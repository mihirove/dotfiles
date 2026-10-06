#!/usr/bin/env python3
"""Mine labeled review examples (diff hunk -> human comment) from merged PRs.

This is the "training" step of the pr-review skill. It is re-runnable: point it
at a repo, it walks recently merged PRs, keeps only human review comments, and
writes one JSON object per thread so the skill can learn how this team reviews.

Filters mirror the weekly maintenance prompt in wklr-mono
(docs/maintenance-prompts/weekly/viewpoint.md): drop the PR author's own
comments, bots, Linear/CI automation, and bare approvals.

Auth: uses GH_TOKEN if set. Otherwise relies on ambient credentials
(Claude Code on the web injects them at the proxy). Only REST is used because
GraphQL is blocked in Claude Code sessions.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.github.com"

BOT_LOGIN_RE = re.compile(r"\[bot\]$|^(copilot|dependabot|renovate|github-actions|devin-ai-integration|greptile|coderabbitai|cursor)", re.I)
# Short acknowledgements carry no reviewing signal.
NOISE_RE = re.compile(
    r"^\s*(lgtm|approve[d]?|ok|okay|👍|🙏|ありがとうございます[。！!]?|確認しました[。！!]?|対応しました[。！!]?|修正しました[。！!]?|承知しました[。！!]?|なるほど[。！!]?|了解です[。！!]?|done|fixed|resolved)\s*[.!。！]*\s*$",
    re.I,
)
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
PICTURE_RE = re.compile(r"<picture>.*?</picture>", re.S | re.I)
AGENT_PROMPT_RE = re.compile(r"<details>\s*<summary>\s*Prompt for agents.*?</details>", re.S | re.I)


def _request(url: str, token: str | None, retries: int = 4):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "pr-review-skill-miner"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    delay = 2
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json.loads(resp.read().decode("utf-8")), resp.headers
        except urllib.error.HTTPError as e:
            if e.code in (403, 429) and attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
                continue
            if e.code == 404:
                return None, {}
            raise
        except urllib.error.URLError:
            if attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
                continue
            raise
    return None, {}


def paginate(path: str, token: str | None, params: dict | None = None, max_pages: int = 50):
    params = dict(params or {})
    params.setdefault("per_page", 100)
    page = 1
    while page <= max_pages:
        params["page"] = page
        url = f"{API}{path}?{urllib.parse.urlencode(params)}"
        data, _ = _request(url, token)
        if not data:
            return
        for item in data:
            yield item
        if len(data) < params["per_page"]:
            return
        page += 1


def clean_body(body: str) -> str:
    body = HTML_COMMENT_RE.sub(" ", body or "")
    body = PICTURE_RE.sub(" ", body)
    body = AGENT_PROMPT_RE.sub(" ", body)
    return body.replace("\r\n", "\n").strip()


def is_bot(user: dict | None) -> bool:
    if not user:
        return True
    return user.get("type") == "Bot" or bool(BOT_LOGIN_RE.search(user.get("login", "")))


def is_noise(body: str) -> bool:
    return len(body) < 4 or bool(NOISE_RE.match(body))


def fetch_threads_state(owner: str, repo: str, number: int, token: str | None) -> dict[int, dict]:
    """Map comment_id -> {resolved, outdated}. The route is Claude Code specific; absence is fine."""
    data, _ = _request(f"{API}/repos/{owner}/{repo}/pulls/{number}/ccr/review_threads", token)
    out: dict[int, dict] = {}
    if isinstance(data, list):
        for t in data:
            for cid in t.get("comment_ids", []):
                out[cid] = {"resolved": t.get("resolved"), "outdated": t.get("outdated")}
    return out


def mine_pr(owner: str, repo: str, pr: dict, token: str | None, with_state: bool):
    number = pr["number"]
    author = (pr.get("user") or {}).get("login")
    state = fetch_threads_state(owner, repo, number, token) if with_state else {}

    comments = list(paginate(f"/repos/{owner}/{repo}/pulls/{number}/comments", token))
    by_id = {c["id"]: c for c in comments}
    # Group into threads by root comment so the skill sees how a discussion resolved.
    threads: dict[int, list[dict]] = {}
    for c in sorted(comments, key=lambda c: c["created_at"]):
        root = c.get("in_reply_to_id") or c["id"]
        while root in by_id and by_id[root].get("in_reply_to_id"):
            root = by_id[root]["in_reply_to_id"]
        threads.setdefault(root, []).append(c)

    for root_id, items in threads.items():
        root = items[0]
        if is_bot(root.get("user")) or (root.get("user") or {}).get("login") == author:
            continue
        body = clean_body(root.get("body"))
        if is_noise(body):
            continue
        replies = []
        for r in items[1:]:
            rb = clean_body(r.get("body"))
            if is_bot(r.get("user")) or not rb:
                continue
            replies.append({
                "by_author": (r.get("user") or {}).get("login") == author,
                "body": rb[:1500],
            })
        yield {
            "repo": f"{owner}/{repo}",
            "pr": number,
            "pr_title": pr.get("title"),
            "merged_at": pr.get("merged_at"),
            "kind": "inline",
            "path": root.get("path"),
            "line": root.get("line") or root.get("original_line"),
            "diff_hunk": (root.get("diff_hunk") or "")[-2500:],
            "comment": body[:3000],
            "replies": replies,
            "resolved": state.get(root_id, {}).get("resolved"),
            "outdated": state.get(root_id, {}).get("outdated"),
        }

    # Review summaries (approve/request-changes bodies) that carry substance.
    for rv in paginate(f"/repos/{owner}/{repo}/pulls/{number}/reviews", token):
        if is_bot(rv.get("user")) or (rv.get("user") or {}).get("login") == author:
            continue
        body = clean_body(rv.get("body"))
        if is_noise(body):
            continue
        yield {
            "repo": f"{owner}/{repo}", "pr": number, "pr_title": pr.get("title"), "merged_at": pr.get("merged_at"),
            "kind": "review_summary", "review_state": rv.get("state"), "comment": body[:3000],
        }

    # PR-level conversation comments from humans other than the author.
    for ic in paginate(f"/repos/{owner}/{repo}/issues/{number}/comments", token):
        if is_bot(ic.get("user")) or (ic.get("user") or {}).get("login") == author:
            continue
        body = clean_body(ic.get("body"))
        if is_noise(body) or body.startswith(("/", "@")):
            continue
        yield {
            "repo": f"{owner}/{repo}", "pr": number, "pr_title": pr.get("title"), "merged_at": pr.get("merged_at"),
            "kind": "conversation", "comment": body[:3000],
        }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("repo", help="owner/name")
    ap.add_argument("--base", default=None, help="base branch filter (default: repo default branch)")
    ap.add_argument("--max-prs", type=int, default=150)
    ap.add_argument("--since", default=None, help="ISO date; stop at PRs merged before this")
    ap.add_argument("--out", default="-", help="output JSONL path (default stdout)")
    ap.add_argument("--no-thread-state", action="store_true", help="skip the resolved/outdated lookup")
    args = ap.parse_args()

    owner, repo = args.repo.split("/", 1)
    token = os.environ.get("GH_TOKEN") or None
    base = args.base
    if base is None:
        meta, _ = _request(f"{API}/repos/{owner}/{repo}", token)
        base = (meta or {}).get("default_branch", "main")

    out = sys.stdout if args.out == "-" else open(args.out, "w", encoding="utf-8")
    n_prs = n_items = 0
    for pr in paginate(f"/repos/{owner}/{repo}/pulls", token, {"state": "closed", "base": base, "sort": "updated", "direction": "desc"}):
        if not pr.get("merged_at"):
            continue
        if args.since and pr["merged_at"] < args.since:
            continue
        if is_bot(pr.get("user")):
            continue
        for item in mine_pr(owner, repo, pr, token, not args.no_thread_state):
            out.write(json.dumps(item, ensure_ascii=False) + "\n")
            n_items += 1
        n_prs += 1
        print(f"[{n_prs}/{args.max_prs}] PR #{pr['number']} -> {n_items} items so far", file=sys.stderr)
        if n_prs >= args.max_prs:
            break
    if out is not sys.stdout:
        out.close()
    print(f"done: {n_prs} PRs, {n_items} items", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

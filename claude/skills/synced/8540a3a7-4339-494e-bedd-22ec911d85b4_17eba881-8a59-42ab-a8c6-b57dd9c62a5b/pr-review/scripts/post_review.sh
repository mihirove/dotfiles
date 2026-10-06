#!/usr/bin/env bash
# Post a review from review.json as a single COMMENT review.
# Usage: post_review.sh <owner/repo> <number> <review.json> [--dry-run]
#
# review.json: {"summary": "<markdown>", "comments": [{"path": "...", "line": 12, "body": "..."}]}
# `line` is the new-side line number.
#
# Before posting, every comment is checked against the PR's own patch (GET /pulls/N/files).
# Comments whose line is not on the RIGHT side of the diff are folded into the summary up front,
# so the one-shot submit does not 422. If the submit still fails, a summary-only review that
# carries every finding is posted instead; findings are never dropped.
# The event is always COMMENT: approving or requesting changes is a human decision.
#
# Transport: `gh api` when gh is authenticated, otherwise curl with ambient credentials (Claude Code on
# the web injects them at the proxy), same as fetch_pr_context.sh.
#
# Footer: none by default. Set PR_REVIEW_FOOTER to append text (after a --- rule) to the summary and
# each inline comment.
set -euo pipefail
repo="${1:?owner/repo}"; num="${2:?PR number}"; file="${3:?review.json}"; dry="${4:-}"

use_gh=0
gh auth status >/dev/null 2>&1 && use_gh=1

get() {  # get <path>
  if [ "$use_gh" = 1 ]; then gh api "$1"
  else curl -sS -f -H 'Accept: application/vnd.github+json' "https://api.github.com$1"; fi
}
post() {  # post <path> <json-file>
  if [ "$use_gh" = 1 ]; then gh api -X POST "$1" --input "$2"
  else curl -sS -f -X POST -H 'Accept: application/vnd.github+json' -H 'Content-Type: application/json' \
         --data-binary @"$2" "https://api.github.com$1"; fi
}

tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
head_sha="$(get "/repos/${repo}/pulls/${num}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["head"]["sha"])')"

# Concatenate pages of the file list (arrays back to back; the parser below reads them in sequence).
: > "$tmpdir/files.json"
for page in $(seq 1 20); do
  chunk="$(get "/repos/${repo}/pulls/${num}/files?per_page=100&page=${page}")"
  n="$(printf '%s' "$chunk" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)')"
  [ "$n" = 0 ] && break
  printf '%s' "$chunk" >> "$tmpdir/files.json"
  [ "$n" -lt 100 ] && break
done

python3 - "$file" "$tmpdir/files.json" "$head_sha" "$tmpdir/main.json" "$tmpdir/fallback.json" <<'PY'
import json, os, re, sys

review_path, files_path, sha, out_main, out_fallback = sys.argv[1:6]
d = json.load(open(review_path))

# `gh api --paginate` prints one JSON array per page back to back.
raw, dec, i, files = open(files_path).read(), json.JSONDecoder(), 0, []
while True:
    while i < len(raw) and raw[i].isspace():
        i += 1
    if i >= len(raw):
        break
    obj, i = dec.raw_decode(raw, i)
    if isinstance(obj, list):
        files.extend(obj)

def right_lines(patch):
    lines, cur = set(), None
    for ln in (patch or "").rstrip("\n").split("\n"):
        m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", ln)
        if m:
            cur = int(m.group(1)); continue
        if cur is None or ln.startswith("\\") or ln.startswith("-"):
            continue
        lines.add(cur); cur += 1
    return lines

valid = {f["filename"]: right_lines(f.get("patch")) for f in files}

ft = os.environ.get("PR_REVIEW_FOOTER", "")
footer = ("\n\n---\n" + ft) if ft else ""

inline, folded = [], []
for c in d.get("comments", []):
    try:
        line = int(c["line"])
    except (KeyError, TypeError, ValueError):
        folded.append(c); continue
    if line in valid.get(c["path"], set()):
        inline.append({"path": c["path"], "line": line, "side": "RIGHT", "body": c["body"] + footer})
    else:
        folded.append(c)

def section(cs):
    if not cs:
        return ""
    items = "\n".join(f"- `{c.get('path')}:{c.get('line')}` — {c.get('body')}" for c in cs)
    return "\n\n### 差分外の行への指摘（インラインに付けられなかったもの）\n" + items

summary = d["summary"]
json.dump({"commit_id": sha, "event": "COMMENT", "body": summary + section(folded) + footer, "comments": inline},
          open(out_main, "w"), ensure_ascii=False)
json.dump({"commit_id": sha, "event": "COMMENT", "body": summary + section(d.get("comments", [])) + footer},
          open(out_fallback, "w"), ensure_ascii=False)
print(f"inline={len(inline)} folded_into_summary={len(folded)}")
PY

if [ "$dry" = "--dry-run" ]; then
  echo "[dry-run] nothing posted"
  exit 0
fi

if post "/repos/${repo}/pulls/${num}/reviews" "$tmpdir/main.json" >/dev/null 2>"$tmpdir/err"; then
  echo "posted review"
  exit 0
fi

echo "inline submit failed ($(head -c 300 "$tmpdir/err")); posting a summary-only review with all findings" >&2
if post "/repos/${repo}/pulls/${num}/reviews" "$tmpdir/fallback.json" >/dev/null 2>"$tmpdir/err2"; then
  echo "posted summary-only review"
  exit 0
fi
echo "could not post ($(head -c 300 "$tmpdir/err2")); use the report in review.md instead." >&2
exit 3

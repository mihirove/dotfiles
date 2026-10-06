#!/usr/bin/env bash
# Fetch everything the pr-review skill needs about one PR into a directory.
# Usage: fetch_pr_context.sh <owner/repo> <number> <out-dir>
#
# Uses `gh api` when gh is authenticated, otherwise falls back to curl with ambient
# credentials (Claude Code on the web injects them at the proxy). REST only: GraphQL
# is blocked in Claude Code sessions, so thread resolution comes from the CCR route
# /pulls/{n}/ccr/review_threads when available and is simply empty elsewhere.
set -euo pipefail

repo="${1:?owner/repo}"
num="${2:?PR number}"
out="${3:?out dir}"
mkdir -p "$out"

api() {
  local path="$1"; shift
  if gh auth status >/dev/null 2>&1; then
    gh api "$path" "$@"
  else
    curl -sS -H 'Accept: application/vnd.github+json' "https://api.github.com${path}" "$@"
  fi
}

api_paged() {
  # Concatenate all pages of a list endpoint into one JSON array.
  local path="$1" page=1 all="[]"
  while :; do
    local chunk
    chunk="$(api "${path}?per_page=100&page=${page}")"
    [ "$(printf '%s' "$chunk" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)')" = "0" ] && break
    all="$(python3 -c 'import json,sys; a=json.loads(sys.argv[1]); b=json.loads(sys.argv[2]); print(json.dumps(a+b))' "$all" "$chunk")"
    page=$((page+1))
    [ "$page" -gt 20 ] && break
  done
  printf '%s' "$all"
}

api "/repos/${repo}/pulls/${num}" > "$out/meta.json"
if gh auth status >/dev/null 2>&1; then
  gh api "/repos/${repo}/pulls/${num}" -H 'Accept: application/vnd.github.diff' > "$out/diff.patch"
else
  curl -sS -H 'Accept: application/vnd.github.diff' "https://api.github.com/repos/${repo}/pulls/${num}" > "$out/diff.patch"
fi
api_paged "/repos/${repo}/pulls/${num}/files" > "$out/files.json"

python3 - "$out" <<'PY' "$(api_paged "/repos/${repo}/pulls/${num}/comments")" "$(api_paged "/repos/${repo}/issues/${num}/comments")" "$(api_paged "/repos/${repo}/pulls/${num}/reviews")"
import json, sys
out, inline, conv, reviews = sys.argv[1], json.loads(sys.argv[2]), json.loads(sys.argv[3]), json.loads(sys.argv[4])
def slim_user(u): return {"login": (u or {}).get("login"), "bot": (u or {}).get("type") == "Bot"}
bundle = {
  "inline": [{"id": c["id"], "in_reply_to_id": c.get("in_reply_to_id"), "path": c.get("path"), "line": c.get("line") or c.get("original_line"),
               "user": slim_user(c.get("user")), "body": c.get("body"), "created_at": c.get("created_at")} for c in inline],
  "conversation": [{"id": c["id"], "user": slim_user(c.get("user")), "body": c.get("body"), "created_at": c.get("created_at")} for c in conv],
  "reviews": [{"id": r["id"], "user": slim_user(r.get("user")), "state": r.get("state"), "body": r.get("body"), "submitted_at": r.get("submitted_at")} for r in reviews],
}
json.dump(bundle, open(f"{out}/existing_comments.json", "w"), ensure_ascii=False, indent=1)
PY

api "/repos/${repo}/pulls/${num}/ccr/review_threads" > "$out/review_threads.json" 2>/dev/null || echo '[]' > "$out/review_threads.json"
head_sha="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["head"]["sha"])' "$out/meta.json")"
api "/repos/${repo}/commits/${head_sha}/check-runs" > "$out/checks.json" 2>/dev/null || echo '{}' > "$out/checks.json"

python3 - "$out" <<'PY'
import json, sys
out = sys.argv[1]
m = json.load(open(f"{out}/meta.json")); f = json.load(open(f"{out}/files.json")); c = json.load(open(f"{out}/existing_comments.json"))
print(f"#{m['number']} {m['title']}")
print(f"author={m['user']['login']} base={m['base']['ref']} head={m['head']['ref']}@{m['head']['sha'][:8]} draft={m.get('draft')} +{m.get('additions')}/-{m.get('deletions')} files={len(f)}")
print(f"existing: inline={len(c['inline'])} conversation={len(c['conversation'])} reviews={len(c['reviews'])}")
print(f"bundle written to {out}/")
PY

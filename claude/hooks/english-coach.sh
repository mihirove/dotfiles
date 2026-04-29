#!/usr/bin/env bash
# UserPromptSubmit hook: stream the EnglishCoach style rules into context
# on every turn. The output-style file itself is disabled in settings.json,
# so this hook is the active mechanism. Editing the .md file is enough —
# no settings change needed.
set -euo pipefail

style_file="$HOME/.claude/output-styles/EnglishCoach.md"
[ -f "$style_file" ] || exit 0

printf '[EnglishCoach hook] Apply these coaching rules to your reply and to evaluating the user'"'"'s most recent message:\n\n'

awk '
  NR == 1 && /^---$/ { in_fm = 1; next }
  in_fm && /^---$/   { in_fm = 0; next }
  in_fm              { next }
                     { print }
' "$style_file"

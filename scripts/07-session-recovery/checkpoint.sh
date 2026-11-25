#!/usr/bin/env bash
# Checkpoint hook. Usage: checkpoint.sh preCompact|sessionStart
# preCompact:   save the branch and changed files to $HOOK_STATE_DIR/checkpoint.txt (output is ignored).
# sessionStart: when the session is a resume, hand that note to the agent as additionalContext.
# Reads:   the event JSON on stdin. Env: HOOK_STATE_DIR (default .hooks-state).
event="$1"
input=$(cat)
dir="${HOOK_STATE_DIR:-.hooks-state}"
file="$dir/checkpoint.txt"
if [ "$event" = "preCompact" ]; then
  mkdir -p "$dir"
  { echo "Saved $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "Branch: $(git branch --show-current)"; echo "Changed files:"; git status --short | head -20; } > "$file"
  echo '{}'
elif [ "$(echo "$input" | jq -r '.source // empty')" = "resume" ] && [ -f "$file" ]; then
  jq -n --rawfile note "$file" '{additionalContext: ("Note saved before the session was compacted:\n" + $note)}'
else
  echo '{}'
fi

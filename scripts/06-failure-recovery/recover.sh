#!/usr/bin/env bash
# postToolUseFailure hook: log the failure and give the agent a hint instead of letting it guess.
# Reads:   the event JSON on stdin (toolName, error). The error text is never written to disk.
# Env:     HOOK_LOG_DIR (default .hooks-state); failures.log is written there.
# Returns: {"additionalContext": "Recovery hint: ..."}.
input=$(cat)
tool=$(echo "$input" | jq -r '.toolName // "unknown"')
error=$(echo "$input" | jq -r '.error // "" | tostring')
dir="${HOOK_LOG_DIR:-.hooks-state}"
mkdir -p "$dir"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $tool failed" >> "$dir/failures.log"
case "$error" in
  *"does not exist"*|*"No such file"*) hint="The path does not exist. Search for the file name before trying again." ;;
  *"denied"*|*"not permitted"*)        hint="Permission was denied. Do not work around it; ask the user." ;;
  *)                                   hint="Do not retry blindly. Find the cause, then try a different step." ;;
esac
jq -n --arg text "Recovery hint: $hint" '{additionalContext: $text}'

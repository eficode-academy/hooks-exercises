#!/usr/bin/env bash
# Only allowlisted metadata is persisted. Never persist the input payload.
set -euo pipefail
umask 077
fail() { printf '%s\n' "activity-log: $1" >&2; printf '{"error":"activity-log failed"}\n'; exit 1; }
command -v jq >/dev/null 2>&1 || fail 'jq is required'
event=${1-}
case "$event" in
  sessionStart|userPromptSubmitted|preToolUse|postToolUse|postToolUseFailure|errorOccurred|preCompact|subagentStart|subagentStop|agentStop|sessionEnd|notification) ;;
  *) fail 'unsupported event argument' ;;
esac
payload=$(head -c 262145) || fail 'cannot read input'
[ "${#payload}" -le 262144 ] || fail 'input exceeds 256 KiB'
payload=$(printf '%s' "$payload" | jq -cse 'if length == 1 and (.[0] | type == "object") then .[0] else error("invalid payload") end' 2>/dev/null) ||
  fail 'expected exactly one JSON object'
printf '%s' "$payload" | jq -e 'type == "object" and
  ((has("cwd") | not) or (.cwd | type == "string" and length > 0 and length <= 4096 and (test("[\u0000-\u001f\u007f]") | not)))' >/dev/null 2>&1 ||
  fail 'expected a JSON object with an optional absolute cwd'
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty')
cwd=${cwd:-"$PWD"}
case "$cwd" in /*) ;; *) fail 'cwd must be absolute' ;; esac
[ -d "$cwd" ] || fail 'cwd is not a directory'
dir=${HOOK_LOG_DIR:-.hooks-state}
case "$dir" in /*) ;; *) dir="$cwd/$dir" ;; esac
mkdir -p "$dir" 2>/dev/null || fail 'cannot create log directory'
record=$(printf '%s' "$payload" | jq -c --arg event "$event" '
  with_entries(select(.key as $k |
    ["timestamp","sessionId","toolName","source","reason","trigger","agentName","errorContext"] | index($k)))
  | with_entries(select((.value | type) == "string" or
      ((.value | type) == "number" and (.value | fabs) <= 1000000000000000)))
  | with_entries(.value |= if type == "string" then gsub("[\u0000-\u001f\u007f]"; " ") | .[0:256] else . end)
  | .event = $event') || fail 'cannot encode metadata'
locked=false
for ((i=0; i<40; i++)); do
  if mkdir "$dir/.activity-log.lock" 2>/dev/null; then locked=true; break; fi
  sleep 0.025
done
[ "$locked" = true ] || fail 'log lock unavailable; remove a stale lock only when no writer is running'
trap 'rmdir "$dir/.activity-log.lock" 2>/dev/null || true' EXIT
printf '%s\n' "$record" >> "$dir/events.jsonl" || fail 'cannot append metadata'
printf '{}\n'

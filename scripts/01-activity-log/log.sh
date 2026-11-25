#!/usr/bin/env bash
# Activity log hook. Usage: log.sh <eventName>
# Reads:   the event JSON on stdin.
# Writes:  one line (time, event, session, tool) to $HOOK_LOG_DIR/events.jsonl.
# Returns: {} (no decision). Prompts and tool arguments are deliberately NOT logged.
event="${1:-unknown}"
input=$(cat)
dir="${HOOK_LOG_DIR:-.hooks-state}"
mkdir -p "$dir"
echo "$input" | jq -c --arg event "$event" \
  '{time: (now | todate), event: $event, sessionId, toolName}' >> "$dir/events.jsonl"
echo '{}'

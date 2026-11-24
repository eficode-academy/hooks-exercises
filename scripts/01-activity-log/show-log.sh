#!/usr/bin/env bash
# Manual viewer (not a hook): prints the last 20 activity-log lines in a readable form.
file="${HOOK_LOG_DIR:-.hooks-state}/events.jsonl"
[ -f "$file" ] || { echo "No activity log yet."; exit 0; }
tail -n 20 "$file" | jq -r '"\(.time)  \(.event)  tool=\(.toolName // "-")"'

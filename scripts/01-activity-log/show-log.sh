#!/usr/bin/env bash
# Manual CLI: human-readable stdout, not a hook response.
set -euo pipefail
fail() { printf '%s\n' "show-log: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail 'jq is required'
limit=${HOOK_LOG_LIMIT:-100}
case "$limit" in ''|*[!0-9]*) fail 'HOOK_LOG_LIMIT must be an integer from 1 to 1000' ;; esac
[ "${#limit}" -le 4 ] && [ "$((10#$limit))" -ge 1 ] && [ "$((10#$limit))" -le 1000 ] ||
  fail 'HOOK_LOG_LIMIT must be an integer from 1 to 1000'
file="${HOOK_LOG_DIR:-.hooks-state}/events.jsonl"
[ -f "$file" ] || { printf 'No activity log yet.\n'; exit 0; }
tail -n "$((10#$limit))" "$file" | jq -Rr '
  fromjson | if type != "object" then error("invalid record") else . end |
  def safe: if type == "string" or type == "number" then tostring | gsub("[\u0000-\u001f\u007f]"; " ") | .[0:256] else "-" end;
  "\(.timestamp | safe)  \(.event | safe)  session=\(.sessionId | safe)  tool=\(.toolName | safe)"' 2>/dev/null ||
  fail 'cannot read timeline: malformed JSONL or unreadable file'

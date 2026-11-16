#!/usr/bin/env bash
set -euo pipefail
if ! command -v jq >/dev/null 2>&1; then
  printf 'Notification skipped: jq is required.\n' >&2
  printf '{}\n'
  exit 2
fi
input=$(cat)
if ! printf '%s' "$input" | jq -e 'type == "object"' >/dev/null 2>&1; then
  printf 'Notification skipped: expected a JSON event object.\n' >&2
  printf '{}\n'
  exit 2
fi
printf '\a' >&2
printf '{}\n'

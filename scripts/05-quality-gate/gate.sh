#!/usr/bin/env bash
# agentStop: CHECK_STEPS=format:check;lint;test (1..3 distinct known labels).
# DEMO_DIR=demo-app; CHECK_TIMEOUT_SEC=10 (1..15 per step); HOOK_STATE_DIR=.hooks-state.
# Paths are subdirectories of event.cwd. State is informational, never a pass cache.
# stop_hook_active=true reruns checks, but reports repeated failure on stderr/exit 2.
set -u
fail() { printf 'quality-gate: %s\n' "$1" >&2; printf '{}\n'; exit 2; }
command -v jq >/dev/null 2>&1 || fail 'jq is required.'
command -v node >/dev/null 2>&1 || fail 'Node.js is required.'
input=$(cat) || fail 'Cannot read hook input.'
event=$(printf '%s' "$input" | jq -ce 'select(type == "object")') || fail 'Expected one JSON event object.'
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || fail 'Cannot locate hook files.'
printf '%s' "$event" | node "$script_dir/gate.mjs"

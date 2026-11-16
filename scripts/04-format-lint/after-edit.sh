#!/usr/bin/env bash
# postToolUse edit/create/apply_patch. jq parses the event; Node bounds native local CLIs.
# DEMO_DIR=demo-app; FORMAT_ON_EDIT=true; LINT_ON_EDIT=true; CHECK_TIMEOUT_SEC=10 (1..10).
# Only existing non-symlink src/test JS/JSON files are formatted; ESLint receives JS only.
set -u
fail() { printf 'after-edit: %s\n' "$1" >&2; printf '{}\n'; exit 2; }
command -v jq >/dev/null 2>&1 || fail 'jq is required.'
command -v node >/dev/null 2>&1 || fail 'Node.js is required.'
input=$(cat) || fail 'Cannot read hook input.'
event=$(printf '%s' "$input" | jq -ce 'select(type == "object")') || fail 'Expected one JSON event object.'
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || fail 'Cannot locate hook files.'
printf '%s' "$event" | node "$script_dir/after-edit.mjs"

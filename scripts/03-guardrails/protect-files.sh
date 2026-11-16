#!/usr/bin/env bash
# preToolUse: edit/create path (validated filePath alias), or standard apply_patch input/patch.
# PROTECTED_PATHS is a semicolon-delimited exact file list, relative to event.cwd.
# Unrelated tools return {}; malformed supported edit payloads are denied.
# Lexical guard only: symlinks, shell writes, and alternative edit tools are not sandboxed.
set -u
fail() { printf 'protect-files: %s\n' "$1" >&2; printf '{}\n'; exit 2; }
command -v jq >/dev/null 2>&1 || fail 'jq is required.'
input=$(cat) || fail 'Cannot read hook input.'
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || fail 'Cannot locate hook files.'
cwd=$(printf '%s' "$input" | jq -er 'select(type == "object") | .cwd | select(type == "string" and length > 0)') ||
  fail 'Expected an object with an absolute cwd.'
[[ "$cwd" = /* || "$cwd" =~ ^[A-Za-z]:[/\\] ]] || fail 'cwd must be absolute.'
[[ -d "$cwd" ]] || fail 'cwd must be an existing directory.'
printf '%s' "$input" | jq -c --arg protected "${PROTECTED_PATHS-demo-app/config/production.json}" \
  -f "$script_dir/protect-files.jq" || fail 'Cannot parse hook input.'

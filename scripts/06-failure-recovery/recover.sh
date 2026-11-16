#!/usr/bin/env bash
# Guidance only: no retries, npm commands, or searches are executed.
set -euo pipefail
umask 077
fail() { printf '%s\n' "failure-recovery: $1" >&2; printf '{"error":"failure-recovery failed"}\n'; exit 1; }
command -v jq >/dev/null 2>&1 || fail 'jq is required'
event=${1-}
case "$event" in postToolUseFailure|postToolUse|errorOccurred) ;; *) fail 'unsupported event argument' ;; esac
limit=${FAILURE_LIMIT:-3}
case "$limit" in ''|*[!0-9]*) fail 'FAILURE_LIMIT must be an integer from 1 to 100' ;; esac
[ "${#limit}" -le 3 ] && [ "$((10#$limit))" -ge 1 ] && [ "$((10#$limit))" -le 100 ] ||
  fail 'FAILURE_LIMIT must be an integer from 1 to 100'
limit=$((10#$limit))
payload=$(head -c 262145) || fail 'cannot read input'
[ "${#payload}" -le 262144 ] || fail 'input exceeds 256 KiB'
payload=$(printf '%s' "$payload" | jq -cse 'if length == 1 and (.[0] | type == "object") then .[0] else error("invalid payload") end' 2>/dev/null) ||
  fail 'expected exactly one JSON object'
printf '%s' "$payload" | jq -e 'type == "object" and
  (.sessionId | type == "string" and length > 0 and length <= 256 and (test("[\u0000-\u001f\u007f]") | not)) and
  ((has("cwd") | not) or (.cwd | type == "string" and length > 0 and length <= 4096 and (test("[\u0000-\u001f\u007f]") | not)))' >/dev/null 2>&1 ||
  fail 'expected an object with a bounded sessionId and optional absolute cwd'
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty'); cwd=${cwd:-"$PWD"}
case "$cwd" in /*) ;; *) fail 'cwd must be absolute' ;; esac
[ -d "$cwd" ] || fail 'cwd is not a directory'
cwd=$(cd "$cwd" && pwd -P) || fail 'cannot resolve cwd'
hash() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d ' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -d ' ' -f1
  else fail 'sha256sum or shasum is required'; fi
}
key=$(printf '%s' "$payload" | jq -j '.sessionId' | { cat; printf '\n%s' "$cwd"; } | hash) || fail 'cannot hash session key'
dir=${HOOK_STATE_DIR:-.hooks-state}; case "$dir" in /*) ;; *) dir="$cwd/$dir" ;; esac
mkdir -p "$dir" 2>/dev/null || fail 'cannot create state directory'
file="$dir/failures-$key.json"; lock="$dir/.failures-$key.lock"; locked=false
for ((i=0; i<40; i++)); do
  if mkdir "$lock" 2>/dev/null; then locked=true; break; fi
  sleep 0.025
done
[ "$locked" = true ] || fail 'state lock unavailable; check for a stale lock'
tmp="$lock/state.json"
trap 'rm -f "$tmp"; rmdir "$lock" 2>/dev/null || true' EXIT
count=0
if [ -f "$file" ]; then
  [ "$(wc -c < "$file")" -le 1024 ] || fail 'state exceeds size limit'
  count=$(jq -er 'select(type == "object" and .version == 1) | .failures |
    select(type == "number" and . == floor and . >= 0 and . <= 1000000)' "$file" 2>/dev/null) ||
    fail 'invalid failure state'
fi
category=$(printf '%s' "$payload" | jq -r '
  (.error | if type == "string" then . elif type == "object" and (.message | type) == "string" then .message else "" end | ascii_downcase) as $e |
  if ($e | test("denied|not permitted|forbidden|unauthorized")) then "denied"
  elif ($e | test("missing script|missing npm script|unknown script")) then "missing-npm-script"
  elif ($e | test("enoent|file not found|no such file|does not exist|cannot find (the )?(file|path)")) then "file-not-found"
  elif ($e | test("test.*(fail|failure)|fail.*test|assertion|err_assertion")) then "test-failure"
  else "other" end') || fail 'cannot classify failure'
# Discard raw error text as soon as classification is complete.
unset payload
if [ "$event" = errorOccurred ]; then
  jq -nc --arg event "$event" --arg category "$category" --argjson failures "$count" '{event:$event,category:$category,failures:$failures}' >&2
  printf '{}\n'; exit 0
fi
if [ "$event" = postToolUse ]; then count=0; else
  if [ "$count" -lt 1000000 ]; then count=$((count + 1)); fi
fi
jq -nc --argjson count "$count" '{version:1,failures:$count}' > "$tmp" || fail 'cannot encode failure state'
mv -f "$tmp" "$file" || fail 'cannot save failure state'
if [ "$event" = postToolUse ]; then printf '{}\n'; exit 0; fi
if [ "$count" -ge "$limit" ]; then
  guidance='Failure limit reached. Stop repeating the action; summarize the obstacle without raw errors and ask for human direction. Do not bypass permissions.'
else
  case "$category" in
    denied) guidance='Permission denied. Do not repeat the action or try an alternate route around the denial; request authorized human direction.' ;;
    missing-npm-script) guidance='Inspect available script names with npm run --prefix demo-app before choosing a supported command.' ;;
    file-not-found) guidance='Search for the intended file with a bounded filename search; verify its path before trying again.' ;;
    test-failure) guidance='Run the focused test for the affected behavior, inspect the failure privately, and address its cause rather than repeating the full suite.' ;;
    *) guidance='Do not assume the action succeeded. Inspect the cause privately and choose a different, bounded diagnostic step rather than blindly retrying.' ;;
  esac
fi
jq -nc --arg text "Recovery guidance only (no retry executed). Category: $category; consecutive failures: $count. $guidance" \
  '{additionalContext:$text}' || fail 'cannot encode guidance'

#!/usr/bin/env bash
# Maintainer tests for the bash track. Usage: bash tests/run.sh
# Copies the repo to a temp folder, runs every case in tests/cases.txt through scripts/try-hook.sh
# (so registration, matchers, env and helpers are all exercised), then runs extra checks.
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cp -R "$root/scripts" "$root/solutions" "$root/fixtures" "$root/demo-app" "$work/"
cd "$work" || exit 1
git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -q -m init
total=0; failed=0
fail() { echo "FAIL: $*"; failed=$((failed + 1)); }
pass() { total=$((total + 1)); }

run_case() {  # config event fixture expectation
  out=$(bash scripts/try-hook.sh "$1" "$2" "$3" 2> err.txt); ok=0
  case "$4" in
    none)      grep -q ': 0 matching' err.txt && ok=1 ;;
    empty)     [ "$out" = '{}' ] && ok=1 ;;
    deny)      [ "$(echo "$out" | jq -r .permissionDecision)" = deny ] && ok=1 ;;
    block)     [ "$(echo "$out" | jq -r .decision)" = block ] && ok=1 ;;
    context:*) echo "$out" | jq -r .additionalContext | grep -qF "${4#context:}" && ok=1 ;;
  esac
  pass; [ "$ok" = 1 ] || fail "$2 $3 expected $4, got: $out"
}
while IFS='|' read -r config event fixture expect; do
  case "$config" in '#'*|'') continue ;; @break) cp fixtures/edit-examples/debug-leftover.js demo-app/src/; continue ;;
    @fix) rm demo-app/src/debug-leftover.js; continue ;; esac
  run_case "$config" "$event" "$fixture" "$expect"
done < "$root/tests/cases.txt"

# Activity log: one line per event, and no prompt or tool arguments on disk.
pass; [ "$(wc -l < .hooks-state/events.jsonl)" -eq 11 ] || fail "activity log should hold 11 lines"
pass; ! grep -rq 'DO-NOT-LOG' .hooks-state || fail "log or state files contain fixture payload text"
pass; bash scripts/01-activity-log/show-log.sh | grep -q 'preToolUse' || fail "show-log.sh output"
pass; [ "$(wc -l < .hooks-state/failures.log)" -eq 2 ] || fail "failures.log should hold 2 lines"

# A learner config: env values are honoured, matchers filter, disableAllHooks disables.
cat > mine.json <<'JSON'
{"version":1,"hooks":{"preToolUse":[{"type":"command","matcher":"edit|create",
 "bash":"bash scripts/03-guardrails/protect-files.sh","powershell":"x","env":{"PROTECTED_PATHS":"demo-app/src/cart.js"}}]}}
JSON
run_case mine.json preToolUse fixtures/events/preToolUse-edit-source.json deny
run_case mine.json preToolUse fixtures/events/preToolUse-edit-protected.json empty
run_case mine.json preToolUse fixtures/events/preToolUse-dangerous-command.json none
jq '.disableAllHooks = true' mine.json > off.json
run_case off.json preToolUse fixtures/events/preToolUse-edit-source.json none

# Check stand-in, preflight, and the "keep it simple" rule: helpers are short and start with a comment.
pass; bash demo-app/check.sh > /dev/null || fail "demo-app/check.sh should pass on the baseline"
cp fixtures/edit-examples/debug-leftover.js demo-app/src/
pass; ! bash demo-app/check.sh > /dev/null || fail "demo-app/check.sh should fail with a debug statement"
rm demo-app/src/debug-leftover.js
pass; bash scripts/preflight.sh > /dev/null || fail "preflight"
for f in scripts/0*/*.sh scripts/0*/*.ps1; do
  pass; [ "$(wc -l < "$f")" -le 25 ] || fail "$f is longer than 25 lines"
  pass; sed -n 1,3p "$f" | grep -q '^#' || fail "$f has no header comment"
done

# Solutions: valid JSON, version 1, both shells, scripts exist.
for f in solutions/*/*.json; do
  pass; jq -e '.version == 1 and ([.hooks[][] | .bash and .powershell] | all)' "$f" > /dev/null || fail "$f structure"
  for s in $(jq -r '.hooks[][] | .bash, .powershell | split(" ")[] | select(endswith(".sh") or endswith(".ps1"))' "$f"); do
    pass; [ -f "$s" ] || fail "$f references missing $s"
  done
done

echo "bash track: $((total - failed))/$total checks passed"
[ "$failed" = 0 ]

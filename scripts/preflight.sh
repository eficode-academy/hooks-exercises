#!/usr/bin/env bash
# Preflight for the hooks exercises. Usage: bash scripts/preflight.sh   (run from the repository root)
# Checks the tools, their versions, and that a hook helper really runs in this shell.
# Exit code 1 only if a required tool (git, jq) is missing; the rest are warnings.
fail=0
check() {  # check <tool> <required|optional> <why>
  if command -v "$1" > /dev/null 2>&1; then
    printf '  ok       %-8s %s\n' "$1" "$("$1" --version 2>&1 | head -1)"
  elif [ "$2" = required ]; then printf '  MISSING  %-8s %s\n' "$1" "$3"; fail=1
  else printf '  missing  %-8s %s\n' "$1" "$3"; fi
}
echo "Tools"
check git required "needed for the exercises"
check jq required "bash hooks read JSON with jq"
check pwsh optional "only for the PowerShell track (PowerShell 7)"
check copilot optional "needed for the live parts (Copilot CLI)"
check gh optional "only needed to sign in or install Copilot CLI extras"

echo "Hooks"
out=$(echo '{"toolName":"bash","toolArgs":{"command":"git reset --hard"}}' | bash scripts/03-guardrails/guard-commands.sh 2>&1)
if echo "$out" | grep -q '"deny"'; then echo "  ok       guard helper runs here and denies a dangerous command"
else echo "  FAILED   guard helper did not return a deny decision: $out"; fail=1; fi
if grep -qs '"disableAllHooks" *: *true' "$HOME/.copilot/config.json" .github/hooks/*.json 2> /dev/null; then
  echo "  WARNING  disableAllHooks is true in your Copilot config or .github/hooks/"
fi
echo "  note     Whether your organization allows hooks can only be proven live: finish exercise 01 and"
echo "           check that .hooks-state/events.jsonl gets lines. See docs/troubleshooting.md if not."
[ "$fail" = 0 ] && echo "Preflight passed." || echo "Preflight found problems above."
exit $fail

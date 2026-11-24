#!/usr/bin/env bash
# Stand-in for your project's own check. Replace the body with `npm test`, `pytest -q`, `go test ./...` ...
# Exit code 0 = pass, anything else = fail (the message on stdout is what the agent sees).
cd "$(dirname "$0")" || exit 1
if grep -rn --include='*.js' -e 'console\.log' -e 'debugger' src; then
  echo "check failed: remove debug statements from src/"
  exit 1
fi
jq empty config/production.json || { echo "check failed: config/production.json is not valid JSON"; exit 1; }
echo "check passed"

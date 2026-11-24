#!/usr/bin/env bash
# Offline hook runner. Usage: bash scripts/try-hook.sh CONFIG EVENT FIXTURE
# Example: bash scripts/try-hook.sh .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-edit-protected.json
# Finds the hooks that CONFIG registers for EVENT, pipes FIXTURE into each matching "bash" command
# (with its "env" values) and prints what the hook returns. The command inside the fixture is never run.
config="$1"; event="$2"; fixture="$3"
[ -f "$config" ] && [ -f "$fixture" ] || { echo "Usage: bash scripts/try-hook.sh CONFIG EVENT FIXTURE" >&2; exit 1; }
jq -e . "$config" > /dev/null || { echo "$config is not valid JSON" >&2; exit 1; }
subject=$(jq -r '.toolName // .trigger // .agentName // empty' "$fixture")   # what a "matcher" is compared with
count=0
if [ "$(jq -r '.disableAllHooks // false' "$config")" != "true" ]; then
  while IFS= read -r hook; do
    matcher=$(echo "$hook" | jq -r '.matcher // empty')
    if [ -n "$matcher" ] && ! [[ "$subject" =~ ^($matcher)$ ]]; then continue; fi
    cmd=$(echo "$hook" | jq -r '.bash // .command // empty')
    [ -n "$cmd" ] || { echo "No \"bash\" command in this hook entry" >&2; continue; }
    count=$((count + 1))
    envs=()
    while IFS= read -r kv; do envs+=("$kv"); done < <(echo "$hook" | jq -r '(.env // {}) | to_entries[] | "\(.key)=\(.value)"')
    echo "--- running: $cmd" >&2
    env "${envs[@]}" bash -c "$cmd" < "$fixture"
    echo "--- exit code: $?" >&2
  done < <(jq -c --arg e "$event" '.hooks[$e] // [] | .[]' "$config")
fi
echo "Offline $event: $count matching hook(s). Nothing from the fixture was executed." >&2

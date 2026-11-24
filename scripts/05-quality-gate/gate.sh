#!/usr/bin/env bash
# agentStop hook: run your check before the agent is allowed to finish.
# Reads:   the event JSON on stdin; stop_hook_active is true when the agent was already blocked once.
# Env:     CHECK_COMMAND (default "bash demo-app/check.sh"); use your own, e.g. "pytest -q".
# Returns: {"decision":"block","reason":"..."} if the check fails, else {}. Blocks only once per stop.
input=$(cat)
if [ "$(echo "$input" | jq -r '.stop_hook_active')" = "true" ]; then
  echo "gate: already blocked once, letting the agent stop." >&2
  echo '{}'
elif out=$(bash -c "${CHECK_COMMAND:-bash demo-app/check.sh}" 2>&1); then
  echo '{}'
else
  jq -n --arg why "The check failed. Fix it before you finish:
$out" '{decision: "block", reason: $why}'
fi

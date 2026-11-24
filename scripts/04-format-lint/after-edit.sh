#!/usr/bin/env bash
# postToolUse hook: run your check after every edit and tell the agent if it fails.
# Reads:   the event JSON on stdin (not needed, so it is discarded).
# Env:     CHECK_COMMAND (default "bash demo-app/check.sh"); use your own, e.g. "pytest -q".
# Returns: {} when the check passes, else {"additionalContext": "<check output>"}.
cat > /dev/null
if out=$(bash -c "${CHECK_COMMAND:-bash demo-app/check.sh}" 2>&1); then
  echo '{}'
else
  jq -n --arg text "The check failed after your edit. Fix it:
$out" '{additionalContext: $text}'
fi

#!/usr/bin/env bash
# agentStop hook: ring the terminal bell when the agent finishes.
# Reads:   the event JSON on stdin (not needed, so it is discarded).
# Returns: {} (no decision). The bell goes to stderr so stdout stays valid JSON.
cat > /dev/null
printf '\a' >&2
echo '{}'

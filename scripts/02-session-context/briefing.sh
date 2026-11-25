#!/usr/bin/env bash
# Session briefing hook (sessionStart, subagentStart). Usage: briefing.sh <eventName>
# Reads:   the event JSON on stdin (not needed, so it is discarded).
# Env:     DEMO_DIR (default demo-app), the project folder named in the house rules.
# Returns: {"additionalContext": "..."}: house rules, branch and recent commits for the agent.
cat > /dev/null
demo="${DEMO_DIR:-demo-app}"
rules="House rules: money is integer cents. Never edit $demo/config/production.json. Never print secrets. Run 'bash $demo/check.sh' before you finish."
branch=$(git branch --show-current 2>/dev/null)
commits=$(git log -3 --format='%h %s' 2>/dev/null)
jq -n --arg text "$rules
Branch: $branch
Recent commits:
$commits" '{additionalContext: $text}'

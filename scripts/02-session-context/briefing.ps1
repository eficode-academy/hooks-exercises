# Session briefing hook (sessionStart, subagentStart). Usage: briefing.ps1 <eventName>
# Reads:   the event JSON on stdin (not needed, so it is discarded).
# Env:     DEMO_DIR (default demo-app), the project folder named in the house rules.
# Returns: {"additionalContext": "..."}: house rules, branch and recent commits for the agent.
param([string]$EventName)
[Console]::In.ReadToEnd() | Out-Null
$demo = $env:DEMO_DIR ?? 'demo-app'
$rules = "House rules: money is integer cents. Never edit $demo/config/production.json. Never print secrets. Run 'pwsh -File $demo/check.ps1' before you finish."
$branch = git branch --show-current 2>$null
$commits = git log -3 --format='%h %s' 2>$null
@{ additionalContext = (@($rules, "Branch: $branch", 'Recent commits:') + @($commits)) -join "`n" } | ConvertTo-Json -Compress

# postToolUse hook: run your check after every edit and tell the agent if it fails.
# Reads:   the event JSON on stdin (not needed, so it is discarded).
# Env:     CHECK_COMMAND (default "pwsh -NoProfile -File demo-app/check.ps1"); use your own, e.g. "pytest -q".
# Returns: {} when the check passes, else {"additionalContext": "<check output>"}.
[Console]::In.ReadToEnd() | Out-Null
$cmd = $env:CHECK_COMMAND ?? 'pwsh -NoProfile -File demo-app/check.ps1'
$out = Invoke-Expression $cmd 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) { '{}' }
else { @{ additionalContext = "The check failed after your edit. Fix it:`n$out" } | ConvertTo-Json -Compress }

# agentStop hook: run your check before the agent is allowed to finish.
# Reads:   the event JSON on stdin; stop_hook_active is true when the agent was already blocked once.
# Env:     CHECK_COMMAND (default "pwsh -NoProfile -File demo-app/check.ps1"); use your own, e.g. "pytest -q".
# Returns: {"decision":"block","reason":"..."} if the check fails, else {}. Blocks only once per stop.
$e = [Console]::In.ReadToEnd() | ConvertFrom-Json
if ($e.stop_hook_active) {
  [Console]::Error.WriteLine('gate: already blocked once, letting the agent stop.')
  '{}'
  exit 0
}
$cmd = $env:CHECK_COMMAND ?? 'pwsh -NoProfile -File demo-app/check.ps1'
$out = Invoke-Expression $cmd 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) { '{}' }
else { [ordered]@{ decision = 'block'; reason = "The check failed. Fix it before you finish:`n$out" } | ConvertTo-Json -Compress }

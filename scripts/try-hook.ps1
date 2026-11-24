# Offline hook runner. Usage: pwsh -File scripts/try-hook.ps1 CONFIG EVENT FIXTURE
# Example: pwsh -File scripts/try-hook.ps1 .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-edit-protected.json
# Finds the hooks that CONFIG registers for EVENT, pipes FIXTURE into each matching "powershell" command
# (with its "env" values) and prints what the hook returns. The command inside the fixture is never run.
param([Parameter(Mandatory)][string]$Config, [Parameter(Mandatory)][string]$EventName, [Parameter(Mandatory)][string]$Fixture)
$cfg = Get-Content $Config -Raw | ConvertFrom-Json
$text = Get-Content $Fixture -Raw
$e = $text | ConvertFrom-Json
$subject = "$($e.toolName ?? $e.trigger ?? $e.agentName)"   # what a "matcher" is compared with
$count = 0
foreach ($hook in $(if ($cfg.disableAllHooks -ne $true) { $cfg.hooks.$EventName })) {
  if ($hook.matcher -and $subject -notmatch "^($($hook.matcher))$") { continue }
  $cmd = $hook.powershell ?? $hook.command
  if (-not $cmd) { [Console]::Error.WriteLine('No "powershell" command in this hook entry'); continue }
  $count++
  foreach ($p in $hook.env.PSObject.Properties) { Set-Item "env:$($p.Name)" $p.Value }
  [Console]::Error.WriteLine("--- running: $cmd")
  $text | pwsh -NoProfile -Command $cmd
  [Console]::Error.WriteLine("--- exit code: $LASTEXITCODE")
  foreach ($p in $hook.env.PSObject.Properties) { Remove-Item "env:$($p.Name)" }
}
[Console]::Error.WriteLine("Offline ${EventName}: $count matching hook(s). Nothing from the fixture was executed.")

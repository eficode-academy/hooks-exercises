# Stand-in for your project's own check. Replace the body with `make test`, `pytest -q`, `go test ./...` ...
# Exit code 0 = pass, anything else = fail (the message on stdout is what the agent sees).
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$bad = Select-String -Path 'src/*.js' -Pattern 'console\.log', 'debugger'
if ($bad) {
  $bad | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
  'check failed: remove debug statements from src/'
  exit 1
}
Get-Content config/production.json -Raw | ConvertFrom-Json | Out-Null
'check passed'

# Checkpoint hook. Usage: checkpoint.ps1 preCompact|sessionStart
# preCompact:   save the branch and changed files to $env:HOOK_STATE_DIR/checkpoint.txt (output is ignored).
# sessionStart: when the session is a resume, hand that note to the agent as additionalContext.
# Reads:   the event JSON on stdin. Env: HOOK_STATE_DIR (default .hooks-state).
param([string]$EventName)
$e = [Console]::In.ReadToEnd() | ConvertFrom-Json
$dir = $env:HOOK_STATE_DIR ?? '.hooks-state'
$file = Join-Path $dir 'checkpoint.txt'
if ($EventName -eq 'preCompact') {
  New-Item -ItemType Directory -Force $dir | Out-Null
  @("Saved $((Get-Date).ToUniversalTime().ToString('s') + 'Z')", "Branch: $(git branch --show-current)", 'Changed files:') + @(git status --short | Select-Object -First 20) | Set-Content $file
  '{}'
}
elseif ($e.source -eq 'resume' -and (Test-Path $file)) {
  @{ additionalContext = "Note saved before the session was compacted:`n" + (Get-Content $file -Raw) } | ConvertTo-Json -Compress
}
else { '{}' }

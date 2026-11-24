# Activity log hook. Usage: log.ps1 <eventName>
# Reads:   the event JSON on stdin.
# Writes:  one line (time, event, session, tool) to $env:HOOK_LOG_DIR/events.jsonl.
# Returns: {} (no decision). Prompts and tool arguments are deliberately NOT logged.
param([string]$EventName = 'unknown')
$e = [Console]::In.ReadToEnd() | ConvertFrom-Json
$dir = $env:HOOK_LOG_DIR ?? '.hooks-state'
New-Item -ItemType Directory -Force $dir | Out-Null
$time = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
[ordered]@{ time = $time; event = $EventName; sessionId = $e.sessionId; toolName = $e.toolName } |
  ConvertTo-Json -Compress | Add-Content (Join-Path $dir 'events.jsonl')
'{}'

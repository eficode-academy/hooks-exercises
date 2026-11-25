# Manual viewer (not a hook): prints the last 20 activity-log lines in a readable form.
$file = Join-Path ($env:HOOK_LOG_DIR ?? '.hooks-state') 'events.jsonl'
if (-not (Test-Path $file)) { 'No activity log yet.'; exit 0 }
Get-Content $file -Tail 20 | ConvertFrom-Json | ForEach-Object { "$($_.time)  $($_.event)  tool=$($_.toolName ?? '-')" }

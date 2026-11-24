# postToolUseFailure hook: log the failure and give the agent a hint instead of letting it guess.
# Reads:   the event JSON on stdin (toolName, error). The error text is never written to disk.
# Env:     HOOK_LOG_DIR (default .hooks-state); failures.log is written there.
# Returns: {"additionalContext": "Recovery hint: ..."}.
$e = [Console]::In.ReadToEnd() | ConvertFrom-Json
$dir = $env:HOOK_LOG_DIR ?? '.hooks-state'
New-Item -ItemType Directory -Force $dir | Out-Null
"$((Get-Date).ToUniversalTime().ToString('s') + 'Z') $($e.toolName ?? 'unknown') failed" | Add-Content (Join-Path $dir 'failures.log')
$error_ = $e.error | ConvertTo-Json -Compress
$hint = switch -Wildcard ($error_) {
  '*does not exist*'  { 'The path does not exist. Search for the file name before trying again.'; break }
  '*No such file*'    { 'The path does not exist. Search for the file name before trying again.'; break }
  '*denied*'          { 'Permission was denied. Do not work around it; ask the user.'; break }
  default             { 'Do not retry blindly. Find the cause, then try a different step.' }
}
@{ additionalContext = "Recovery hint: $hint" } | ConvertTo-Json -Compress

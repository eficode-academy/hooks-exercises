# preToolUse guard for file-editing tools (edit, create, apply_patch).
# Reads:   the event JSON on stdin; looks at toolArgs.path (or the patch text for apply_patch).
# Env:     PROTECTED_PATHS, ";"-separated list (default demo-app/config/production.json).
# Returns: a deny decision if the target contains a protected path, otherwise {} (no decision).
$e = [Console]::In.ReadToEnd() | ConvertFrom-Json
$a = $e.toolArgs
$target = "$($a.path ?? $a.filePath ?? $a.input ?? $a.patch)" -replace '\\', '/'
foreach ($p in ($env:PROTECTED_PATHS ?? 'demo-app/config/production.json') -split ';') {
  if ($target.Contains($p)) {
    @{ permissionDecision = 'deny'; permissionDecisionReason = "$p is protected. Edit another file or ask a human." } | ConvertTo-Json -Compress
    exit 0
  }
}
'{}'

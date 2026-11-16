#!/usr/bin/env pwsh
# Manual CLI: human-readable stdout, not a hook response.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Safe($Value) {
    if ($Value -is [string] -or ($Value -is [ValueType] -and $Value -isnot [bool])) {
        $text = ([string]$Value) -replace '[\x00-\x1f\x7f]', ' '
        return $text.Substring(0, [Math]::Min(256, $text.Length))
    }
    return '-'
}
try {
    $limit = if ($env:HOOK_LOG_LIMIT) { $env:HOOK_LOG_LIMIT } else { '100' }
    if ($limit -cnotmatch '^[0-9]{1,4}$' -or [int]$limit -lt 1 -or [int]$limit -gt 1000) {
        throw 'Invalid limit'
    }
    $directory = if ($env:HOOK_LOG_DIR) { $env:HOOK_LOG_DIR } else { '.hooks-state' }
    $file = Join-Path $directory 'events.jsonl'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        [Console]::Out.WriteLine('No activity log yet.')
        exit 0
    }
    foreach ($line in (Get-Content -LiteralPath $file -Tail ([int]$limit))) {
        $item = $line | ConvertFrom-Json -AsHashtable -Depth 64
        if ($item -isnot [System.Collections.IDictionary]) { throw 'Invalid record' }
        [Console]::Out.WriteLine(('{0}  {1}  session={2}  tool={3}' -f
            (Safe $item['timestamp']), (Safe $item['event']), (Safe $item['sessionId']), (Safe $item['toolName'])))
    }
} catch {
    [Console]::Error.WriteLine('show-log: invalid HOOK_LOG_LIMIT, unreadable file, or malformed JSONL (details withheld)')
    exit 1
}

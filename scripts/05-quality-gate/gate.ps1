#!/usr/bin/env pwsh
# agentStop: CHECK_STEPS=format:check;lint;test (1..3 distinct known labels).
# DEMO_DIR=demo-app; CHECK_TIMEOUT_SEC=10 (1..15 per step); HOOK_STATE_DIR=.hooks-state.
# Paths are subdirectories of event.cwd. State is informational, never a pass cache.
# stop_hook_active=true reruns checks, but reports repeated failure on stderr/exit 2.
$ErrorActionPreference = 'Stop'
try {
    $event = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
    if ($event -isnot [System.Collections.IDictionary]) { throw 'Expected one JSON event object' }
    $node = Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $event | ConvertTo-Json -Depth 100 -Compress | & $node.Source (Join-Path $PSScriptRoot 'gate.mjs')
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("quality-gate: $($_.Exception.Message)")
    [Console]::Out.WriteLine('{}')
    exit 2
}

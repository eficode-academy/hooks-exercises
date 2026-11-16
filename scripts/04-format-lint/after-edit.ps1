#!/usr/bin/env pwsh
# postToolUse edit/create/apply_patch. Native JSON parsing; Node bounds native local CLIs.
# DEMO_DIR=demo-app; FORMAT_ON_EDIT=true; LINT_ON_EDIT=true; CHECK_TIMEOUT_SEC=10 (1..10).
# Only existing non-symlink src/test JS/JSON files are formatted; ESLint receives JS only.
$ErrorActionPreference = 'Stop'
try {
    $event = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
    if ($event -isnot [System.Collections.IDictionary]) { throw 'Expected one JSON event object' }
    $node = Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $event | ConvertTo-Json -Depth 100 -Compress | & $node.Source (Join-Path $PSScriptRoot 'after-edit.mjs')
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("after-edit: $($_.Exception.Message)")
    [Console]::Out.WriteLine('{}')
    exit 2
}

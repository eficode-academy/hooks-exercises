#!/usr/bin/env pwsh
# preToolUse bash/powershell toolArgs.command only. GUARD_MODE=deny (default) or ask.
# Text heuristics, not a shell parser: quoted examples can match; aliases, quoting,
# obfuscation, global git options, and equivalent PowerShell commands can evade them.
# This hook never executes the supplied command.
$ErrorActionPreference = 'Stop'
try {
    $event = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
    if ($event -isnot [System.Collections.IDictionary] -or $event.cwd -isnot [string] -or
        $event.cwd -notmatch '^(/|[A-Za-z]:[/\\])' -or -not [IO.Directory]::Exists($event.cwd)) { throw 'Expected an existing absolute cwd' }
    $mode = if ($null -eq $env:GUARD_MODE) { 'deny' } else { $env:GUARD_MODE }
    if ($mode -cnotin @('deny', 'ask')) { throw 'GUARD_MODE must be deny or ask' }
    if ($event.toolName -is [string] -and $event.toolName -cnotin @('bash', 'powershell')) {
        [Console]::Out.WriteLine('{}')
        exit 0
    }
    if ($event.toolName -cnotin @('bash', 'powershell') -or $event.toolArgs -isnot [System.Collections.IDictionary] -or
        $event.toolArgs.command -isnot [string]) {
        @{ permissionDecision = 'deny'; permissionDecisionReason = 'Cannot safely inspect this command: expected bash/powershell toolArgs.command as a string.' } | ConvertTo-Json -Compress
        exit 0
    }
    $command = $event.toolArgs.command
    $risk = $null
    if ($command -match '(^|[\s;&|()])rm\s+(-[A-Za-z]*r[A-Za-z]*f[A-Za-z]*|-[A-Za-z]*f[A-Za-z]*r[A-Za-z]*|-[A-Za-z]*r[A-Za-z]*\s+-[A-Za-z]*f[A-Za-z]*|-[A-Za-z]*f[A-Za-z]*\s+-[A-Za-z]*r[A-Za-z]*)(\s|$)') {
        $risk = 'Recursive forced deletion (rm -rf)'
    } elseif ($command -match '(^|[\s;&|()])git\s+reset\s+[^\r\n;&|]*--hard(\s|$)') {
        $risk = 'Discarding changes (git reset --hard)'
    } elseif ($command -match '(^|[\s;&|()])git\s+push\s+[^\r\n;&|]*(--force(?:-with-lease(?:=[^\s;&|]+)?|-if-includes)?|-f)(\s|$)') {
        $risk = 'Rewriting remote history (git push --force/-f)'
    }
    if ($null -eq $risk) { [Console]::Out.WriteLine('{}') }
    else {
        @{ permissionDecision = $mode; permissionDecisionReason = "$risk is guarded. Inspect git status/diff, make a backup, and ask a human to run a reviewed recovery command instead. No command was executed by this hook." } | ConvertTo-Json -Compress
    }
} catch {
    [Console]::Error.WriteLine("guard-commands: $($_.Exception.Message)")
    [Console]::Out.WriteLine('{}')
    exit 2
}

#!/usr/bin/env pwsh
# preToolUse: edit/create path (validated filePath alias), or standard apply_patch input/patch.
# PROTECTED_PATHS is a semicolon-delimited exact file list, relative to event.cwd.
# Unrelated tools return {}; malformed supported edit payloads are denied.
# Lexical guard only: symlinks, shell writes, and alternative edit tools are not sandboxed.
$ErrorActionPreference = 'Stop'
function Normalize-Path([object]$Value, [string]$Base) {
    if ($Value -isnot [string] -or $Value.Length -eq 0 -or $Value -match '[\x00-\x1f]') { throw 'Invalid path' }
    $value = $Value.Replace('\', '/')
    if ($value.StartsWith('//')) { throw 'UNC paths are not supported' }
    if ($value -cmatch '^[A-Za-z]:($|[^/])') { throw 'Drive-relative paths are not supported' }
    if ($value.StartsWith('/') -and $Base -cmatch '^[A-Za-z]:[/\\]') { $value = $Base.Substring(0, 2) + $value }
    if (-not ($value.StartsWith('/') -or $value -cmatch '^[A-Za-z]:/')) { $value = "$Base/$value" }
    if ($value -cmatch '^[A-Za-z]:') { $value = $value.ToLowerInvariant() }
    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($part in $value.Split('/')) {
        if ($part -eq '' -or $part -eq '.') { continue }
        if ($part -eq '..') {
            if ($parts.Count -eq 0 -or ($parts.Count -eq 1 -and $parts[0] -cmatch '^[a-z]:$')) { throw 'Path escapes root' }
            $parts.RemoveAt($parts.Count - 1)
        } else { $parts.Add($part) }
    }
    if ($parts.Count -gt 0 -and $parts[0] -cmatch '^[a-z]:$') { return $parts -join '/' }
    return '/' + ($parts -join '/')
}
function Get-PatchPaths([object]$Patch) {
    if ($Patch -isnot [string]) { throw 'apply_patch needs string input or patch' }
    $lines = $Patch.Replace("`r`n", "`n").Split("`n")
    if ($lines[-1] -eq '') { $lines = $lines[0..($lines.Length - 2)] }
    if ($lines.Length -lt 3 -or $lines[0] -cne '*** Begin Patch' -or $lines[-1] -cne '*** End Patch') { throw 'Unknown patch envelope' }
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines[1..($lines.Length - 2)]) {
        if ($line -cmatch '^\*\*\* (Add File|Update File|Delete File|Move to): (.*)$') { $paths.Add($Matches[2]) }
        elseif ($line -ceq '*** End of File' -or $line.StartsWith('@@') -or $line -cmatch '^[ +\-]' -or $line -eq '') {
            if ($paths.Count -eq 0) { throw 'Patch content before a file header' }
        } else { throw 'Unknown patch syntax' }
    }
    if ($paths.Count -eq 0) { throw 'Patch has no file headers' }
    return $paths.ToArray()
}
try {
    $event = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
    if ($event -isnot [System.Collections.IDictionary] -or $event.cwd -isnot [string] -or
        $event.cwd -notmatch '^(/|[A-Za-z]:[/\\])' -or -not [IO.Directory]::Exists($event.cwd)) { throw 'Expected an existing absolute cwd' }
} catch {
    [Console]::Error.WriteLine("protect-files: $($_.Exception.Message)")
    [Console]::Out.WriteLine('{}')
    exit 2
}
if ($event.toolName -is [string] -and $event.toolName -cnotin @('edit', 'create', 'apply_patch')) {
    [Console]::Out.WriteLine('{}')
    exit 0
}
try {
    $cwd = Normalize-Path $event.cwd $event.cwd
    $setting = if ($null -eq $env:PROTECTED_PATHS) { 'demo-app/config/production.json' } else { $env:PROTECTED_PATHS }
    $protected = @($setting.Split(';') | ForEach-Object { Normalize-Path $_ $cwd })
    $args = $event.toolArgs
    if ($args -isnot [System.Collections.IDictionary]) { throw 'toolArgs must be an object' }
    $paths = @()
    if ($event.toolName -ceq 'edit' -or $event.toolName -ceq 'create') {
        if ($args.Contains('path')) { $paths = @(Normalize-Path $args.path $cwd) }
        if ($args.Contains('filePath')) {
            $alias = Normalize-Path $args.filePath $cwd
            if ($paths.Count -gt 0 -and $paths[0] -cne $alias) { throw 'path and filePath disagree' }
            $paths = @($alias)
        }
        if ($paths.Count -eq 0) { throw 'Missing path (or filePath alias)' }
    } elseif ($event.toolName -ceq 'apply_patch') {
        if ($args.Contains('input') -and $args.Contains('patch') -and $args.input -cne $args.patch) { throw 'input and patch disagree' }
        $patch = if ($args.Contains('input')) { $args.input } else { $args.patch }
        $paths = @(Get-PatchPaths $patch | ForEach-Object { Normalize-Path $_ $cwd })
    } else { throw 'Unsupported tool; use matcher edit|create|apply_patch' }
    $blocked = @($paths | Where-Object { $protected -ccontains $_ } | Sort-Object -Unique)
    if ($blocked.Count -gt 0) {
        @{ permissionDecision = 'deny'; permissionDecisionReason = "Protected file: $($blocked -join ', '). Edit an unprotected example instead, or ask a human to change PROTECTED_PATHS." } | ConvertTo-Json -Compress
    } else { [Console]::Out.WriteLine('{}') }
} catch {
    @{ permissionDecision = 'deny'; permissionDecisionReason = "Cannot safely inspect this edit: $($_.Exception.Message). Use a direct edit/create path or a standard apply_patch input." } | ConvertTo-Json -Compress
}

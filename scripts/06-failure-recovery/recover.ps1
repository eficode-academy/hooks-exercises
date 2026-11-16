#!/usr/bin/env pwsh
param([string]$EventName)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Fail([string]$Message) {
    [Console]::Error.WriteLine("failure-recovery: $Message")
    [Console]::Out.WriteLine('{"error":"failure-recovery failed"}')
    exit 1
}
function Read-Json([string]$Text) {
    function Convert-Element($Element) {
        switch ($Element.ValueKind.ToString()) {
            'Object' {
                $map = @{}
                foreach ($property in $Element.EnumerateObject()) { $map[$property.Name] = Convert-Element $property.Value }
                return $map
            }
            'Array' { return ,@(foreach ($item in $Element.EnumerateArray()) { Convert-Element $item }) }
            'String' { return $Element.GetString() }
            'Number' {
                $integer = 0L
                if ($Element.TryGetInt64([ref]$integer)) { return $integer }
                return $Element.GetDouble()
            }
            'True' { return $true }
            'False' { return $false }
            'Null' { return $null }
        }
    }
    # Keep ISO timestamps as strings, including on PowerShell before 7.5.
    $document = [System.Text.Json.JsonDocument]::Parse($Text)
    try { return Convert-Element $document.RootElement }
    finally { $document.Dispose() }
}
function Read-Payload {
    $buffer = [char[]]::new(262145)
    $length = 0
    while ($length -lt $buffer.Length) {
        $read = [Console]::In.Read($buffer, $length, $buffer.Length - $length)
        if ($read -eq 0) { break }
        $length += $read
    }
    if ($length -gt 262144) { Fail 'input exceeds character limit' }
    $value = Read-Json (-join $buffer[0..([Math]::Max(0, $length - 1))])
    if ($value -isnot [System.Collections.IDictionary]) { Fail 'expected a JSON object' }
    return $value
}
$locked = $false
$lock = $null
$temporary = $null
$exitCode = 0
try {
    if ($EventName -cnotin @('postToolUseFailure','postToolUse','errorOccurred')) { Fail 'unsupported event argument' }
    $limitText = if ($env:FAILURE_LIMIT) { $env:FAILURE_LIMIT } else { '3' }
    if ($limitText -cnotmatch '^[0-9]{1,3}$' -or [int]$limitText -lt 1 -or [int]$limitText -gt 100) {
        Fail 'FAILURE_LIMIT must be an integer from 1 to 100'
    }
    $limit = [int]$limitText
    $payload = Read-Payload
    if (-not $payload.Contains('sessionId') -or $payload.sessionId -isnot [string] -or
        $payload.sessionId.Length -eq 0 -or $payload.sessionId.Length -gt 256 -or $payload.sessionId -match '[\x00-\x1f\x7f]') {
        Fail 'expected a bounded sessionId'
    }
    $cwdPath = (Get-Location).Path
    if ($payload.Contains('cwd')) {
        $cwdPath = $payload.cwd
        if ($cwdPath -isnot [string] -or $cwdPath.Length -eq 0 -or $cwdPath.Length -gt 4096 -or $cwdPath -match '[\x00-\x1f\x7f]') {
            Fail 'invalid cwd'
        }
    }
    if (-not [IO.Path]::IsPathFullyQualified($cwdPath) -or -not (Test-Path -LiteralPath $cwdPath -PathType Container)) {
        Fail 'cwd must be an existing absolute directory'
    }
    $cwdPath = [IO.Path]::GetFullPath($cwdPath)
    if ($cwdPath.Length -gt [IO.Path]::GetPathRoot($cwdPath).Length) {
        $cwdPath = $cwdPath.TrimEnd([IO.Path]::DirectorySeparatorChar)
    }
    $keyBytes = [Text.Encoding]::UTF8.GetBytes($payload.sessionId + "`n" + $cwdPath)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $key = [BitConverter]::ToString($hasher.ComputeHash($keyBytes)).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
    $directory = if ($env:HOOK_STATE_DIR) { $env:HOOK_STATE_DIR } else { '.hooks-state' }
    if (-not [IO.Path]::IsPathFullyQualified($directory)) { $directory = Join-Path $cwdPath $directory }
    [void][IO.Directory]::CreateDirectory($directory)
    $file = Join-Path $directory "failures-$key.json"
    $lock = Join-Path $directory ".failures-$key.lock"
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $null = New-Item -ItemType Directory -Path $lock -ErrorAction Stop
            $locked = $true
            break
        } catch { Start-Sleep -Milliseconds 25 }
    }
    if (-not $locked) { Fail 'state lock unavailable; check for a stale lock' }
    $count = 0
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        if ((Get-Item -LiteralPath $file).Length -gt 1024) { Fail 'state exceeds size limit' }
        $state = Read-Json ([IO.File]::ReadAllText($file))
        if ($state -isnot [System.Collections.IDictionary] -or
            ($state['version'] -isnot [long] -and $state['version'] -isnot [int]) -or $state['version'] -ne 1 -or
            ($state['failures'] -isnot [long] -and $state['failures'] -isnot [int]) -or
            $state['failures'] -lt 0 -or $state['failures'] -gt 1000000) { Fail 'invalid failure state' }
        $count = [int]$state['failures']
    }
    $errorText = ''
    if ($payload.Contains('error')) {
        if ($payload.error -is [string]) { $errorText = $payload.error }
        elseif ($payload.error -is [System.Collections.IDictionary] -and $payload.error['message'] -is [string]) {
            $errorText = $payload.error['message']
        }
    }
    $category = if ($errorText -match 'denied|not permitted|forbidden|unauthorized') { 'denied' }
        elseif ($errorText -match 'missing script|missing npm script|unknown script') { 'missing-npm-script' }
        elseif ($errorText -match 'enoent|file not found|no such file|does not exist|cannot find (the )?(file|path)') { 'file-not-found' }
        elseif ($errorText -match 'test.*(fail|failure)|fail.*test|assertion|err_assertion') { 'test-failure' }
        else { 'other' }
    $errorText = $null
    $payload = $null
    if ($EventName -ceq 'errorOccurred') {
        [Console]::Error.WriteLine((@{event=$EventName;category=$category;failures=$count} | ConvertTo-Json -Compress))
        [Console]::Out.WriteLine('{}')
    } else {
        if ($EventName -ceq 'postToolUse') { $count = 0 } else { $count = [Math]::Min(1000000, $count + 1) }
        $temporary = Join-Path $lock 'state.json'
        $json = @{version=1;failures=$count} | ConvertTo-Json -Compress
        [IO.File]::WriteAllText($temporary, $json + "`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $file, $true)
        if ($EventName -ceq 'postToolUse') { [Console]::Out.WriteLine('{}') }
        else {
            $guidance = if ($count -ge $limit) {
                'Failure limit reached. Stop repeating the action; summarize the obstacle without raw errors and ask for human direction. Do not bypass permissions.'
            } else {
                switch ($category) {
                    'denied' { 'Permission denied. Do not repeat the action or try an alternate route around the denial; request authorized human direction.' }
                    'missing-npm-script' { 'Inspect available script names with npm run --prefix demo-app before choosing a supported command.' }
                    'file-not-found' { 'Search for the intended file with a bounded filename search; verify its path before trying again.' }
                    'test-failure' { 'Run the focused test for the affected behavior, inspect the failure privately, and address its cause rather than repeating the full suite.' }
                    default { 'Do not assume the action succeeded. Inspect the cause privately and choose a different, bounded diagnostic step rather than blindly retrying.' }
                }
            }
            $text = "Recovery guidance only (no retry executed). Category: $category; consecutive failures: $count. $guidance"
            [Console]::Out.WriteLine((@{additionalContext=$text} | ConvertTo-Json -Compress))
        }
    }
} catch { Fail 'invalid input or state access failed (details withheld)' }
finally {
    if ($locked) {
        if ($temporary -and [IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        [IO.Directory]::Delete($lock)
    }
}
exit $exitCode

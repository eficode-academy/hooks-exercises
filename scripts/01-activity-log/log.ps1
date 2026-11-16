#!/usr/bin/env pwsh
param([string]$EventName)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Fail([string]$Message) {
    [Console]::Error.WriteLine("activity-log: $Message")
    [Console]::Out.WriteLine('{"error":"activity-log failed"}')
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
function Get-Cwd($Payload) {
    $path = (Get-Location).Path
    if ($Payload.Contains('cwd')) {
        $path = $Payload.cwd
        if ($path -isnot [string] -or $path.Length -eq 0 -or $path.Length -gt 4096 -or $path -match '[\x00-\x1f\x7f]') {
            Fail 'invalid cwd'
        }
    }
    if (-not [IO.Path]::IsPathFullyQualified($path) -or -not (Test-Path -LiteralPath $path -PathType Container)) {
        Fail 'cwd must be an existing absolute directory'
    }
    return $path
}
$lock = $null
$locked = $false
try {
    if ($EventName -cnotin @('sessionStart','userPromptSubmitted','preToolUse','postToolUse','postToolUseFailure','errorOccurred','preCompact','subagentStart','subagentStop','agentStop','sessionEnd','notification')) {
        Fail 'unsupported event argument'
    }
    $payload = Read-Payload
    $cwdPath = Get-Cwd $payload
    $directory = if ($env:HOOK_LOG_DIR) { $env:HOOK_LOG_DIR } else { '.hooks-state' }
    if (-not [IO.Path]::IsPathFullyQualified($directory)) { $directory = Join-Path $cwdPath $directory }
    [void][IO.Directory]::CreateDirectory($directory)
    $record = [ordered]@{}
    foreach ($name in @('timestamp','sessionId','toolName','source','reason','trigger','agentName','errorContext')) {
        if (-not $payload.Contains($name)) { continue }
        $value = $payload[$name]
        if ($value -is [string]) {
            $value = $value -replace '[\x00-\x1f\x7f]', ' '
            $record[$name] = $value.Substring(0, [Math]::Min(256, $value.Length))
        } elseif (($value -is [ValueType]) -and $value -isnot [bool] -and
                  ($value -is [long] -or $value -is [int] -or $value -is [double] -or $value -is [decimal]) -and
                  [Math]::Abs([double]$value) -le 1000000000000000) {
            $record[$name] = $value
        }
    }
    $record.event = $EventName
    $line = ($record | ConvertTo-Json -Compress -Depth 4) + "`n"
    $lock = Join-Path $directory '.activity-log.lock'
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $null = New-Item -ItemType Directory -Path $lock -ErrorAction Stop
            $locked = $true
            break
        } catch { Start-Sleep -Milliseconds 25 }
    }
    if (-not $locked) { Fail 'log lock unavailable; check for a stale lock' }
    [IO.File]::AppendAllText((Join-Path $directory 'events.jsonl'), $line, [Text.UTF8Encoding]::new($false))
    [Console]::Out.WriteLine('{}')
} catch { Fail 'invalid input or metadata write failed (details withheld)' }
finally {
    if ($locked) { [IO.Directory]::Delete($lock) }
}

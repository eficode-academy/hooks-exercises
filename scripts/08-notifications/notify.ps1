$ErrorActionPreference = 'Stop'
try {
    $event = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
    if ($event -isnot [System.Collections.IDictionary]) {
        throw 'Expected a JSON event object.'
    }
    [Console]::Error.Write([char]7)
    [Console]::Out.WriteLine('{}')
}
catch {
    [Console]::Error.WriteLine('Notification skipped: expected a JSON event object.')
    [Console]::Out.WriteLine('{}')
    exit 2
}

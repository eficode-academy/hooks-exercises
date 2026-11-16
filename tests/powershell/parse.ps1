$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$files = Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1'
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$errors
    ) | Out-Null
    if ($errors.Count -gt 0) {
        throw "PowerShell parse error in $($file.FullName): $($errors[0].Message)"
    }
}
Write-Output "Parsed $($files.Count) PowerShell files."

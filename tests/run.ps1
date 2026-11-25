# Maintainer tests for the PowerShell track. Usage: pwsh -File tests/run.ps1
# Copies the repo to a temp folder, runs every case in tests/cases.txt through scripts/try-hook.ps1
# (so registration, matchers, env and helpers are all exercised), then runs extra checks.
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$work = Join-Path ([IO.Path]::GetTempPath()) "hooks-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory $work | Out-Null
foreach ($d in 'scripts', 'solutions', 'fixtures', 'demo-app') { Copy-Item (Join-Path $root $d) $work -Recurse }
Set-Location $work
git init -q; git add -A; git -c user.name=t -c user.email=t@t commit -q -m init
$script:total = 0; $script:failed = 0
function Pass { $script:total++ }
function Fail($msg) { "FAIL: $msg"; $script:failed++ }

function RunCase($config, $event, $fixture, $expect) {
  $err = Join-Path $work 'err.txt'
  $out = (pwsh -NoProfile -File scripts/try-hook.ps1 $config $event $fixture 2> $err) -join "`n"
  $json = try { $out | ConvertFrom-Json } catch { $null }
  $ok = switch -Wildcard ($expect) {
    'none'       { (Get-Content $err -Raw) -match ': 0 matching' }
    'empty'      { $out -eq '{}' }
    'deny'       { $json.permissionDecision -eq 'deny' }
    'block'      { $json.decision -eq 'block' }
    'context:*'  { "$($json.additionalContext)".Contains($expect.Substring(8)) }
  }
  Pass; if (-not $ok) { Fail "$event $fixture expected $expect, got: $out" }
}

foreach ($line in Get-Content (Join-Path $root 'tests/cases.txt')) {
  if ($line -eq '' -or $line.StartsWith('#')) { continue }
  if ($line -eq '@break') { Copy-Item fixtures/edit-examples/debug-leftover.js demo-app/src/; continue }
  if ($line -eq '@fix') { Remove-Item demo-app/src/debug-leftover.js; continue }
  $c = $line -split '\|', 4
  RunCase $c[0] $c[1] $c[2] $c[3]
}

# Activity log: one line per event, and no prompt or tool arguments on disk.
Pass; if ((Get-Content .hooks-state/events.jsonl).Count -ne 11) { Fail 'activity log should hold 11 lines' }
Pass; if (Get-ChildItem .hooks-state -Recurse -File | Select-String 'DO-NOT-LOG' | Select-Object -First 1) { Fail 'state files contain fixture payload text' }
Pass; if (-not ((pwsh -NoProfile -File scripts/01-activity-log/show-log.ps1) -match 'preToolUse')) { Fail 'show-log.ps1 output' }
Pass; if ((Get-Content .hooks-state/failures.log).Count -ne 2) { Fail 'failures.log should hold 2 lines' }

# A learner config: env values are honoured, matchers filter, disableAllHooks disables.
@'
{"version":1,"hooks":{"preToolUse":[{"type":"command","matcher":"edit|create","bash":"x",
 "powershell":"pwsh -NoProfile -File scripts/03-guardrails/protect-files.ps1","env":{"PROTECTED_PATHS":"demo-app/src/cart.js"}}]}}
'@ | Set-Content mine.json
RunCase mine.json preToolUse fixtures/events/preToolUse-edit-source.json deny
RunCase mine.json preToolUse fixtures/events/preToolUse-edit-protected.json empty
RunCase mine.json preToolUse fixtures/events/preToolUse-dangerous-command.json none
$off = Get-Content mine.json -Raw | ConvertFrom-Json; $off | Add-Member disableAllHooks $true
$off | ConvertTo-Json -Depth 10 | Set-Content off.json
RunCase off.json preToolUse fixtures/events/preToolUse-edit-source.json none

# Check stand-in, preflight, and the "keep it simple" rule.
Pass; pwsh -NoProfile -File demo-app/check.ps1 | Out-Null; if ($LASTEXITCODE -ne 0) { Fail 'check.ps1 should pass on the baseline' }
Copy-Item fixtures/edit-examples/debug-leftover.js demo-app/src/
Pass; pwsh -NoProfile -File demo-app/check.ps1 | Out-Null; if ($LASTEXITCODE -eq 0) { Fail 'check.ps1 should fail with a debug statement' }
Remove-Item demo-app/src/debug-leftover.js
Pass; pwsh -NoProfile -File scripts/preflight.ps1 | Out-Null; if ($LASTEXITCODE -ne 0) { Fail 'preflight' }
foreach ($f in Get-ChildItem scripts/0*/*.ps1) {
  Pass; if ((Get-Content $f).Count -gt 25) { Fail "$f is longer than 25 lines" }
  Pass; if (-not (Get-Content $f -TotalCount 3 | Where-Object { $_.StartsWith('#') })) { Fail "$f has no header comment" }
  Pass; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errors) | Out-Null
  if ($errors.Count) { Fail "$f does not parse: $($errors[0].Message)" }
}

# Solutions: valid JSON, version 1, both shells.
foreach ($f in Get-ChildItem solutions -Recurse -Filter *.json) {
  $cfg = Get-Content $f -Raw | ConvertFrom-Json
  foreach ($event in $cfg.hooks.PSObject.Properties) { foreach ($h in $event.Value) {
    Pass; if ($cfg.version -ne 1 -or -not $h.bash -or -not $h.powershell) { Fail "$f structure" }
    foreach ($s in ($h.bash, $h.powershell | ForEach-Object { $_ -split ' ' } | Where-Object { $_ -match '\.(sh|ps1)$' })) {
      Pass; if (-not (Test-Path $s)) { Fail "$f references missing $s" }
    }
  } }
}

# Every powershell block in exercises/00-07 runs, with the reference solutions installed as active hooks.
New-Item -ItemType Directory .github/hooks -Force | Out-Null
Copy-Item solutions/*/*.json .github/hooks/
$n = 0
foreach ($md in Get-ChildItem (Join-Path $root 'exercises/0*.md')) {
  foreach ($m in [regex]::Matches((Get-Content $md -Raw), '(?s)```powershell\r?\n(.*?)```')) {
    $n++; $file = Join-Path $work "block-$n.ps1"; $m.Groups[1].Value | Set-Content $file
    pwsh -NoProfile -File $file *> $null
    Pass; if ($LASTEXITCODE -ne 0) { Fail "$($md.Name) block $n failed" }
  }
}

Set-Location $root
Remove-Item $work -Recurse -Force
"PowerShell track: $($total - $failed)/$total checks passed"
exit ($failed -gt 0 ? 1 : 0)

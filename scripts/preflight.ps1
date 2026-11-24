# Preflight for the hooks exercises. Usage: pwsh -File scripts/preflight.ps1   (run from the repository root)
# Checks the tools, their versions, and that a hook helper really runs in this shell.
# Exit code 1 only if a required tool (git, PowerShell 7) is missing; the rest are warnings.
$fail = $false
function Check($name, $required, $why) {
  if (Get-Command $name -ErrorAction SilentlyContinue) { '  ok       {0,-8} {1}' -f $name, ((& $name --version 2>&1) | Select-Object -First 1) }
  elseif ($required) { '  MISSING  {0,-8} {1}' -f $name, $why; $script:fail = $true }
  else { '  missing  {0,-8} {1}' -f $name, $why }
}
'Tools'
'  ok       pwsh     PowerShell {0}' -f $PSVersionTable.PSVersion
if ($PSVersionTable.PSVersion.Major -lt 7) { '  MISSING  pwsh     the hook scripts need PowerShell 7 (pwsh)'; $fail = $true }
Check git $true 'needed for the exercises'
Check copilot $false 'needed for the live parts (Copilot CLI)'
Check gh $false 'only needed to sign in or install Copilot CLI extras'

'Hooks'
$out = '{"toolName":"bash","toolArgs":{"command":"git reset --hard"}}' | pwsh -NoProfile -File scripts/03-guardrails/guard-commands.ps1
if ($out -match '"deny"') { '  ok       guard helper runs here and denies a dangerous command' }
else { "  FAILED   guard helper did not return a deny decision: $out"; $fail = $true }
$configs = @("$HOME/.copilot/config.json") + @(Get-ChildItem .github/hooks/*.json -ErrorAction SilentlyContinue)
if ($configs | Where-Object { Test-Path $_ } | Select-String -Pattern '"disableAllHooks"\s*:\s*true' -Quiet) {
  '  WARNING  disableAllHooks is true in your Copilot config or .github/hooks/'
}
'  note     Whether your organization allows hooks can only be proven live: finish exercise 01 and'
'           check that .hooks-state/events.jsonl gets lines. See docs/troubleshooting.md if not.'
if ($fail) { 'Preflight found problems above.'; exit 1 } else { 'Preflight passed.' }

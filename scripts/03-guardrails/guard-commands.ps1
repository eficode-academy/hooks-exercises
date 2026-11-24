# preToolUse guard for shell tools (bash, powershell). A plain text match, not a shell parser.
# Reads:   the event JSON on stdin; looks at toolArgs.command.
# Env:     GUARD_MODE, "deny" (default) or "ask" (let a human decide).
# Returns: a decision for rm -rf, git push --force, git reset --hard and curl | sh; otherwise {}.
$e = [Console]::In.ReadToEnd() | ConvertFrom-Json
$cmd = "$($e.toolArgs.command)"
function Block($why) {
  [ordered]@{ permissionDecision = ($env:GUARD_MODE ?? 'deny'); permissionDecisionReason = $why } | ConvertTo-Json -Compress
  exit 0
}
if ($cmd -like '*rm -rf*' -or $cmd -like '*rm -fr*') { Block 'rm -rf is blocked. Delete specific files instead.' }
if ($cmd -like '*git push*--force*' -or $cmd -like '*git push* -f*') { Block 'Force push is blocked. Use a normal push or open a pull request.' }
if ($cmd -like '*git reset --hard*') { Block 'git reset --hard throws work away. Ask a human first.' }
if ($cmd -like '*curl*| sh*' -or $cmd -like '*curl*| bash*') { Block 'Piping a download into a shell is blocked.' }
'{}'

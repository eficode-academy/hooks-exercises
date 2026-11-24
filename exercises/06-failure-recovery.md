# 06 · Failure recovery

**Stretch · about 10 minutes**

## Problem

When a tool call fails, an agent tends to guess: retry, work around a
permission, or invent a path. At a bank, "work around the permission" is exactly
what you do not want. A `postToolUseFailure` hook can log the failure and hand the
agent a short, safe hint before its next move.

## Task

Write `.github/hooks/failure-recovery.json` from a blank file.

1. Register `postToolUseFailure` with `bash scripts/06-failure-recovery/recover.sh`
   and `pwsh -NoProfile -File scripts/06-failure-recovery/recover.ps1`.
2. Add `"env": { "HOOK_LOG_DIR": ".hooks-state" }` and `"timeoutSec": 5`.

The script is about 15 lines: it reads `toolName` and `error` from stdin, appends
`time tool failed` to `.hooks-state/failures.log` (never the error text), and
returns a hint as `additionalContext`: "path does not exist", "permission denied",
or a generic "do not retry blindly". Compare with
`solutions/06-failure-recovery/failure-recovery.json` afterwards.

## Check

**Bash**

```bash
bash scripts/try-hook.sh .github/hooks/failure-recovery.json postToolUseFailure fixtures/events/postToolUseFailure-missing-file.json
bash scripts/try-hook.sh .github/hooks/failure-recovery.json postToolUseFailure fixtures/events/postToolUseFailure-permission-denied.json
bash scripts/try-hook.sh .github/hooks/failure-recovery.json postToolUse fixtures/events/postToolUse-read.json
cat .hooks-state/failures.log
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 .github/hooks/failure-recovery.json postToolUseFailure fixtures/events/postToolUseFailure-missing-file.json
pwsh -File scripts/try-hook.ps1 .github/hooks/failure-recovery.json postToolUseFailure fixtures/events/postToolUseFailure-permission-denied.json
pwsh -File scripts/try-hook.ps1 .github/hooks/failure-recovery.json postToolUse fixtures/events/postToolUse-read.json
Get-Content .hooks-state/failures.log
```

Expect two different hints, `0 matching hook(s)` for the success event, and two
log lines with no error text.

**Live:** ask *"Use view to read demo-app/src/no-such-file.js once. Do not retry. Quote any recovery hint you received."*
The agent should quote the hint. A failing shell command (non-zero exit) is
often reported as a normal `postToolUse`, not a failure: that is the client's choice.

## Stretch

Add a new `case` pattern of your own to the script for an error you have seen.
To disable: move the file out and start a fresh session.

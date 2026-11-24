# 07 · Session recovery

**Stretch · about 10 minutes**

## Problem

Long agent sessions get compacted: the client summarizes the conversation to
free space, and details such as "which files was I changing?" can vanish. A bank
team that resumes work the next day wants the agent oriented immediately. A
`preCompact` hook writes a small note; a `sessionStart` hook shows it when the
session is resumed.

## Task

Write `.github/hooks/session-recovery.json` from a blank file.

1. Register `preCompact` with `bash scripts/07-session-recovery/checkpoint.sh preCompact`
   and `pwsh -NoProfile -File scripts/07-session-recovery/checkpoint.ps1 preCompact`.
2. Register `sessionStart` with the same helper, passing `sessionStart`.
3. Add `"env": { "HOOK_STATE_DIR": ".hooks-state" }` and `"timeoutSec": 5` to both.

The script is about 15 lines: on `preCompact` it writes the branch and changed
files to `.hooks-state/checkpoint.txt`; on `sessionStart` it returns that note as
`additionalContext`, but only when the event's `source` is `resume`.
Compare with `solutions/07-session-recovery/session-recovery.json` afterwards.

## Check

**Bash**

```bash
bash scripts/try-hook.sh .github/hooks/session-recovery.json preCompact fixtures/events/preCompact.json
cat .hooks-state/checkpoint.txt
bash scripts/try-hook.sh .github/hooks/session-recovery.json sessionStart fixtures/events/sessionStart-new.json
bash scripts/try-hook.sh .github/hooks/session-recovery.json sessionStart fixtures/events/sessionStart-resume.json
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 .github/hooks/session-recovery.json preCompact fixtures/events/preCompact.json
Get-Content .hooks-state/checkpoint.txt
pwsh -File scripts/try-hook.ps1 .github/hooks/session-recovery.json sessionStart fixtures/events/sessionStart-new.json
pwsh -File scripts/try-hook.ps1 .github/hooks/session-recovery.json sessionStart fixtures/events/sessionStart-resume.json
```

Expect a note file with the branch and changed files, `{}` for the new session
(nothing to restore), and `additionalContext` with the note for the resume.

**Live:** do some work, type `/compact`, exit, then `copilot --resume <id>` (use
the id printed on exit; `--continue` picks the newest session on the machine).
Ask *"Without using tools, which branch and files were we working on?"*
This restores working-tree facts, not the conversation.

## Stretch

Put the note in a different `HOOK_STATE_DIR` and explain what that changes.
To disable: move the file out and start a fresh session.

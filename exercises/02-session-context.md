# 02 · Session context

**Core · about 10 minutes**

## Problem

Your bank has house rules: money is integer cents, never touch production
config, never print secrets. Developers paste them into prompts when they
remember to. A `sessionStart` hook gives every session (and every subagent) the
same briefing, plus fresh facts such as the branch and recent commits.

## Task

Write `.github/hooks/session-context.json` from a blank file.

1. Register `sessionStart` with
   `bash scripts/02-session-context/briefing.sh sessionStart` and
   `pwsh -NoProfile -File scripts/02-session-context/briefing.ps1 sessionStart`.
2. Add `"env": { "DEMO_DIR": "demo-app" }` and `"timeoutSec": 5`.
3. Register `subagentStart` the same way, passing `subagentStart` as the argument.

Skim `scripts/02-session-context/briefing.sh`: the event comes in on stdin (it is
not needed), the house rules and `git` facts go out as `additionalContext`.
`DEMO_DIR` only changes the folder named in the rules.
Compare with `solutions/02-session-context/session-context.json` afterwards.

## Check

**Bash**

```bash
bash scripts/try-hook.sh .github/hooks/session-context.json sessionStart fixtures/events/sessionStart-new.json
bash scripts/try-hook.sh .github/hooks/session-context.json subagentStart fixtures/events/subagentStart.json
bash scripts/try-hook.sh .github/hooks/session-context.json postToolUse fixtures/events/postToolUse-read.json
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 .github/hooks/session-context.json sessionStart fixtures/events/sessionStart-new.json
pwsh -File scripts/try-hook.ps1 .github/hooks/session-context.json subagentStart fixtures/events/subagentStart.json
pwsh -File scripts/try-hook.ps1 .github/hooks/session-context.json postToolUse fixtures/events/postToolUse-read.json
```

Expect `additionalContext` with the house rules and branch for the first two, and
`0 matching hook(s)` for the third (wrong event, so no briefing).

**Live:** start a fresh session and ask: *"Which rules apply to money in this
project, and which check should I run before finishing?"* The answer should
quote the house rules. If you kept the activity log on, `sessionStart` appears there.
A correct answer alone is weak evidence (the model may guess): use the log.

## Stretch

Register only `subagentStart`, then only `sessionStart`, and explain the
difference in scope. To disable: move the file out and start a fresh session.

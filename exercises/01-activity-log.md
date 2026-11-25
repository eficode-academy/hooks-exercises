# 01 · Activity log

**Core · about 15 minutes**

## Problem

Compliance asks: "What did the agent actually do in our repository last
Tuesday?" Without a record, nobody can say. A hook on every event can write a
small audit trail (when, which event, which tool) without storing prompts or file
contents, which may contain customer data.

## Task

Write `.github/hooks/activity-log.json` from a blank file.

1. Start with `"version": 1` and `"hooks": {}`.
2. Add `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse` and
   `sessionEnd`. Each is a one-entry array of `type: "command"`.
3. For each, set `bash` and `powershell` to the helper plus the **event name** as
   its argument:
   `bash scripts/01-activity-log/log.sh preToolUse` and
   `pwsh -NoProfile -File scripts/01-activity-log/log.ps1 preToolUse`.
4. Add `"timeoutSec": 5`. Do not add a `matcher`: you want to see every tool call.

Skim `scripts/01-activity-log/log.sh` (or `log.ps1`) first: it reads the event on
stdin, appends one metadata line to `.hooks-state/events.jsonl`, and returns `{}`.
`HOOK_LOG_DIR` in `env` changes the folder. Compare with
`solutions/01-activity-log/activity-log.json` when you are done.

## Check

**Offline** (`show-log` is a viewer, not a hook; do not register it):

**Bash**

```bash
bash scripts/try-hook.sh .github/hooks/activity-log.json sessionStart fixtures/events/sessionStart-new.json
bash scripts/try-hook.sh .github/hooks/activity-log.json preToolUse fixtures/events/preToolUse-edit-protected.json
bash scripts/01-activity-log/show-log.sh
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 .github/hooks/activity-log.json sessionStart fixtures/events/sessionStart-new.json
pwsh -File scripts/try-hook.ps1 .github/hooks/activity-log.json preToolUse fixtures/events/preToolUse-edit-protected.json
pwsh -File scripts/01-activity-log/show-log.ps1
```

Expect `1 matching hook(s)` each time and two lines in the viewer, with the event
and tool name but no prompt text or file contents.

**Live:** start a fresh session in this folder and run the viewer after each step.

| Prompt | Look for |
| --- | --- |
| Start the session | `sessionStart` |
| "Read demo-app/src/cart.js and explain calculateTotal." | `userPromptSubmitted`, then `preToolUse` / `postToolUse` with a tool name |
| Exit the session | `sessionEnd` (if your client sends it) |

A missing event is a finding, not a failure: see [troubleshooting](../docs/troubleshooting.md).

## Stretch

Add the remaining events (`postToolUseFailure`, `errorOccurred`, `preCompact`,
`subagentStart`, `subagentStop`, `agentStop`) and keep the log running while you
do the other exercises, so you can see their events too.
To disable: move the file out of `.github/hooks/` and start a fresh session.

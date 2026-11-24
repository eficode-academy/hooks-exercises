# Extra · Completion cue

**Stretch · about 10 minutes**

## Problem

Agents take minutes. Engineers who context-switch to a review or a stand-up miss
the moment the agent needs them. An `agentStop` hook can ring the terminal bell
when the agent finishes or hands back.

## Task

Write `.github/hooks/notifications.json`: register `agentStop` with
`bash scripts/08-notifications/notify.sh` and
`pwsh -NoProfile -File scripts/08-notifications/notify.ps1`, with
`"timeoutSec": 5`. The script is 3 lines: the bell goes to stderr, `{}` to stdout.
Compare with `solutions/08-notifications/notifications.json`.

## Check

**Bash**

```bash
bash scripts/try-hook.sh .github/hooks/notifications.json agentStop fixtures/events/agentStop.json
bash scripts/try-hook.sh .github/hooks/notifications.json sessionEnd fixtures/events/sessionEnd.json
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 .github/hooks/notifications.json agentStop fixtures/events/agentStop.json
pwsh -File scripts/try-hook.ps1 .github/hooks/notifications.json sessionEnd fixtures/events/sessionEnd.json
```

Expect `{}` (and maybe a beep) for `agentStop`, and `0 matching hook(s)` for
`sessionEnd`. Live: ask *"Run the demo check once, then summarize."* A terminal
may mute the bell. The cue fires on every stop attempt, even when another hook
blocks the stop, so it does not mean "checks passed".

## Stretch

In the CLI only, add a `notification` entry with `matcher: "permission_prompt"`
using the same helper and the `notification.json` fixture. To disable: move the
file out and start a fresh session.

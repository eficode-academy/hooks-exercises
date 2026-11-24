# 05 · Quality gate

**Stretch · about 15 minutes**

## Problem

"The agent said it was done" is not evidence. Before a change reaches review,
your pipeline would run the tests; a bank usually wants that to happen **before
the agent hands work back**. An `agentStop` hook runs the check when the agent
tries to finish, and blocks the stop once if it fails so the agent fixes it first.

## Task

Write `.github/hooks/quality-gate.json` from a blank file.

1. Register `agentStop` (not `sessionEnd`: that fires too late to block
   anything) with `bash scripts/05-quality-gate/gate.sh` and
   `pwsh -NoProfile -File scripts/05-quality-gate/gate.ps1`.
2. Set `"timeoutSec": 60`: it must be longer than your check takes to run.

The gate is about 15 lines: it runs the same single check as exercise 04 and,
if it fails, returns `{"decision": "block", "reason": "..."}`. When the agent
comes back and tries again, the event carries `stop_hook_active: true`; the gate
lets it stop then, so a stubborn failure cannot loop forever. Use
`env.CHECK_COMMAND` for your own check. Compare with
`solutions/05-quality-gate/quality-gate.json` afterwards.

## Check

**Bash**

```bash
bash scripts/try-hook.sh .github/hooks/quality-gate.json agentStop fixtures/events/agentStop.json
cp fixtures/edit-examples/debug-leftover.js demo-app/src/
bash scripts/try-hook.sh .github/hooks/quality-gate.json agentStop fixtures/events/agentStop.json
bash scripts/try-hook.sh .github/hooks/quality-gate.json agentStop fixtures/events/agentStop-retry.json
rm demo-app/src/debug-leftover.js
bash scripts/try-hook.sh .github/hooks/quality-gate.json sessionEnd fixtures/events/sessionEnd.json
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 .github/hooks/quality-gate.json agentStop fixtures/events/agentStop.json
Copy-Item fixtures/edit-examples/debug-leftover.js demo-app/src/
pwsh -File scripts/try-hook.ps1 .github/hooks/quality-gate.json agentStop fixtures/events/agentStop.json
pwsh -File scripts/try-hook.ps1 .github/hooks/quality-gate.json agentStop fixtures/events/agentStop-retry.json
Remove-Item demo-app/src/debug-leftover.js
pwsh -File scripts/try-hook.ps1 .github/hooks/quality-gate.json sessionEnd fixtures/events/sessionEnd.json
```

Expect `{}` (passing), then a `block` decision with the check output, then `{}`
for the retry (already blocked once), and `0 matching hook(s)` for `sessionEnd`.
If the copy step is interrupted, delete `demo-app/src/debug-leftover.js` yourself.

**Live:** put the debug file in place, then ask *"Summarize calculateTotal."* The
agent should be sent back once to fix the check. Delete the file afterwards.
If your client ignores the block, mark it unverified and keep CI as the real gate.

## Stretch

Set `env.CHECK_COMMAND` to your project's real test command and a larger `timeoutSec`.
To disable: move the file out and start a fresh session.

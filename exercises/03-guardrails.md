# 03 · Guardrails

**Core · about 20 minutes**

## Problem

An agent that can run shell commands can also run `git push --force`, `rm -rf`
or `curl ... | sh`, and one that can edit files can edit
`config/production.json`. At a bank a single such action is an incident.
A `preToolUse` hook sees the call **before** it runs and can deny it, and tells
the agent why so it picks a safer route.

## Task

Write `.github/hooks/guardrails.json` with one `preToolUse` array holding **two**
entries.

1. File guard: `matcher: "edit|create|apply_patch"`, commands
   `bash scripts/03-guardrails/protect-files.sh` and
   `pwsh -NoProfile -File scripts/03-guardrails/protect-files.ps1`, and
   `"env": { "PROTECTED_PATHS": "demo-app/config/production.json" }`.
2. Command guard: `matcher: "bash|powershell"`, commands
   `bash scripts/03-guardrails/guard-commands.sh` and
   `pwsh -NoProfile -File scripts/03-guardrails/guard-commands.ps1`, and
   `"env": { "GUARD_MODE": "deny" }`.
3. Add `"timeoutSec": 5` to both. Event name arguments are not needed.
4. Why can both guards not share one matcher? (They read different fields.)

Skim both scripts (about 15 lines each): the tool call arrives on stdin, a
decision goes out as JSON. `protect-files` checks the target path against the
semicolon-separated `PROTECTED_PATHS`; `guard-commands` looks for four plain
patterns: `rm -rf`, `git push --force` (or `-f`), `git reset --hard`, and
`curl ... | sh`. `GUARD_MODE: "ask"` lets a human decide instead of denying.
Compare with `solutions/03-guardrails/guardrails.json` afterwards.

## Check

**Bash**

```bash
bash scripts/try-hook.sh .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-edit-protected.json
bash scripts/try-hook.sh .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-edit-source.json
bash scripts/try-hook.sh .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-force-push.json
bash scripts/try-hook.sh .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-rm-rf.json
bash scripts/try-hook.sh .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-curl-pipe.json
bash scripts/try-hook.sh .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-safe-command.json
bash scripts/try-hook.sh .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-read.json
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-edit-protected.json
pwsh -File scripts/try-hook.ps1 .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-edit-source.json
pwsh -File scripts/try-hook.ps1 .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-force-push.json
pwsh -File scripts/try-hook.ps1 .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-rm-rf.json
pwsh -File scripts/try-hook.ps1 .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-curl-pipe.json
pwsh -File scripts/try-hook.ps1 .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-safe-command.json
pwsh -File scripts/try-hook.ps1 .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-read.json
```

Expect `deny` for the protected path, force push, `rm -rf` and `curl | sh`; `{}`
(no decision) for the source edit and the safe command; and
`0 matching hook(s)` for the read (matchers pick tools by name). The dangerous
strings are inert test data: the runner never executes them, and neither should you.

**Live** (stop if denied, do not let the agent work around it):

| Prompt | Expected |
| --- | --- |
| "Add a comment to demo-app/config/production.json using a direct file edit. If denied, stop." | Denied with the protected-file reason; file unchanged |
| "Add a comment to demo-app/src/cart.js." | Not denied |
| "Run `echo hook-demo`." | Allowed |

Never test the destructive patterns with real prompts. If nothing is denied, the
tool name or payload shape may differ from the matcher: check the activity log.

## Stretch

Add a second protected path to `PROTECTED_PATHS` with `;`. Switch
`GUARD_MODE` to `"ask"` and note what changes. These checks are text matches and
complement permissions and code review; they are not a security boundary
([limits](../docs/compatibility.md#what-the-guardrails-do-not-cover)).
To disable: move the file out and start a fresh session.

# 04 · Check after edits

**Stretch · about 15 minutes**

## Problem

Agents leave things behind: a stray debug statement, a malformed config. In a
bank those reach code review, or worse. A `postToolUse` hook can run your
project's own check right after every edit and feed the failure straight back to
the agent, while it still has the context to fix it.

## Task

Write `.github/hooks/format-lint.json` from a blank file.

1. Register `postToolUse` with `matcher: "edit|create|apply_patch"` and the
   commands `bash scripts/04-format-lint/after-edit.sh` and
   `pwsh -NoProfile -File scripts/04-format-lint/after-edit.ps1`.
2. Add `"timeoutSec": 30`.

The wrapper is about 10 lines: it runs **one check command** and returns its
output as `additionalContext` when the check fails. By default it runs the
demo's stand-in, `demo-app/check.sh` (`check.ps1`), which fails on leftover
`console.log` / `debugger` in `demo-app/src/` and on invalid config JSON.
Set `env.CHECK_COMMAND` to use your own (`make test`, `pytest -q`, ...).
Compare with `solutions/04-format-lint/format-lint.json` afterwards.

## Check

Passing check, then a deliberately failing one (the last line cleans up):

**Bash**

```bash
bash scripts/try-hook.sh .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-edit.json
cp fixtures/edit-examples/debug-leftover.js demo-app/src/
bash scripts/try-hook.sh .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-edit.json
rm demo-app/src/debug-leftover.js
bash scripts/try-hook.sh .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-read.json
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-edit.json
Copy-Item fixtures/edit-examples/debug-leftover.js demo-app/src/
pwsh -File scripts/try-hook.ps1 .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-edit.json
Remove-Item demo-app/src/debug-leftover.js
pwsh -File scripts/try-hook.ps1 .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-read.json
```

Expect `{}` first, then `additionalContext` naming the debug statement, then
`0 matching hook(s)` for the read. A post-tool hook cannot undo an edit; it only
reports.

**Live:** ask *"Add a log line to calculateTotal in demo-app/src/cart.js that prints the total."*
The agent should see the check failure and remove the line.

## Stretch

Set `CHECK_COMMAND` to a command of your own and re-run the checks.
To disable: move the file out and start a fresh session.

# 01 · Activity log

## Goal

See which hooks are called, in what order, and with which minimal metadata.
This optional observer is useful alongside other topics, but they do not depend
on it.

## Events

Choose any/all of `sessionStart`, `userPromptSubmitted`, `preToolUse`,
`postToolUse`, `postToolUseFailure`, `errorOccurred`, `preCompact`,
`subagentStart`, `subagentStop`, `agentStop`, and `sessionEnd`. The optional
`notification` event is CLI-only; do not assume every client emits every event.

## Read the supplied script / environment options

Read `scripts/01-activity-log/log.sh` or `log.ps1`. Pass the exact event name
as its first argument. `HOOK_LOG_DIR` defaults to `.hooks-state`.
The helper records metadata only, not raw prompts, tool arguments, source, or
errors. `show-log.sh` / `show-log.ps1` is a **manual viewer**, not a hook.
Do not register it as a handler.

## Task: write `.github/hooks/activity-log.json` yourself

1. Start a blank JSON file with `version: 1` and `hooks`.
2. Add a `sessionStart` command entry. Use
   `bash scripts/01-activity-log/log.sh sessionStart` and
   `pwsh -NoProfile -File scripts/01-activity-log/log.ps1 sessionStart`.
3. Set a small `timeoutSec` and explicitly set `env.HOOK_LOG_DIR` if you want
   another local folder. Keep values strings.
4. Register prompt and tool events, passing each entry's matching event name.
   Do not add a tool matcher yet: you want to observe all tool calls.
5. Add the remaining lifecycle events you want to investigate.

Compare only after trying: `solutions/01-activity-log/activity-log.json`.
That reference is inactive until you deliberately install a configuration.

## Offline fixture commands

**Bash**

```bash
node tests/validate-configs.mjs .github/hooks/activity-log.json
node tests/try-hook.mjs .github/hooks/activity-log.json sessionStart fixtures/events/sessionStart-new.json --shell bash
node tests/try-hook.mjs .github/hooks/activity-log.json preToolUse fixtures/events/preToolUse-edit-protected.json --shell bash
node tests/try-hook.mjs .github/hooks/activity-log.json postToolUseFailure fixtures/events/postToolUseFailure-missing-file.json --shell bash
bash scripts/01-activity-log/show-log.sh
```

**PowerShell**

```powershell
node tests/validate-configs.mjs .github/hooks/activity-log.json
node tests/try-hook.mjs .github/hooks/activity-log.json sessionStart fixtures/events/sessionStart-new.json --shell powershell
node tests/try-hook.mjs .github/hooks/activity-log.json preToolUse fixtures/events/preToolUse-edit-protected.json --shell powershell
node tests/try-hook.mjs .github/hooks/activity-log.json postToolUseFailure fixtures/events/postToolUseFailure-missing-file.json --shell powershell
pwsh -NoProfile -File scripts/01-activity-log/show-log.ps1
```

Expect metadata records for the supplied events. These are **synthetic** records;
distinguish them from your subsequent live session records by session metadata.
Use the same `HOOK_LOG_DIR` for writer and viewer if you override it.

**No-trigger control:** temporarily add root-level `"disableAllHooks": true`
to your JSON, repeat the start call, and expect `0 matching hook(s)` with no
new record. Remove the flag before the live checks.

## Live prompts and observations

Start a fresh session with your JSON active. Inspect the viewer after each row.

| Action/prompt | Event(s) to look for | Expected outcome |
| --- | --- | --- |
| Start a new session | `sessionStart` | A live session record, separate from fixtures |
| “Read demo-app/src/cart.js and explain calculateTotal.” | `userPromptSubmitted`, then tool pre/post if used | Tool metadata without file contents |
| “Run npm --prefix demo-app test.” | Tool pre/post, then possibly `agentStop` | Successful check and observable tool lifecycle |
| “Use view to read demo-app/src/no-such-file.js once; do not create or retry.” | `postToolUseFailure` if the runtime classifies it as a failed tool | Failure metadata; this event was observed for missing-file `view` in CLI 1.0.105 |
| “Run npm --prefix demo-app run missing-hook-demo and report the error; don't install anything.” | Often `postToolUse`, not necessarily failure event | Nonzero shell exit is not the same as a failed tool |
| “Use an explore subagent to summarize the demo tests, if available.” | `subagentStart` / `subagentStop` if emitted | Observe rather than assume subagent support |
| In CLI, manually run `/compact` | `preCompact` if supported | A compaction record; not an unattended prompt guarantee |
| Exit the session | `sessionEnd` if emitted | Client-dependent; absence is a finding |

An event can be absent because no tool was chosen, the event is unsupported,
configuration was not loaded, or policy prevented execution. Investigate with
[troubleshooting](../docs/troubleshooting.md), not by logging sensitive payloads.

## Configuration-only stretch

Add a second observer configuration using a different `HOOK_LOG_DIR` and only
tool events, then remove it after comparing. What changes if you add a matcher?
Avoid registering duplicate writes to the same log accidentally.

## Reuse / disable

Optionally keep this configuration enabled while exploring other topics to
observe their live events. For a real project, select only events you need and
choose retention/access controls for local metadata.
Disable by moving `activity-log.json` out of `.github/hooks/` and restarting.

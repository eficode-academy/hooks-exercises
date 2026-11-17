# 06 · Recovery after failed tools

## Goal

Provide targeted recovery guidance and a bounded failure count without blindly
retrying commands or turning this into a shell scripting task.

## Events

`postToolUseFailure`, `postToolUse`, and `errorOccurred`.

## Read the supplied script / environment options

`scripts/06-failure-recovery/recover.sh` / `recover.ps1` accepts the event name.
`FAILURE_LIMIT` defaults to `3`; `HOOK_STATE_DIR` defaults to `.hooks-state`.
The helper classifies raw error details in memory, without logging them. It
offers recovery context rather than executing automatic retries.
A `postToolUse` completion resets the counter; repeated failure events reach a limit
that calls for human action, not continued autonomous guessing.

Whether a nonzero shell command exit becomes `postToolUseFailure` or a completed
shell-tool result is runtime-dependent. For `postToolUseFailure` the helper
returns `{"additionalContext": "Recovery guidance ..."}`; other modes return `{}`.
Verified live in CLI 1.0.105 (Bash, macOS): after a missing-file `view`, the
agent quoted the guidance back verbatim. The reference also describes plain
stdout with exit 2; that variant was **not** delivered to the model in our
probe, so the helper uses JSON. Guidance is advice. Whether the agent follows
it is up to the model.

## Task: write `.github/hooks/failure-recovery.json` yourself

1. Register three event entries, each passing its own exact name to the helper.
2. Supply both shell commands, a short `timeoutSec`, and the two environment
   options as strings.
3. Do not register an automatic shell retry or modify the helper.
4. Decide whether a matcher would accidentally hide successes needed to reset
   the count. Start without one.

Compare with `solutions/06-failure-recovery/failure-recovery.json`.

## Offline fixture commands

**Bash**

```bash
node tests/validate-configs.mjs .github/hooks/failure-recovery.json
node tests/try-hook.mjs .github/hooks/failure-recovery.json postToolUseFailure fixtures/events/postToolUseFailure-missing-file.json --shell bash
node tests/try-hook.mjs .github/hooks/failure-recovery.json errorOccurred fixtures/events/errorOccurred.json --shell bash
node tests/try-hook.mjs .github/hooks/failure-recovery.json postToolUse fixtures/events/postToolUse-read.json --shell bash
node tests/try-hook.mjs .github/hooks/failure-recovery.json sessionStart fixtures/events/sessionStart-new.json --shell bash
```

**PowerShell**

```powershell
node tests/validate-configs.mjs .github/hooks/failure-recovery.json
node tests/try-hook.mjs .github/hooks/failure-recovery.json postToolUseFailure fixtures/events/postToolUseFailure-missing-file.json --shell powershell
node tests/try-hook.mjs .github/hooks/failure-recovery.json errorOccurred fixtures/events/errorOccurred.json --shell powershell
node tests/try-hook.mjs .github/hooks/failure-recovery.json postToolUse fixtures/events/postToolUse-read.json --shell powershell
node tests/try-hook.mjs .github/hooks/failure-recovery.json sessionStart fixtures/events/sessionStart-new.json --shell powershell
```

Repeat the same failure fixture until the configured limit, **before** the
success-reset call, to observe the guidance change to the stop-and-ask message.
Inspect the metadata counter under `HOOK_STATE_DIR` to see failure increments
and completion reset; do not capture raw error logs. `errorOccurred` emits
classification diagnostics without incrementing that counter.
The final start call is a **no-trigger control**: expect zero matches.
Fixture state belongs to its synthetic session.

## Live prompts and observations

| Prompt | Event | Expected outcome |
| --- | --- | --- |
| “Use view to read demo-app/src/no-such-file.js once. Do not retry. Then quote any recovery guidance you received.” | `postToolUseFailure` (`toolName: view`) | Failure counter increments; agent quotes `Category: file-not-found` guidance |
| “Run npm --prefix demo-app run missing-hook-demo once. Report why it failed; do not install packages or retry.” | Often `postToolUse`, not a failure event | Contrast command failure with tool failure; a completion may reset the counter |
| “Read demo-app/package.json and identify the correct test script.” | Successful `postToolUse` if used | Completion resets the session's failure count |
| “Run npm --prefix demo-app test once.” | Successful tool event | Tests provide an actual recovery result |

If configured, use the optional activity log to observe the failure events. A
failure hook cannot make an unavailable tool exist.
If the runtime emits only `postToolUse`, record that distinction and do not
claim the failure handler ran.

## Configuration-only stretch

Set `FAILURE_LIMIT` to `"2"`, exercise repeated **offline** failures, then restore
`"3"`. Explain the trade-off between early human review and excessive retries.

## Reuse / disable

Use guidance to encourage diagnosis, not automatic installation or permission
changes. Remove `failure-recovery.json` and restart to disable.

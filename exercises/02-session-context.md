# 02 · Session context

## Goal

Give an agent useful, fresh project context without depending on a remembered
prompt or copying project instructions into a script.

## Events

`sessionStart`; optionally `subagentStart`.

## Read the supplied script / environment options

Read `scripts/02-session-context/briefing.sh` or `briefing.ps1`.
It accepts `sessionStart` or `subagentStart`. `DEMO_DIR` defaults to `demo-app`.
It supplies known demo check commands and read-only Git status/recent commits as
`additionalContext`. It does not expose secrets or load arbitrary instructions.
Filenames and commit text are untrusted data, not commands or policy.

## Task: write `.github/hooks/session-context.json` yourself

1. Register a `sessionStart` command using the supplied helper and event argument.
2. Include both `bash` and `powershell`, a short `timeoutSec`, and
   `env: { "DEMO_DIR": "demo-app" }`.
3. Add a separate `subagentStart` entry if you want the same briefing for
   subagents. Pass that event name rather than reusing the start argument.

Predict the effect before comparing with
`solutions/02-session-context/session-context.json`.

## Offline fixture commands

**Bash**

```bash
node tests/validate-configs.mjs .github/hooks/session-context.json
node tests/try-hook.mjs .github/hooks/session-context.json sessionStart fixtures/events/sessionStart-new.json --shell bash
node tests/try-hook.mjs .github/hooks/session-context.json subagentStart fixtures/events/subagentStart.json --shell bash
node tests/try-hook.mjs .github/hooks/session-context.json postToolUse fixtures/events/postToolUse-read.json --shell bash
```

**PowerShell**

```powershell
node tests/validate-configs.mjs .github/hooks/session-context.json
node tests/try-hook.mjs .github/hooks/session-context.json sessionStart fixtures/events/sessionStart-new.json --shell powershell
node tests/try-hook.mjs .github/hooks/session-context.json subagentStart fixtures/events/subagentStart.json --shell powershell
node tests/try-hook.mjs .github/hooks/session-context.json postToolUse fixtures/events/postToolUse-read.json --shell powershell
```

Expect top-level `additionalContext` with relevant check commands and available
Git metadata. The commands should not change files. Outside a Git repository,
missing Git context is not evidence that the whole hook failed.
If you omitted the optional subagent entry, its call correctly reports zero
matches. The last call is a **no-trigger control**: `postToolUse` should report
`0 matching hook(s)` and no briefing.

## Live prompts and observations

| Action/prompt | Event | Expected outcome |
| --- | --- | --- |
| Start a fresh session, then ask “Which demo checks should we run before finishing?” | `sessionStart` | Activity log confirms delivery; context identifies demo checks |
| “Use an explore subagent to summarize the demo tests, if supported.” | `subagentStart` if emitted | Subagent briefing only if the runtime supports/emits the event |

An answer that happens to name the commands is not sufficient proof; compare
the activity log and hook diagnostics.

## Configuration-only stretch

Configure context for only subagents, then only session starts. Explain the
difference in scope without editing the helper.

## Reuse / disable

For another project, adapt the helper's known-project assumptions separately;
changing `DEMO_DIR` alone does not teach it arbitrary build systems.
Remove only `session-context.json` and restart to disable.

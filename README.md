# GitHub Copilot hooks: configuration-first exercises

Learn how hooks are created, called, and used by **writing hook configurations**,
not shell scripts. All Bash and PowerShell helpers are supplied and complete.
Your tasks are choosing events, commands, matchers, environment options, and
timeouts, then proving that your configuration does what you intended.

Work independently in a disposable checkout. Allow about **two hours** for the
core path, excluding installation. No hooks are enabled when you open this
repository: configurations in `solutions/` are reference answers, not startup
hooks.

## Learning path

| Exercise | Time | Configuration task |
| --- | ---: | --- |
| [00 · Setup and anatomy](exercises/00-setup.md) | 15 min | Understand the format and verify the demo baseline |
| [01 · Activity log](exercises/01-activity-log.md) | 15 min | Subscribe to lifecycle events and observe calls |
| [02 · Session context](exercises/02-session-context.md) | 10 min | Inject useful context at session/subagent start |
| [03 · Guardrails](exercises/03-guardrails.md) | 20 min | Match selected tools and configure narrow checks |
| [04 · Format and lint](exercises/04-format-lint.md) | 15 min | Run scoped feedback after edits |
| [05 · Quality gate](exercises/05-quality-gate.md) | 20 min | Check formatting, lint, and tests before finishing |
| [06 · Failure recovery](exercises/06-failure-recovery.md) | 15 min | Give the agent recovery guidance after failed tool calls |
| [07 · Session recovery](exercises/07-session-recovery.md) | 10 min | Save a small checkpoint and supply it on resume |

There are seven hook topics (01–07). Start at setup and keep the activity log
enabled throughout.
Each exercise includes offline fixture calls, suggested live prompts, expected
observations, a configuration-only stretch, and instructions to disable/reuse it.
Write each JSON file from blank before comparing with `solutions/NN-name/name.json`.
Validate your own file with `tests/validate-configs.mjs` and test it offline with
`tests/try-hook.mjs`; setup explains the commands. There are no script-writing
TODOs.

## What you need

- Git, Node.js 22+, npm, and either Bash with `jq` or PowerShell 7.
- GitHub Copilot CLI or VS Code's **Copilot** session target, in a trusted
  workspace where organization policy allows hooks.
- A disposable checkout; do not use production files or real secrets.

`demo-app/` is a small integer-cents cart/pricing project with Node tests,
ESLint, and Prettier. It makes hook feedback visible without building an app.
Install its dependencies during [setup](exercises/00-setup.md).

## Extras and reference

- [Personal hooks and portability](exercises/extras/personal-hooks.md)
- [Notifications](exercises/extras/notifications.md)
- [Agent-scoped hooks](exercises/extras/agent-scoped-hooks.md)
- [A limited secret-check experiment](exercises/extras/secret-guard.md)
- [Events cheat sheet](docs/events.md), [troubleshooting](docs/troubleshooting.md),
  [compatibility and verification](docs/compatibility.md), [sources](docs/sources.md)

Selected Bash/macOS effects have been observed in CLI 1.0.105; see the
[evidence matrix](docs/compatibility.md#recorded-live-observations).
**Offline script checks are not proof of live hook delivery.** Client versions,
policies, tool names, and argument shapes matter. Record what you actually
observe; an absent event is a diagnostic finding, not success. Hooks are not a
tamper-proof security boundary and do not replace permissions, CI, or review.

The learning material is original, with attribution in [sources](docs/sources.md).
No license is selected; confirm rights and choose one before redistribution.

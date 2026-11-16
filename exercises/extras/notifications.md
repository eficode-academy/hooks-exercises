# Extra · Completion cues and CLI notifications

## Goal / events

Configure a small terminal cue and distinguish `agentStop`, CLI `notification`,
and `sessionEnd`. A terminal bell is not guaranteed desktop delivery.

## Read the supplied helper / task

Read `scripts/08-notifications/notify.sh` / `notify.ps1`. It reads an event,
emits a bell on **stderr**, and returns `{}` on stdout. Terminal settings may
make the cue silent. It does not write a log or replace a quality gate.

Write `.github/hooks/notifications.json` from blank. Register `agentStop`,
command `type`, both platform commands, and a short timeout:
`bash scripts/08-notifications/notify.sh` and
`pwsh -NoProfile -File scripts/08-notifications/notify.ps1`.
No event argument or environment option is required.
Compare later with `solutions/08-notifications/notifications.json`.

## Offline fixture commands

```text
node tests/validate-configs.mjs .github/hooks/notifications.json
node tests/try-hook.mjs .github/hooks/notifications.json agentStop fixtures/events/agentStop.json --shell bash
node tests/try-hook.mjs .github/hooks/notifications.json sessionEnd fixtures/events/sessionEnd.json --shell bash
```

For PowerShell use the same commands with `--shell powershell`. Expect one
completion helper invocation, `{}`, and possibly an audible cue. The
`sessionEnd` control should report `0 matching hook(s)`.

## Live prompts and observations

| Prompt/action | Event / expected outcome |
| --- | --- |
| “Run the demo tests once, then summarize.” | `agentStop`; a cue if the terminal supports it, with activity metadata as delivery evidence |
| Disable the extra config and repeat | No cue from this helper |

When combined with a stop gate, a cue can occur on a stop attempt even if
another handler blocks finishing. It is not a “checks passed” signal.

## Configuration-only stretch / disable / reuse

In CLI only, experiment with a separate `notification` entry using
`matcher: "permission_prompt"` and the same helper. Use
`fixtures/events/notification.json` with the offline runner, inspecting its
notification type first. An actual permission notification is
client-dependent; a normal completed turn does not prove it happened.
Do not assume CLI notifications fire in VS Code.

Remove this extra JSON and start a fresh session to disable. Reuse a cue only
where terminal behavior and event delivery are verified.

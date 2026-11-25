# Events cheat sheet

Use exact native camelCase names. A handler receives an event JSON object on
stdin. Configuration selects **when** a helper runs; its argument tells the
shared helper **which mode** to use.

| Event | When to investigate | Core example / expected effect |
| --- | --- | --- |
| `sessionStart` | New or resumed session | House-rules briefing; resume note only for `source: "resume"` |
| `userPromptSubmitted` | A user submits input | Metadata only; do not store raw prompt text |
| `preToolUse` | Before an actual tool call | Deny or ask for risky files and commands |
| `postToolUse` | Tool completion | Run the project check, report failures to the agent |
| `postToolUseFailure` | Runtime-classified tool failure | Recovery hint as `additionalContext` |
| `errorOccurred` | Runtime error event | Observe without logging raw errors |
| `preCompact` | Before supported context compaction | Save a small note; output ignored |
| `subagentStart` | Runtime starts a subagent | Observer or limited briefing |
| `subagentStop` | Runtime finishes a subagent | Observer |
| `agentStop` | Agent is about to finish | Run the check, block the stop once if it fails |
| `sessionEnd` | Runtime ends session | Observer, not a finish-time quality gate |
| `notification` | CLI notification lifecycle | Optional CLI-only exploration |

Not every client emits every event. See [compatibility](compatibility.md) for
observations and how to verify.

## Inputs and outputs

Common payload fields include `sessionId`, `timestamp`, `cwd`; tool events add
`toolName` and `toolArgs`. Fields vary by event. Tool argument schemas are not
universal: open a file in `fixtures/events/` and check your client's real shapes.

- Context is a top-level `additionalContext` field on supported events.
- A tool denial uses `permissionDecision` and `permissionDecisionReason`.
- A finish-time block uses top-level `decision` and `reason`.
- `{}` is no decision, not a tool permission grant.
- `postToolUseFailure` recovery guidance also uses `additionalContext`
  (exit 0). CLI 1.0.105 delivered it to the model alongside the failure; the
  reference's alternative, plain stdout with exit 2, was **not** delivered in
  an earlier probe.
- `preCompact` persists its artifact; a separate resume event supplies context.

Do not use PascalCase aliases or copy nested/snake_case envelopes from another
harness into these native examples. Even where a client accepts an alias, its
payload and output fields can differ.

Hooks complement instructions and skills. Instructions describe standards, and
skills package reusable workflows. Hooks run deterministic commands at lifecycle
points. Prefer several narrowly matched hooks over one broad script.

## Matchers and budgets

`matcher: "edit|create|apply_patch"` narrows supported tool events by **tool
name**, not path or prompt. An offline helper call does not exercise a matcher.
Environment values configure the supplied helper. `timeoutSec` bounds the
runtime call; helper-specific timeouts bound individual checks. Neither is a
replacement for permissions, sandboxing, CI, or review.

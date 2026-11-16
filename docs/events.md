# Events cheat sheet

Use exact native camelCase names. A handler receives an event JSON object on
stdin. Configuration selects **when** a helper runs; its argument tells the
shared helper **which mode** to use.

| Event | When to investigate | Core example / expected effect |
| --- | --- | --- |
| `sessionStart` | New or resumed session | Briefing; checkpoint context only for `source: "resume"` |
| `userPromptSubmitted` | A user submits input | Metadata observer; do not store raw prompt text |
| `preToolUse` | Before an actual tool call | Narrow matched guardrail decision |
| `postToolUse` | Tool completion | Observer; scoped format/lint; success-reset mode |
| `postToolUseFailure` | Runtime-classified tool failure | Bounded recovery guidance as `additionalContext` |
| `errorOccurred` | Runtime error event | Observe/classify without logging raw errors |
| `preCompact` | Before supported context compaction | Save metadata checkpoint; output ignored |
| `subagentStart` | Runtime starts a subagent | Observer or limited briefing |
| `subagentStop` | Runtime finishes a subagent | Observer |
| `agentStop` | Agent is about to finish | Bounded quality check / stop decision |
| `sessionEnd` | Runtime ends session | Observer, not a finish-time quality gate |
| `notification` | CLI notification lifecycle | Optional CLI-only exploration |

Not every client emits every event. See [compatibility](compatibility.md) for
observations and a verification checklist.

## Inputs and outputs

Common payload fields include `sessionId`, `timestamp`, `cwd`; tool events add
`toolName` and `toolArgs`. Fields vary by event. Tool argument schemas are not
universal: inspect supplied fixtures and verify actual client shapes.

- Context is a top-level `additionalContext` field on supported events.
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

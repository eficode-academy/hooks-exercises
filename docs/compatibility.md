# Compatibility and what offline checks prove

The exercises keep one line about this; the detail lives here.

## Evidence levels

Keep these separate when you record a result:

1. **Documented contract:** the reference describes a field or event.
2. **Offline fixture-tested:** the supplied helper answers a synthetic event
   correctly (`scripts/try-hook`, `tests/run.sh`).
3. **Live delivery observed:** your client really called the handler.
4. **Live effect observed:** your client used the answer (context reached the
   model, a denial stopped the call).

A passing offline run proves levels 1-2 at most. It does not prove that your
client registered the file, matched the tool name, or honoured the response.
An absent event is a diagnostic finding, not a pass: a tool may not have run,
the client may not emit that event, the folder may be untrusted, or policy
may block hooks. Say "unverified" until you have seen it live.

## What was observed live

Controlled probes used **Copilot CLI 1.0.105, Bash, macOS**. The helpers were
longer in that version; this repository now ships simplified v2 helpers that
have been tested **offline** (bash and PowerShell 7) but not yet re-run live.
The event behaviour below belongs to the client, not to the helpers.

| Behaviour | Observed |
| --- | --- |
| Event delivery | `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `agentStop`, `sessionEnd`, `subagentStart`, `subagentStop` reached a logging hook |
| Start context | `additionalContext` from `sessionStart` was consumed by the model |
| File guard | A direct `edit` of a protected path was denied and the file stayed unchanged |
| Post-edit feedback | `additionalContext` after an `edit`/`create` reached the agent |
| Finish gate | An `agentStop` block forced a second turn; a still-failing retry with `stop_hook_active` ended after exactly two stops |
| Tool failure | A missing-file `view` fired `postToolUseFailure`; JSON `additionalContext` (exit 0) was quoted back by the agent, a plain-stdout/exit-2 variant was not delivered |
| Shell failure | A shell command exiting `7` was reported as `postToolUse`, **not** `postToolUseFailure` |
| Compaction | Manual `/compact` fired `preCompact` (`trigger: "manual"`); automatic compaction was not triggered |
| Resume | `copilot --resume <id>` fired `sessionStart` with `source: "resume"`, and the agent used working-tree facts from the note, not the conversation |
| VS Code, live PowerShell | Not tested |

Tool arguments seen: `edit` with `path`, `old_str`, `new_str`; `view` with
`path`; `bash` with `command`, `description`. These are examples, not a universal
schema; other tools and clients may differ.

## What the guardrails do not cover

The guards in exercise 03 are plain text matches on one tool call:

- `protect-files` reads `toolArgs.path` (or the patch text for `apply_patch`).
  It does not see shell writes (`echo > file`), other tools, or symlinks.
- `guard-commands` matches four patterns (`rm -rf`, `git push --force`/`-f`,
  `git reset --hard`, `curl ... | sh`). Quoting, aliases, extra spaces, other
  flags and PowerShell equivalents such as `Remove-Item -Recurse -Force` pass
  through. A quoted example in a string can also trigger it.
- Hook errors and timeouts are not a security guarantee, and an agent that can
  edit `.github/hooks/` can change the hooks.

Treat hooks as a seatbelt next to permissions, review and CI.

## Contracts these exercises use

Native camelCase event names and fields: `toolName`, `toolArgs`,
`additionalContext`, `permissionDecision`, `decision`. Do not substitute
PascalCase aliases or another harness's nested response envelopes, and keep
event-specific keys such as `stop_hook_active` as they are.

| Surface | Used for |
| --- | --- |
| Registration | `version: 1`, `hooks`, `type: "command"`, `bash`, `powershell`, `env`, `timeoutSec`, optional `matcher` |
| Context | Top-level `additionalContext` where the event consumes it |
| Tool decision | `permissionDecision` + `permissionDecisionReason` on `preToolUse` |
| Finish decision | `decision: "block"` + `reason` on `agentStop`, not `sessionEnd` |
| `preCompact` | Output is ignored; the helper saves a local note |
| `notification` | CLI-only; not assumed in VS Code |

`{}` means "no decision", not approval. See [sources](sources.md) for the
current reference; organization policy, trust and other hook sources (user,
agent, plugin) also affect behaviour.

## Checking your own work

Offline, from the repository root:

```text
bash scripts/try-hook.sh .github/hooks/NAME.json EVENT fixtures/events/FIXTURE.json
pwsh -File scripts/try-hook.ps1 .github/hooks/NAME.json EVENT fixtures/events/FIXTURE.json
```

`try-hook` runs the matching entries of **your** JSON with their `env` values
and matchers, and never the command stored in the fixture. Maintainers run
`bash tests/run.sh` and `pwsh -File tests/run.ps1`, which push every fixture
through the reference solutions.

In your own client, record version, OS, shell, date and policy, then:

1. Enable only the activity log and check that live lines appear.
2. Enable one topic at a time and look for its event in the log.
3. Verify the effect separately (a denial, a briefing, a block).
4. Remove the JSON and start a fresh session to prove it is off. User and plugin
   hooks can keep running after a repository file is removed.

Do not keep raw prompts, source code, secrets or full event payloads as debug logs.

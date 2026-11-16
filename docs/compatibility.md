# Compatibility and verification

## Evidence levels

Keep these separate when recording results:

1. **Documented contract:** reference describes a field/event.
2. **Offline fixture-tested:** supplied helpers respond to synthetic payloads.
3. **Live delivery observed:** a particular client actually calls a handler.
4. **Live effect observed:** that client consumes context/decisions as intended.

A passing fixture does not establish registration, matching, or live effects.
A live event record does not establish that the agent received its output.

## Recorded live observations

Controlled probes used **Copilot CLI 1.0.105, Bash, macOS**. The following
separates supplied-fixture behavior from observed client effects; it does not
certify other versions, shells, platforms, or tool adapters.

| Topic / behavior | Offline fixture coverage | Recorded live result |
| --- | --- | --- |
| Activity metadata | Synthetic event records | Supplied logger persisted `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `agentStop`, `sessionEnd`, `subagentStart`, and `subagentStop` |
| Session context | Briefing response | Supplied briefing's npm check command consumed; a separate unique-code context probe also established start-context consumption |
| File guard | Protected edit denial and controls | Configured `PROTECTED_PATHS` direct edit denied; protected file remained unchanged |
| Command guard | Synthetic dangerous/safe strings | Destructive commands deliberately not executed; no broader live security claim |
| Post-edit feedback | Scoped format/lint and controls | `create` of the exact messy example was formatted into two spaced, semicolon-terminated lines; agent received ESLint `no-unused-vars` context |
| Finish-time gate | Initial failure, retry, passing checks | Broken-cart **test-only** gate blocked the first stop and forced a second turn; still-failing retry surfaced a warning with exit 2 and finished after exactly two stops; last-check status was failed |
| Missing-file tool failure | Guidance, counter, completion reset | Missing-file `view` fired `postToolUseFailure` and updated the counter. JSON `additionalContext` (exit 0) guidance was quoted back by the agent; an earlier plain-stdout/exit-2 variant was **not** delivered |
| Shell command exiting `7` | Distinct completion/failure fixtures | Reported as `postToolUse`, **not** `postToolUseFailure` |
| Checkpoint creation | Supplied `preCompact` handler saved metadata after an offline lint failure | Interactive `/compact` fired `preCompact` with `trigger: "manual"` and the supplied handler wrote `checkpoint.json` (branch, changed files, diffstat); compaction completed |
| Resume context | New/resume fixture controls | `copilot --resume <id> -p` on the compacted session fired `sessionStart` with `source: "resume"`; agent reported the checkpoint's branch and changed files without tools. An earlier run also reported last-check `lint` / `failed` |
| VS Code / live PowerShell | Separate supplied script tracks | Live effects not tested |

Do not infer the full default format/lint/test gate sequence was
live-verified from the test-only gate probe. Resume evidence demonstrates
consumption of **working-tree metadata**, not transcript restoration.
Automatic compaction (`trigger: "auto"`) was not triggered.

Live-run notes: `-p` runs skipped repository hooks in an untrusted folder, and
`--continue` resumed the machine's most recent session rather than this
folder's (see [troubleshooting](troubleshooting.md)).

Bounded CLI 1.0.109 observations (Bash, macOS, disposable repository; not used
as exercises):

- With `-p`, repository hooks loaded in an untrusted folder when
  `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=true` was set. Without that setting
  or broad permission approval, they were skipped. A separate non-default
  `COPILOT_ALLOW_ALL=true` probe also loaded them, but approved all tools: it
  did not validate the normal folder-trust flow and is not recommended setup.
  The opt-in is not a tool-permission grant or a substitute for reviewing the
  folder and using the normal trust flow.
- A `userPromptSubmitted` hook's `additionalContext` reached the model in one
  run. The current reference says config-file `userPromptSubmitted` output is
  dropped, so treat this as undocumented, version-specific behavior. It is not
  an exercise contract.
- A `userPromptSubmitted` response of `{"response": ...}` was **not observed**
  to skip the model in one `-p` run; the model still answered.
- A `preToolUse` `modifiedArgs` rewrite of a synthetic `echo` command was
  applied: the tool ran the replacement command.
- HTTP hooks and `permissionRequest` were not tested.

Observed tool arguments included `edit` with `path`, `old_str`, `new_str`;
`view` with `path`; and `bash` with `command`, `description`. These examples do
not define a universal tool schema. Other tools/clients may use other names or
argument shapes.

## Contracts used by these exercises

The recipes target native camelCase event names and payload/output fields:
`sessionStart`, `toolName`, `toolArgs`, `additionalContext`, and so on.
Do not substitute PascalCase aliases or nested response envelopes from a
different agent harness. Do not mechanically rename payload keys: the supplied
stop retry fixture deliberately includes the event-specific `stop_hook_active`.

| Surface | Exercise use / limitation |
| --- | --- |
| JSON registration | `version: 1`, `hooks`, command `type`, `bash`, `powershell`, `env`, `timeoutSec`, optional `matcher` |
| Context responses | Top-level `additionalContext` where the event consumes context |
| Pre-tool decisions | Narrow tool/path adapters only; prove both matching and decision handling live |
| Finish-time decisions | `agentStop` block/reason with bounded retry handling; not a `sessionEnd` gate |
| Failure response | `postToolUseFailure` helper returns top-level `additionalContext` (exit 0), delivered in CLI 1.0.105. The documented plain-stdout/exit-2 alternative was not delivered |
| Other recovery modes | No-decision JSON (`{}`); they are not automatic retry commands |
| `preCompact` | Output is ignored; the checkpoint helper saves a local artifact |
| Resume context | Separate `sessionStart` call with `source: "resume"`; not automatic restoration during compaction |
| `notification` | CLI-only optional exploration; not assumed for VS Code |

See the authoritative [references](sources.md) for your current version.
Organization policy, trust, permissions, execution host, and other hook sources
can all affect behavior. Hook errors/timeouts are not a security guarantee.

## Offline validation

From the repository root, after installing demo dependencies:

```text
node tests/validate-configs.mjs .github/hooks/activity-log.json
node tests/try-hook.mjs .github/hooks/activity-log.json sessionStart fixtures/events/sessionStart-new.json --shell bash
node tests/run.mjs --shell bash
node tests/run.mjs --shell powershell
node tests/doc-commands.mjs --shell bash
node tests/doc-commands.mjs --shell powershell
```

Run the shell suite for your installed track; running both is optional.
The first command validates **your active JSON** and resolves commands to
supplied script paths. `try-hook` executes matching entries from your JSON with
its environment options; it resolves fixture `cwd` and never runs the Copilot
tool described by that fixture. Neither invokes a live client.
`tests/run.mjs` is the separate supplied-script fixture regression suite.
`tests/doc-commands.mjs` runs the numbered exercises' shell blocks verbatim in
disposable copies with sample active configurations. It also checks that an
existing quality-gate backup is preserved and a failed restore retains its
backup. This is documentation regression coverage, not evidence that your own
JSON or live client works.

The demo baseline (`npm --prefix demo-app run check`) has been observed passing
with six Node tests, ESLint 9, and Prettier 3 after dependency installation.
Re-run it locally; later exercises intentionally introduce failures temporarily.

## Verify in your own client

Record client/version, OS, shell, host, date, and policy/trust prerequisites.
In VS Code select the **Copilot** target; other harnesses have other contracts.

1. Enable only the activity observer, validate its JSON, and start a fresh
   session. Distinguish synthetic session records from live ones.
2. Request a harmless read and identify actual tool names from metadata.
3. Enable context and check both start delivery and output consumption.
4. Try the harmless protected-file prompt, plus an ordinary read/control.
   Confirm the actual tool payload fits the supplied adapter.
5. Test post-edit formatting on a disposable file and check the resulting diff.
6. Safely back up the demo before a quality-gate failure. Verify initial
   blocking, repeated-check bounded behavior, and final restoration.
7. Test tool failure with a missing-file **view**. A failed shell command need
   not emit `postToolUseFailure`.
8. Test manual compaction and explicit session resume separately if available.
9. Remove each exercise's JSON and start a fresh session to prove disabling.

Label absent or ambiguous effects **unverified**, not successful. User/plugin
hooks can continue running after a repository config is removed. Do not retain
raw prompts, source, secrets, or full event payloads as debugging logs.

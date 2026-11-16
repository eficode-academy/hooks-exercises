# Troubleshooting

## Start with three different checks

1. **Configuration:** `node tests/validate-configs.mjs .github/hooks/activity-log.json`
   (substitute your file). Fix JSON syntax, event spelling, and unresolved script
   paths before live tests. The validator does not prove runtime support.
2. **Offline registration and helper:** run the exercise's
   `node tests/try-hook.mjs CONFIG EVENT FIXTURE --shell bash` command
   (`--shell powershell` for that track). It honors your config env and matcher,
   resolves fixture `cwd`, and never executes the tool described in the fixture.
   Then use
   `node tests/run.mjs --shell bash` or `--shell powershell` for supplied-script
   regressions. Offline success does not prove live delivery.
3. **Runtime:** enable the activity observer and start a fresh session. Look for
   the expected event and separately verify its artifact/decision/context.

## No activity record

- Is the reviewed JSON under `.github/hooks/`, not just `solutions/`?
- Did you start from the repository root and start a fresh session?
- Is the workspace trusted, with hooks allowed by policy?
- In VS Code, is the session target **Copilot**?
- Is the configured interpreter installed on the actual execution host?
  On Unix, `bash` is the configuration command selected even if your terminal
  happens to be PowerShell; adjust it to invoke `pwsh` for that experiment.
- Does the helper have a writable log/state directory? Did the viewer use the
  same `HOOK_LOG_DIR`?
- Did a tool actually run? A prompt is not a guarantee of tool use.
- Does this client emit the event? See [recorded evidence](compatibility.md).

Do not bypass organization controls to make a demonstration work.

## Helper works, active configuration does not

Direct helper calls skip registration and matchers; use `tests/try-hook.mjs`
instead. Check exact event
capitalization, event argument, platform command, string-valued `env`, timeout,
and tool-name matcher. Run the active-JSON validator again.
Paths are relative to the execution working directory. Run from the repository
root. Some helpers require absolute `cwd`: the runner resolves fixture `"."`
before invocation; do not pipe a relative-cwd fixture directly to those helpers.

## No failure-hook guidance after a failed command

A shell process's nonzero exit is not necessarily a tool failure. CLI 1.0.105
reported an exit-7 shell command as `postToolUse`; a missing-file `view` produced
`postToolUseFailure`. Use the exercise's harmless missing-view prompt and look
at actual event records.

The failure helper returns `{"additionalContext": "..."}` with exit 0 for
`postToolUseFailure`. In CLI 1.0.105 that guidance reached the model; plain
stdout with exit 2 did not. Other recovery modes return `{}`. Guidance is
advice: it does not mean a retry happened.

## Hooks are silently skipped in `copilot -p`

CLI 1.0.105 and 1.0.109 print `Skipped repository hooks (.github/hooks) because
the folder ... is not trusted` when a non-interactive run starts in an
untrusted folder. Review the folder and hooks first, then use the client's
normal trust flow. Answering "Yes" once in an interactive session does not
persist; choose "Yes, and remember this folder" if you intend to trust it for
future runs.

CLI 1.0.109 also loaded repository hooks in one `-p` probe with
`GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=true`. This version-specific opt-in is
not a tool-permission grant or a substitute for reviewing and trusting the
folder. Follow your client's current guidance and organization policy.

## `copilot --continue` resumes the wrong session

`--continue` resumes the most recent session on the machine, which may belong
to another folder or still be running. Copy the ID from the `Resume` line the
CLI prints on exit and use `copilot --resume <id>` instead.

## A guard does not deny an edit

Check the actual tool name and supported argument shape. A different tool,
unrecognized patch format, or shell write may bypass a narrow adapter. Matchers
are tool-name patterns, not filename patterns. Use harmless fixtures only; do
not test by requesting destructive commands. No security claim follows from a
passing synthetic denial.

## Formatting or lint feedback is missing

Run `npm --prefix demo-app ci` if dependencies are not installed. The helper uses
local tools, not an on-demand download. Check `DEMO_DIR`, supported `src/` /
`test/` paths, tool payload shape, and `FORMAT_ON_EDIT` / `LINT_ON_EDIT`.
A clean file may need no repair. A post-tool hook cannot undo the edit.

## Quality gate fails or keeps giving feedback

Run `npm --prefix demo-app run check` directly to identify the real baseline.
`CHECK_STEPS` uses semicolons and names npm scripts. Give the outer
`timeoutSec` room for the bounded sequence. A retry that still fails produces
a warning and yields; that is **not** a passing check.
Only `format:check`, `lint`, and `test` are supported by this helper; adapting
the recipe to other commands requires reviewing its allowlist, not just
renaming a config value.
Restore the exercise backup before finishing. Do not reset unrelated changes.
If `agentStop` delivery or block consumption is absent, mark it unverified and
keep CI checks; `sessionEnd` is not a replacement finish-time gate.

## Checkpoint exists but context is absent

`preCompact` saves metadata; its output is ignored. Resume injection is a
separate `sessionStart` event with `source: "resume"` and an existing checkpoint.
New-session starts intentionally do not inject it. Check `HOOK_STATE_DIR`
consistency and the client's actual resume behavior. No helper restores a full
conversation or automatically injects context immediately after compaction.
CLI 1.0.105 did consume an **offline-created** checkpoint during real explicit
resume; that evidence does not establish interactive `preCompact` delivery.

## Output errors, timeouts, or repeated calls

Keep protocol stdout clean (except the documented failure-context mode).
Put diagnostics on stderr. Do not mix native top-level output fields with another
harness's output envelopes. If hooks repeat, inspect repository, user, agent,
and plugin registrations for duplicates; do not assume array order is a
cross-hook dependency guarantee.

Disable only your exercise JSON, restart, and repeat a harmless control. Keep
local metadata private and apply a sensible retention policy.

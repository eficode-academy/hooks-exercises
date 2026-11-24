# Troubleshooting

## Three different checks

1. **Configuration:** run your file through `scripts/try-hook` for the event you
   expect. If it says the JSON is invalid, fix the syntax; if it says
   `0 matching hook(s)`, check the event name and `matcher`.
2. **Helper:** the `try-hook` output shows what the script returned. A hook that
   returns `{}` is working; it just has no opinion.
3. **Runtime:** enable the activity log ([exercise 01](../exercises/01-activity-log.md))
   and start a fresh session. Look for the event, then verify the effect separately.
   Offline success does not prove live delivery ([why](compatibility.md)).

## No activity record

- Is the reviewed JSON under `.github/hooks/`, not just `solutions/`?
- Did you start from the repository root and start a **fresh** session?
- Is the workspace trusted, and are hooks allowed by your organization's policy?
- In VS Code, is the session target **Copilot**?
- Is `jq` (Bash) or `pwsh` (PowerShell 7) installed where the hook runs?
  `bash scripts/preflight.sh` checks. On Unix the `bash` command is used even
  if your terminal is PowerShell.
- Is the log folder writable? Did the viewer use the same `HOOK_LOG_DIR`?
- Did a tool actually run? A prompt is not a guarantee of tool use.
- Does this client emit the event? See [compatibility](compatibility.md).

Do not bypass organization controls to make a demonstration work.

## Helper works, active configuration does not

Calling a script directly skips registration and matchers; use `scripts/try-hook`.
Check exact event capitalization, the event argument, both platform commands,
string-valued `env`, and the tool-name `matcher`. Paths are relative to the
working directory: start from the repository root.

## A guard does not deny an edit

Check the actual tool name and argument shape in the activity log. A different
tool, an unrecognized patch format, or a shell write bypasses a narrow check.
Matchers are tool-name patterns, not filename patterns. Do not test with
destructive prompts.

## The check hook says nothing, or always fails

Run `bash demo-app/check.sh` (or `pwsh -File demo-app/check.ps1`) directly: that
is the real baseline. If you set `CHECK_COMMAND`, run that command by hand too.
The outer `timeoutSec` must be longer than the check takes.

## No recovery hint after a failed command

A shell process's non-zero exit is not necessarily a tool failure; CLI 1.0.105
reported an exit-7 command as `postToolUse`. A missing-file `view` produced
`postToolUseFailure`. Use the exercise's harmless missing-file prompt.

## Hooks are silently skipped in `copilot -p`

Non-interactive runs skip repository hooks in an untrusted folder (the CLI
prints `Skipped repository hooks (.github/hooks) because the folder ... is not
trusted`). Review the folder, then use the client's normal trust flow and choose
"Yes, and remember this folder" if you intend to trust it. Version-specific
opt-ins exist but are not a substitute for trust and policy.

## `copilot --continue` resumes the wrong session

`--continue` resumes the machine's most recent session, which may belong to
another folder. Use `copilot --resume <id>` with the id printed on exit.

## Checkpoint exists but no context after resume

`preCompact` only writes the note. The context comes from a separate
`sessionStart` call with `source: "resume"`. A new session intentionally gets
none. Check that `HOOK_STATE_DIR` is the same for both events.

## Output errors, timeouts, or repeated calls

Keep stdout clean JSON; put diagnostics on stderr. If hooks repeat, look for
duplicates in repository, user, agent and plugin registrations.
Disable only your exercise JSON, start a fresh session, and repeat a harmless control.

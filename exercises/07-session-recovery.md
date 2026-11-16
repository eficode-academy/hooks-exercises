# 07 · Small checkpoints and session recovery

## Goal

Save just enough project state to orient a resumed session without saving a
transcript, source code, or promising complete session restoration.

## Events

`preCompact` for a checkpoint; `sessionStart` for resume-time context.

## Read the supplied script / environment options

`scripts/07-session-recovery/checkpoint.sh` / `checkpoint.ps1` accepts
`preCompact` or `sessionStart`. `HOOK_STATE_DIR` defaults to `.hooks-state`.
The snapshot contains branch, status, diffstat, and the last failed check when
available. It saves **no diffs or source contents**.
The start handler injects checkpoint context only when the payload's `source`
is `resume`; a new session is not treated as a restored one.

Status filenames are untrusted data. A checkpoint is a stale observation, not
new instructions or proof that checks still fail/pass.
Verified live with Bash on macOS and CLI 1.0.105: an interactive `/compact`
fired `preCompact` (`trigger: "manual"`), which saved the checkpoint. A later
`copilot --resume <id> -p` fired `sessionStart` with `source: "resume"`, and the
agent reported the saved branch and changed files without using tools. This is
working-tree metadata recovery, not transcript restoration.

## Task: write `.github/hooks/session-recovery.json` yourself

1. Register both events with their matching helper arguments.
2. Include both platform commands, a short timeout, and `HOOK_STATE_DIR`.
3. Use the same state directory as the quality gate if you want its last failed
   check available. Explain why two different directories lose that connection.

Compare with `solutions/07-session-recovery/session-recovery.json`.

## Offline fixture commands

**Bash**

```bash
node tests/validate-configs.mjs .github/hooks/session-recovery.json
node tests/try-hook.mjs .github/hooks/session-recovery.json preCompact fixtures/events/preCompact.json --shell bash
node tests/try-hook.mjs .github/hooks/session-recovery.json sessionStart fixtures/events/sessionStart-new.json --shell bash
node tests/try-hook.mjs .github/hooks/session-recovery.json sessionStart fixtures/events/sessionStart-resume.json --shell bash
```

**PowerShell**

```powershell
node tests/validate-configs.mjs .github/hooks/session-recovery.json
node tests/try-hook.mjs .github/hooks/session-recovery.json preCompact fixtures/events/preCompact.json --shell powershell
node tests/try-hook.mjs .github/hooks/session-recovery.json sessionStart fixtures/events/sessionStart-new.json --shell powershell
node tests/try-hook.mjs .github/hooks/session-recovery.json sessionStart fixtures/events/sessionStart-resume.json --shell powershell
```

Expect checkpoint creation (`preCompact` output is ignored), no checkpoint
injection on a new start (**negative control**), and
`additionalContext` on a resume when a checkpoint is available. Inspect state to
confirm that it contains metadata rather than a patch or conversation.

## Live prompts and observations

| Action/prompt | Event | Expected outcome |
| --- | --- | --- |
| “Read the demo tests and summarize the current pricing behavior.” | Tool events if used | Establish harmless session activity |
| Type `/compact` in the interactive CLI | `preCompact` with `trigger: "manual"` | `.hooks-state/checkpoint.json` is written; the CLI reports compaction completed |
| `/exit`, then `copilot --resume <id>` using the ID printed on exit | `sessionStart` with `source: "resume"` | Checkpoint is offered as context |
| “Without using tools, what branch and changed files were we working on?” | none beyond the prompt/stop events | Agent answers from the checkpoint |
| Start an unrelated new session | `sessionStart` with new-session source | No resume checkpoint injection |

`/compact` needs some conversation first: in a brand-new session it reports
"Nothing to compact", though `preCompact` still fired in our run. Prefer
`--resume <id>` over `--continue`, which picks the most recent session on the
machine, not necessarily this folder's. Review the folder and use the normal
client trust flow before testing `-p`; see the version-specific notes in
[troubleshooting](../docs/troubleshooting.md). VS Code's
session lifecycle can differ. The activity log must show the relevant calls;
session history restoration itself is the client's responsibility.

## Configuration-only stretch

Put all stateful exercises in a different local `HOOK_STATE_DIR` and keep
`HOOK_LOG_DIR` aligned if desired. Explain the difference between state that is
shared intentionally and unrelated fixture/live session state.

## Reuse / disable

Choose retention for local snapshots; filenames and branch names may still be
sensitive metadata. Remove `session-recovery.json` and restart to disable.
Review which configurations you want to keep, then disable the others.

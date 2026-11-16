# Extra · Personal hooks and portability

## Goal / events

Reuse a reviewed configuration outside this checkout. Start with `sessionStart`
context or metadata observation, not a guard or automatic edit.

## Read / task

Read your client's current user-level hook-location documentation in
[sources](../../docs/sources.md); this exercise does not assume a universal
personal configuration directory. Review trust and organization policy.

Write a configuration from blank for that supported location. Use **absolute,
properly quoted script paths** because another repository's working directory
will not contain this repository's `scripts/` folder. Keep the helper folder
and its shared dependencies together. An absolute helper path alone does not
make project-relative options portable: set `DEMO_DIR` to the intended absolute
demo directory and choose absolute `HOOK_LOG_DIR` / `HOOK_STATE_DIR` when needed.
Do not accidentally run demo checks against an unrelated project.

## Offline / live check

Test a reviewed scratch JSON containing the absolute helper command with
`node tests/validate-configs.mjs PATH-TO-YOUR-JSON`, then
`node tests/try-hook.mjs PATH-TO-YOUR-JSON sessionStart fixtures/events/sessionStart-new.json --shell bash`
from this checkout (`--shell powershell` for that track). The runner resolves
the fixture's relative `cwd`; do not pipe it directly to a helper that requires
an absolute live-payload `cwd`. This check does not install personal hooks.

| Prompt/action | Event / expected artifact |
| --- | --- |
| Start a disposable session and ask which demo checks are available | Configured `sessionStart`; metadata and context if supported |
| Start an unrelated project with this personal configuration disabled | No personal helper record or context |

Use the activity observer to identify duplicates: repository and personal hooks
can coexist. Keep personal paths private; do not commit them to shared JSON.

## Configuration-only stretch / disable / reuse

Separate a personal metadata log from the repository log without script edits.
Remove only your personal registration and start a fresh session to disable.
For wider reuse, choose genuinely project-appropriate helpers; `DEMO_DIR` is not
a discovery system for arbitrary project tooling.

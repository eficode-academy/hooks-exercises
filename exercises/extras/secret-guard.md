# Extra · A limited secret-check experiment

## Goal / events

Reason about a narrow pre-tool guard without introducing real secrets or
claiming comprehensive secret protection.

## Read / task

Reuse `scripts/03-guardrails/protect-files.sh` / `protect-files.ps1`, not a new
script. Create a separate `preToolUse` configuration with the file-tool matcher
and set `PROTECTED_PATHS` to a **harmless exercise-only path** that you create,
such as `demo-app/config/secret-demo.json`. Put only a dummy marker there.

This checks paths, not secret contents. It does not inspect arbitrary commands,
network requests, logs, already-read context, or every tool payload. Do not use
real `.env` files, access tokens, credentials, or live secret stores.

## Offline / live check

Adapt a synthetic protected-file payload to name your harmless path; pipe it
to the supplied guard using exercise 03's command pattern.

| Prompt | Event / expected decision |
| --- | --- |
| “Using a direct file edit, change the dummy marker in demo-app/config/secret-demo.json. Stop if denied.” | Matching `preToolUse`; denial only for supported tools/shapes |
| “Read demo-app/.env.example without editing it.” | Read remains outside the edit matcher; no secret-protection claim |

Use the activity log to confirm matching and preserve the harmless file if the
guard did not run. Do not ask for bypasses or destructive operations.

## Configuration-only stretch / disable / reuse

Add a second harmless path via the semicolon-separated environment option.
Remove this extra JSON and restart to disable; remove only your dummy file
after preserving unrelated changes. For real secret protection use appropriate
permissions, approved secret scanning, and review — this exercise is a limited
accidental-edit guard, not data-loss prevention.

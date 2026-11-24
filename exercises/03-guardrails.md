# 03 · Narrow tool guardrails

## Goal

Configure two pre-tool checks and learn why tool matchers and payload shapes
matter. This is a configuration experiment, **not a security boundary**.

## Events

`preToolUse`, with separate file-tool and shell-tool matchers.

## Read the supplied scripts / environment options

- `scripts/03-guardrails/protect-files.sh` / `protect-files.ps1` accepts
  `preToolUse`. `PROTECTED_PATHS` is a semicolon-separated list, defaulting to
  `demo-app/config/production.json`.
- `scripts/03-guardrails/guard-commands.sh` / `guard-commands.ps1` also accepts
  `preToolUse`, inspecting `toolArgs.command` for the supplied narrow rules.

The file adapter expects the fixture's supported path fields; it cannot protect
every possible tool format. The command adapter is string-based, not a shell
parser. Alternate tools, shell writes, symlinks, and hook changes can bypass
these checks. No real secrets or production resources belong in this exercise.
The supplied path guard denied a direct edit and preserved the file in the
recorded Bash/macOS CLI 1.0.105 probe; this does not prove other adapters or
clients are covered.

## Task: write `.github/hooks/guardrails.json` yourself

1. Create a `preToolUse` array with two command entries.
2. Route the file helper using `matcher: "edit|create|apply_patch"`.
3. Route the command helper using `matcher: "bash|powershell"`.
4. Provide both shell commands, explicit short timeouts, and
   `env.PROTECTED_PATHS` on the file entry.
5. Explain why combining both helpers behind the same matcher is incorrect.

Use the supplied script paths and pass `preToolUse` as the event argument.
Compare with `solutions/03-guardrails/guardrails.json` after writing your own.
Matchers apply to actual runtime tool names, not natural-language prompt text.

## Offline fixture commands

**Bash**

```bash
node tests/validate-configs.mjs .github/hooks/guardrails.json
node tests/try-hook.mjs .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-edit-protected.json --shell bash
node tests/try-hook.mjs .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-read.json --shell bash
node tests/try-hook.mjs .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-dangerous-command.json --shell bash
node tests/try-hook.mjs .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-safe-command.json --shell bash
```

**PowerShell**

```powershell
node tests/validate-configs.mjs .github/hooks/guardrails.json
node tests/try-hook.mjs .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-edit-protected.json --shell powershell
node tests/try-hook.mjs .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-read.json --shell powershell
node tests/try-hook.mjs .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-dangerous-command.json --shell powershell
node tests/try-hook.mjs .github/hooks/guardrails.json preToolUse fixtures/events/preToolUse-safe-command.json --shell powershell
```

Expect denial for the protected path, **zero matches for the read control**,
denial for the synthetic dangerous-command fixture, and no denial for the safe
command. The runner executes configured helpers, **never** the command stored
in a fixture. Dangerous strings are synthetic data only: never copy them to a
shell or ask an agent to perform a destructive action.

## Live prompts and observations

| Prompt | Event | Expected outcome |
| --- | --- | --- |
| “Using a direct file edit, add a harmless exercise marker to demo-app/config/production.json. If denied, stop; don't use another tool.” | `preToolUse` if a matching edit tool is selected | Denial only if the actual tool/payload matches the adapter; preserve the file |
| “Read demo-app/config/production.json without modifying it.” | Read-tool pre/post if used | Read is not denied by a file-edit matcher |
| “Run echo hook-demo.” | Shell `preToolUse` if used | Harmless command remains allowed by the hook; normal permissions still apply |

If you configured the optional activity log, inspect it for actual tool names;
otherwise use available runtime diagnostics. If names/shapes differ, record
the check as unverified, disable the guard, and investigate safely. Do not
silently assume a denied edit prevents shell-based writes.

## Configuration-only stretch

Add another harmless practice path to `PROTECTED_PATHS` using `;`. Narrow a
matcher to one observed tool and explain what the hook no longer covers.

## Reuse / disable

Treat this as a small accidental-edit guard, alongside permissions and review.
Remove `guardrails.json` and restart to disable. Never use live destructive
prompts as a way to test it.

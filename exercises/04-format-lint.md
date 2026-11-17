# 04 · Format and lint after edits

## Goal

Configure useful post-edit automation and distinguish repair from feedback.

## Events

`postToolUse`, restricted to file-edit tools.

## Read the supplied script / environment options

`scripts/04-format-lint/after-edit.sh` / `after-edit.ps1` accepts `postToolUse`.
It uses the **installed demo-local** Prettier and ESLint, scoped to supported
JavaScript/JSON edits under demo `src/` and `test/`.

| Environment option | Default / purpose |
| --- | --- |
| `DEMO_DIR` | `demo-app` |
| `FORMAT_ON_EDIT` | `true`: apply formatting |
| `LINT_ON_EDIT` | `true`: report remaining lint issues |
| `CHECK_TIMEOUT_SEC` | `10`: bound helper checks |

Remaining issues are returned as top-level `additionalContext`. A post-tool hook
cannot undo an already completed edit, and is not a finish-time quality gate.
Unsupported paths/tool payloads may produce no action.
In the recorded Bash/macOS CLI 1.0.105 probe, a supported `create` call was
formatted and the agent received remaining ESLint `no-unused-vars` context.
Other tool shapes and clients still need their own checks.

## Task: write `.github/hooks/format-lint.json` yourself

1. Add a `postToolUse` handler with `matcher: "edit|create|apply_patch"`.
2. Configure both helper commands; this single-event helper needs no event argument.
3. Set the four options above as strings. Give `timeoutSec` enough room for
   helper work without an unbounded wait.
4. Predict what happens with formatting off but linting on.

Compare later with `solutions/04-format-lint/format-lint.json`.

## Offline fixture commands

Validate your active JSON first. The runner honors its options and matcher:

**Bash**

```bash
node tests/validate-configs.mjs .github/hooks/format-lint.json
node tests/try-hook.mjs .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-read.json --shell bash
```

**PowerShell**

```powershell
node tests/validate-configs.mjs .github/hooks/format-lint.json
node tests/try-hook.mjs .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-read.json --shell powershell
```

The read fixture is the **no-trigger control**: expect `0 matching hook(s)`.
For deterministic positive cases, use the supplied messy and unused-variable
examples in a **new** sample path. Do not overwrite an existing sample.

**Bash**

```bash
if test -e demo-app/src/hook-example.js || test -L demo-app/src/hook-example.js; then
  echo 'Sample path already exists; preserve it and skip this experiment.'
else
  cp fixtures/edit-examples/messy.js demo-app/src/hook-example.js &&
    node tests/try-hook.mjs .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-edit-example.json --shell bash
  # Inspect hook-example.js: formatting should now differ from the messy fixture.
  cp fixtures/edit-examples/unused.js demo-app/src/hook-example.js &&
    node tests/try-hook.mjs .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-edit-example.json --shell bash
  # Expect additionalContext describing the remaining lint issue, not its repair.
  rm demo-app/src/hook-example.js
  npm --prefix demo-app run check
fi
```

**PowerShell**

```powershell
if (Test-Path demo-app/src/hook-example.js) { throw 'Sample exists; preserve it.' }
try {
    Copy-Item fixtures/edit-examples/messy.js demo-app/src/hook-example.js -ErrorAction Stop
    node tests/try-hook.mjs .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-edit-example.json --shell powershell
    Get-Content demo-app/src/hook-example.js
    Copy-Item fixtures/edit-examples/unused.js demo-app/src/hook-example.js -ErrorAction Stop
    node tests/try-hook.mjs .github/hooks/format-lint.json postToolUse fixtures/events/postToolUse-edit-example.json --shell powershell
} finally {
    if (Test-Path demo-app/src/hook-example.js) { Remove-Item demo-app/src/hook-example.js }
}
npm --prefix demo-app run check
```

Inspect the formatted sample and remaining-lint `additionalContext` separately.
Clean up the new sample before returning to the passing baseline. If you
interrupt the experiment, remove only the sample you created, not existing work.

## Live prompts and observations

| Prompt | Event | Expected outcome |
| --- | --- | --- |
| “Add a test for calculateTotal with nonzero shipping, using a direct file edit. Do not run formatting yet.” | Matching `postToolUse` if used | Supported changed test is formatted; remaining lint issues become feedback |
| “Add a well-named test for a percentage discount, then run the demo checks.” | Edit post-tool, then shell events | Tests/lint/format can verify the rule; the optional activity log can distinguish edit feedback from shell checks |
| “Read demo-app/src/cart.js without editing it.” | Read-tool post event if used | Edit-only matcher does not run the formatter |

Copilot may already produce formatted code, so no diff is not failure. If its
tool payload is unsupported, the fixture result does not prove live formatting.
Keep useful test additions; restore only deliberately broken exercise changes.

## Configuration-only stretch

Set `FORMAT_ON_EDIT` to `"false"` and keep `LINT_ON_EDIT` `"true"`. Compare the
feedback-only experience, then restore your preferred settings. Do not edit the
helper to change these options.

## Reuse / disable

Keep format-on-edit only where automatic changes are appropriate. Broader
repository checks belong in the quality-gate topic and CI. Remove
`format-lint.json` and restart to disable.

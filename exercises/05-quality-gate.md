# 05 · Finish-time quality gate

## Goal

Make formatting, linting, and tests an explicit finish-time check, with bounded
continuation rather than an endless correction loop.

## Events

`agentStop` — **not** `sessionEnd`. A finish-time gate must respond before a turn
finishes; closing a session is a different lifecycle event.

## Read the supplied script / environment options

`scripts/05-quality-gate/gate.sh` / `gate.ps1` accepts `agentStop`.

| Option | Default |
| --- | --- |
| `CHECK_STEPS` | `format:check;lint;test` (semicolon-separated npm scripts) |
| `CHECK_TIMEOUT_SEC` | `10` |
| `DEMO_DIR` | `demo-app` |
| `HOOK_STATE_DIR` | `.hooks-state` |

The first failed check returns a top-level `decision: "block"` and `reason`.
The retry fixture marks the stop hook active: the helper re-runs checks and, if
they still fail, yields with a warning instead of repeatedly blocking.
This bounded behavior is not a passing result and cannot guarantee repair.
The supplied **test-only** gate was live-observed in Bash/macOS CLI 1.0.105:
first-stop blocking forced a second turn, and a still-failing retry warned and
ended after exactly two stops. This is not a live verification of every
configured check sequence or platform.

## Task: write `.github/hooks/quality-gate.json` yourself

1. Register one `agentStop` command entry with both shell commands. This
   single-event helper needs no event argument.
2. Set all four environment options explicitly as strings.
3. Choose `timeoutSec` to accommodate the configured check sequence (for example
   40 seconds for three checks bounded at 10 seconds each plus overhead).
4. Explain why the formatter step is `format:check`, not `format`.

Compare with `solutions/05-quality-gate/quality-gate.json` after trying.
Keep activity logging enabled so you can see stop and continuation calls.

## Offline fixture commands

**Passing baseline — Bash**

```bash
node tests/validate-configs.mjs .github/hooks/quality-gate.json
node tests/try-hook.mjs .github/hooks/quality-gate.json agentStop fixtures/events/agentStop.json --shell bash
node tests/try-hook.mjs .github/hooks/quality-gate.json sessionEnd fixtures/events/sessionEnd.json --shell bash
```

**Passing baseline — PowerShell**

```powershell
node tests/validate-configs.mjs .github/hooks/quality-gate.json
node tests/try-hook.mjs .github/hooks/quality-gate.json agentStop fixtures/events/agentStop.json --shell powershell
node tests/try-hook.mjs .github/hooks/quality-gate.json sessionEnd fixtures/events/sessionEnd.json --shell powershell
```

The passing stop should not block. The `sessionEnd` call is a **no-trigger
control**: expect `0 matching hook(s)` and no quality checks.

For an intentional failing check, first verify that
`demo-app/src/cart.js.exercise-backup` does not already exist. Preserve your own
work. Copy the file to that backup, replace it with the supplied broken fixture,
run both stop fixtures, then restore **even if a command fails**.

**Bash**

```bash
if test -e demo-app/src/cart.js.exercise-backup || test -L demo-app/src/cart.js.exercise-backup; then
  echo 'Backup exists; preserve it and skip this experiment.'
elif cp demo-app/src/cart.js demo-app/src/cart.js.exercise-backup; then
  if cp fixtures/broken-code/cart.js demo-app/src/cart.js; then
    node tests/try-hook.mjs .github/hooks/quality-gate.json agentStop fixtures/events/agentStop.json --shell bash
    node tests/try-hook.mjs .github/hooks/quality-gate.json agentStop fixtures/events/agentStop-retry.json --shell bash
  fi
  if cp demo-app/src/cart.js.exercise-backup demo-app/src/cart.js; then
    rm demo-app/src/cart.js.exercise-backup
    npm --prefix demo-app run check
  else
    echo 'Restore failed. Backup retained; restore it before continuing.'
  fi
fi
```

**PowerShell**

```powershell
if (Test-Path demo-app/src/cart.js.exercise-backup) { throw 'Backup already exists; preserve it.' }
Copy-Item demo-app/src/cart.js demo-app/src/cart.js.exercise-backup -ErrorAction Stop
try {
    Copy-Item fixtures/broken-code/cart.js demo-app/src/cart.js -ErrorAction Stop
    node tests/try-hook.mjs .github/hooks/quality-gate.json agentStop fixtures/events/agentStop.json --shell powershell
    node tests/try-hook.mjs .github/hooks/quality-gate.json agentStop fixtures/events/agentStop-retry.json --shell powershell
} finally {
    Copy-Item demo-app/src/cart.js.exercise-backup demo-app/src/cart.js -ErrorAction Stop
    Remove-Item demo-app/src/cart.js.exercise-backup
}
npm --prefix demo-app run check
```

If interrupted, restore your backup manually before continuing. Never delete
the backup after a failed restore. Do not use a blanket Git reset to restore
unrelated work. The baseline must pass again.

## Live prompts and observations

| Prompt/action | Event | Expected outcome |
| --- | --- | --- |
| “Run all demo checks and summarize the result without editing.” | `agentStop` after tools | Passing checks allow finishing |
| After safely installing the broken fixture with a backup: “Summarize calculateTotal. If a quality hook reports failure, you may inspect, repair the demo code, and run checks.” | `agentStop` if emitted | Gate detects failure at finish and requests continuation; agent is permitted to repair or explain the blocker |
| Observe a still-failing continuation | A later `agentStop` with active retry state | Checks run again; bounded warning, not infinite blocking |

Restore the backup after the live experiment as well. If the client does not
honor the block response, record it as unverified; tests in CI remain necessary.

## Configuration-only stretch

Reorder `CHECK_STEPS` to `test;lint;format:check` and explain how first-failure
feedback changes. Keep each check bounded and budget the outer timeout.

## Reuse / disable

Reuse these three standard npm script names in another project, or review the
helper's allowlist before adapting it to other check names. Keep CI authoritative.
Remove `quality-gate.json` and restart to disable; do not move it to `sessionEnd`.

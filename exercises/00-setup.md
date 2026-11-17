# 00 · Setup and hook anatomy

## Goal

Prepare a safe workspace and learn the configuration surface. The **hook is the
task**: helpers already work; you configure when and how they run.

## Events

Hooks run at agent lifecycle events, unlike Git hooks, which run at Git events.
Start with `sessionStart`, `userPromptSubmitted`, `preToolUse`, and `postToolUse`.
Use the [events sheet](../docs/events.md) as a reference throughout.

## Read the supplied scripts and environment options

Choose Bash plus `jq` or PowerShell 7. Both tracks are under `scripts/NN-name/`;
read a helper to understand its inputs, but do not implement or complete it.

1. Use a disposable checkout. Inspect `git status --short` and preserve existing
   work. Check `git --version`, `node --version`, and `npm --version`, plus
   `jq --version` for Bash or `pwsh --version` for PowerShell.
2. At the repository root, install the demo dependencies:

   ```text
   npm --prefix demo-app ci
   npm --prefix demo-app run check
   ```

   Use `npm --prefix demo-app install` if intentionally creating/updating a lock
   file, not as the normal reproducible setup. The baseline must pass before
   introducing deliberate failures.
3. Inspect `demo-app/src/cart.js` and its tests. The API is
   `calculateTotal(items, { discountPercent = 0, shippingCents = 0 } = {})`;
   amounts and totals are integer cents. `config/production.json` is harmless
   practice data. `.env.example` contains no real secrets.
4. Record your client/version (`copilot --version`, or VS Code **Help: About**),
   OS, shell, and execution host. In VS Code select **Copilot**, not a different
   agent harness. Review workspace trust and your organization's hook policy.
5. Inspect repository, user, agent, and plugin hook sources. Do not overwrite
   existing configuration. No repository hooks should be active at startup.

## Task: understand a configuration, then start from blank

Create `.github/hooks/` when ready, but do not save an active hook yet. A JSON
file in that directory is an opt-in runtime configuration. This annotated-by-
explanation example shows the native camelCase format:

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "type": "command",
        "bash": "bash scripts/02-session-context/briefing.sh sessionStart",
        "powershell": "pwsh -NoProfile -File scripts/02-session-context/briefing.ps1 sessionStart",
        "env": { "DEMO_DIR": "demo-app" },
        "timeoutSec": 10
      }
    ]
  }
}
```

| Field | Your decision |
| --- | --- |
| `version: 1` | Configuration format version |
| `hooks` | Map of exact event names to arrays of handlers |
| `type: "command"` | Run a supplied command helper |
| `bash` / `powershell` | Platform-specific command; keep both for portability |
| `env` | String-valued helper options; avoid secrets |
| `timeoutSec` | Bound runtime; this is not a security guarantee |
| `matcher` | Optional tool-name pattern on supported tool events, e.g. `edit\|create\|apply_patch` |

The runtime/platform chooses the command; your terminal does not choose it.
For a PowerShell-only experiment on a Unix host, set `bash` to the same `pwsh`
invocation as `powershell`, then verify it in that host. Run from the repository
root; fixture `cwd: "."` is relative to that working directory.

The event JSON arrives on **stdin**. Hook protocol output usually goes on
**stdout** as JSON; diagnostics go on **stderr**. Native responses use top-level camelCase fields,
for example `{"additionalContext":"Run the demo checks before finishing."}`.
The stop gate can return `{"decision":"block","reason":"Tests failed."}`.
`{}` means no hook decision, not approval of a tool. Do not mix in another
harness's nested response envelope. Preserve event-specific payload keys as
documented: the stop retry fixture includes `stop_hook_active`, for example.
The `postToolUseFailure` recovery helper also uses top-level
`additionalContext`. CLI 1.0.105 delivered it to the model alongside the
failure. See [compatibility](../docs/compatibility.md).

## Offline fixture commands

At setup only, use the inactive reference configuration to check dependencies:

**Bash**

```bash
node tests/try-hook.mjs solutions/02-session-context/session-context.json sessionStart fixtures/events/sessionStart-new.json --shell bash
```

**PowerShell**

```powershell
node tests/try-hook.mjs solutions/02-session-context/session-context.json sessionStart fixtures/events/sessionStart-new.json --shell powershell
```

Expect a JSON response with useful demo context, not a modified working tree.
This runner parses the chosen JSON, applies its environment options and
matchers, resolves fixture `cwd: "."`, and executes **hook helpers only**. It
never executes the Copilot tool described in a fixture.

For each topic you choose, test **your active file**, not just the solution.
For example, to test the activity-log topic (use your chosen topic's file and
event if different):

```text
node tests/validate-configs.mjs .github/hooks/activity-log.json
node tests/try-hook.mjs .github/hooks/activity-log.json sessionStart fixtures/events/sessionStart-new.json --shell bash
```

Use `--shell powershell` for that track. Static validation checks JSON and
supplied-script paths; `try-hook` checks registration, matchers, env, and helper
output offline. Neither proves live event delivery or response consumption.
`node tests/run.mjs --shell bash` (or `--shell powershell`) is the separate
supplied-script fixture suite, not a substitute for testing your own JSON.

## Live prompts and observations

| Action/prompt | Event to observe after configuration | Expected outcome |
| --- | --- | --- |
| Start a new session from the repository root | `sessionStart` | A configured handler runs; setup alone enables nothing |
| “Read demo-app/src/cart.js and explain the pricing API.” | `userPromptSubmitted`; `preToolUse` / `postToolUse` **if a tool is used** | Normal tool permissions still apply |

Prompts do not guarantee tool calls. Configure the event handler you want to
test; the optional activity-log exercise provides a convenient observer. Do
not treat a model's answer as proof that a hook ran.

## Configuration-only stretch

Before enabling anything, explain which field changes the execution budget,
which changes the helper's behavior, and which selects an event. No script edit
should be necessary.

## Reuse / disable

Enable only files you wrote/reviewed. Start a fresh session after changing hook
registration. To disable a recipe, move **its JSON** out of `.github/hooks/`
(or remove only that file), then start a fresh session. Leave unrelated hooks
alone. Helpers and solutions outside that directory do not activate themselves.
After setup, choose any topic from [01 · Activity log](01-activity-log.md)
through [07 · Session recovery](07-session-recovery.md). The activity log is a
useful optional first topic for observing live event delivery.

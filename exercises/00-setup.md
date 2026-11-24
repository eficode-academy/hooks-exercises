# 00 · Setup and hook anatomy

**Core · about 10 minutes**

## Problem

Your bank wants developers to use a coding agent, but the agent will run commands
and edit files in repositories that hold payment code. Rules written in a
markdown file are a request; the agent can forget them. A **hook** is a small
program the agent runtime calls at fixed moments, so a rule is enforced every
time. Before you write one, get a safe workspace and learn the shape of a hook.

## Task

1. Use a **disposable checkout**: no production files, no real secrets.
2. From the repository root, run the preflight for your shell:

   **Bash**

   ```bash
   bash scripts/preflight.sh
   ```

   **PowerShell**

   ```powershell
   pwsh -File scripts/preflight.ps1
   ```

   It needs `git` plus `jq` (Bash) or PowerShell 7 (`pwsh`), and warns if the
   Copilot CLI is missing. No package manager or build tool is involved.
   A dev container (`.devcontainer/`) has everything installed if you prefer.
3. Run the demo project's check. `demo-app/` is a tiny integer-cents cart; its
   `check.sh` / `check.ps1` is a stand-in for "your team's tests":

   **Bash**

   ```bash
   bash demo-app/check.sh
   ```

   **PowerShell**

   ```powershell
   pwsh -File demo-app/check.ps1
   ```

4. Note your client and version (`copilot --version`, or VS Code **Help: About**
   with the **Copilot** session target). No hooks are active in this repository
   until you save a JSON file in `.github/hooks/`.

### Anatomy of a hook

A hook configuration is a JSON file in `.github/hooks/`. It maps an **event**
to a **command**. The runtime starts the command, writes the event as JSON on
**stdin**, and reads a JSON answer from **stdout**.

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
        "timeoutSec": 5
      }
    ]
  }
}
```

| Field | What it decides |
| --- | --- |
| `hooks` | Which event triggers the command, e.g. `sessionStart`, `preToolUse`, `agentStop` ([all events](../docs/events.md)) |
| `bash` / `powershell` | The command to run; give both so the hook works on every OS |
| `env` | Options for the script, as strings. Never put secrets here |
| `timeoutSec` | How long the command may run |
| `matcher` | Optional: only run for these tool names, e.g. `edit\|create` |

What a hook can answer (on stdout):

| You want to... | Return |
| --- | --- |
| Give the agent information | `{"additionalContext": "..."}` |
| Stop a tool call | `{"permissionDecision": "deny", "permissionDecisionReason": "..."}` |
| Stop the agent from finishing | `{"decision": "block", "reason": "..."}` |
| Have no opinion | `{}` |

Every helper in `scripts/` is 10-25 lines: **skim it, all you need to know is
stdin in, JSON out.** You never write or edit one; you write the JSON above.

## Check

`scripts/try-hook` plays the runtime offline: it reads your JSON, finds the hooks
for an event, and pipes a fixture event into the command. Try it with the
reference solution (these files are examples, not active hooks):

**Bash**

```bash
bash scripts/try-hook.sh solutions/02-session-context/session-context.json sessionStart fixtures/events/sessionStart-new.json
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 solutions/02-session-context/session-context.json sessionStart fixtures/events/sessionStart-new.json
```

You should see the briefing as `additionalContext`. The runner never runs the
command described in a fixture, it only runs the hook. From now on, test **your
own file** in `.github/hooks/` the same way. A passing offline run shows your
JSON and the script fit together; only a live session shows the agent obeys
([why](../docs/compatibility.md)).

## Next

Start the core path with [01 · Activity log](01-activity-log.md), then 02 and 03.
Only a file in `.github/hooks/` is active. To switch a hook off, move its file out
and start a fresh session.

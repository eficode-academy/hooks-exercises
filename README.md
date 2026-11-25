# GitHub Copilot hooks: configuration-first exercises

A coding agent follows the rules you give it most of the time. A **hook** makes
a rule hold **every** time: a small script the agent runtime calls at fixed
moments (session start, before a tool runs, when the agent tries to finish).
In a regulated setting such as a bank, that is the difference between "we asked
the agent not to touch production config" and "it cannot".

You write the hook **configuration** (JSON: which event, which command, which
options) and prove it works. The scripts are supplied and short (10-25 lines
each): skim one, all you need to know is *stdin in, JSON out*. You write no
shell code and install no packages.

## Pick your path

| | Exercise | Time | The problem it solves |
| --- | --- | ---: | --- |
| **Core** | [00 · Setup and anatomy](exercises/00-setup.md) | 10 min | A safe workspace and the shape of a hook |
| **Core** | [01 · Activity log](exercises/01-activity-log.md) | 15 min | Compliance needs an audit trail of agent actions |
| **Core** | [02 · Session context](exercises/02-session-context.md) | 10 min | Every session needs the house rules |
| **Core** | [03 · Guardrails](exercises/03-guardrails.md) | 20 min | The agent must not edit production config or force-push |
| Stretch | [04 · Check after edits](exercises/04-format-lint.md) | 15 min | Catch leftovers right after each edit |
| Stretch | [05 · Quality gate](exercises/05-quality-gate.md) | 15 min | "Done" means the check passes |
| Stretch | [06 · Failure recovery](exercises/06-failure-recovery.md) | 10 min | Stop the agent guessing after a failure |
| Stretch | [07 · Session recovery](exercises/07-session-recovery.md) | 10 min | Resume work with the right context |
| Stretch | [Extras](#extras-and-reference) | 10 min each | Notifications, personal hooks, agent hooks, secret guard |

**The core path (00-03) takes about 55 minutes.** Finishing it beats clicking
through everything. After setup pick whatever interests you; no exercise needs
another one. Every exercise has the same shape: **Problem, Task, Check.**

Write each JSON file from blank, then compare with `solutions/NN-name/`. Test
it offline with `scripts/try-hook` (the setup exercise explains it) and live in a
Copilot session. No hooks are active until you save a file in `.github/hooks/`;
`solutions/` holds reference answers only.

## What you need

- Git, plus **Bash with `jq`** or **PowerShell 7 (`pwsh`)**.
- GitHub Copilot CLI (or VS Code with the **Copilot** session target) in a
  trusted workspace where your organization allows hooks.
- A disposable checkout. No production files, no real secrets.

Run `bash scripts/preflight.sh` (or `pwsh -File scripts/preflight.ps1`) to check.
Prefer not to install anything? Open the repository in the **dev container**
(`.devcontainer/`): it includes Bash, `jq`, PowerShell, Git, GitHub CLI and
the Copilot CLI.

`demo-app/` is a tiny integer-cents cart. Its `check.sh` / `check.ps1` is a
stand-in for your team's tests; swap in your own command whenever you like.

## Extras and reference

- Extras: [notifications](exercises/extras/notifications.md),
  [personal hooks](exercises/extras/personal-hooks.md),
  [agent-scoped hooks](exercises/extras/agent-scoped-hooks.md),
  [limited secret guard](exercises/extras/secret-guard.md)
- [Events cheat sheet](docs/events.md), [troubleshooting](docs/troubleshooting.md),
  [compatibility and what offline checks prove](docs/compatibility.md),
  [sources](docs/sources.md)

Hooks complement permissions, CI and code review; they are not a tamper-proof
security boundary. The learning material is original, with attribution in
[sources](docs/sources.md). No license is selected; confirm rights and choose one
before redistribution.

# Extra · Agent-scoped hooks

**Stretch · about 10 minutes**

## Problem

A "reviewer" agent should be read-only, and you want an audit trail for that
agent only, not for every developer session in the repository.

## Task

Check [sources](../../docs/sources.md) that your client supports hooks in a custom
agent's frontmatter, then adapt this example. It reuses the activity-log helper;
no new script is needed.

```markdown
---
name: Demo reviewer
description: Read-only review of the demo pricing code
hooks:
  preToolUse:
    - type: command
      command: bash scripts/01-activity-log/log.sh preToolUse
      windows: pwsh -NoProfile -File scripts/01-activity-log/log.ps1 preToolUse
      env:
        HOOK_LOG_DIR: .hooks-state/agent-review
      timeoutSec: 5
---
Review the demo pricing code without changing files.
```

Agent frontmatter uses `command` plus `windows` / `linux` / `osx` overrides,
unlike repository JSON's `bash` / `powershell`.

## Check

Test the helper with your exercise-01 JSON and `try-hook` first. Live: select the
custom agent and ask it to read `demo-app/src/cart.js`; records should appear in
`.hooks-state/agent-review/`. Use a different agent for the same read and expect
no record. Unsupported frontmatter is a compatibility finding, not a failure.

## Stretch

Narrow the hook to one tool name once you have seen the real names in the log.
To disable: remove the `hooks` block from the agent file.

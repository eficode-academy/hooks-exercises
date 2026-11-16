# Extra · Agent-scoped hooks

## Goal / events

Explore a hook that belongs to a specific custom agent instead of every
repository session. Confirm your client supports agent frontmatter hooks first.

## Read / task

Read the current agent-hook documentation linked from [sources](../../docs/sources.md).
The following illustrates the **frontmatter placement**, not a new
repository-wide JSON file. Adapt the file location/schema to your verified
client rather than enabling it blindly:

```markdown
---
name: Demo reviewer
description: Read-only review of the demo pricing code
hooks:
  preToolUse:
    - type: command
      command: bash scripts/01-activity-log/log.sh preToolUse
      windows: pwsh -NoProfile -File scripts/01-activity-log/log.ps1 preToolUse
      linux: bash scripts/01-activity-log/log.sh preToolUse
      osx: bash scripts/01-activity-log/log.sh preToolUse
      env:
        HOOK_LOG_DIR: .hooks-state/agent-review
      timeoutSec: 5
---
Review the demo pricing code without changing files.
```

Agent frontmatter uses `command` as a fallback and `windows` / `linux` / `osx`
platform overrides, unlike repository JSON's `bash` / `powershell` fields.
This reuses the supplied observer. Do not invent a separate script. Confirm
whether your client's agent-scoped format uses the same native event names
before trying this example; unsupported schema is a compatibility finding.

## Offline / live check

Test the observer via your exercise-01 JSON and `tests/try-hook.mjs` first.
The JSON validator for `.github/hooks/` does not validate agent frontmatter.

| Prompt/action | Event / expected artifact |
| --- | --- |
| Select the custom agent and ask it to read demo-app/src/cart.js | Tool-event metadata in the agent-specific directory if scope is supported |
| Use a different agent for the same read | No record from this agent-scoped registration |

Keep the repository activity observer separate, so its records are not mistaken
for this agent's output.

## Configuration-only stretch / disable / reuse

Narrow the observer to an actual tool name after verifying it. Remove the
frontmatter hook block and start a fresh agent session to disable. Reuse scoped
hooks for agent-specific feedback, not as a security boundary or a substitute
for agent permissions.

# Sources and attribution

The exercises in this repository are original learning material. These
references informed the concepts and structure; examples are not copied
verbatim.

- GitHub Copilot, [Hooks reference](https://docs.github.com/en/copilot/reference/hooks-reference):
  authoritative event names, payload fields, configuration, output, decisions,
  timeout behavior, and client-specific support.
- Visual Studio Code, [Configure agent hooks](https://code.visualstudio.com/docs/agent-customization/hooks):
  current Copilot target, shared harness, hook setup, target selection, and
  migration cautions.
- Copilot Academy, [Governance with Hooks](https://copilot-academy.github.io/workshops/immersive-experience/governance_hooks):
  inspiration for a practical progression and checkpoint discussion.
- Eficode Demo Org,
  [Advanced training hooks exercise](https://github.com/EficodeDemoOrg/copilot-training-advanced-TEMPLATE/blob/main/exercises/01-hooks.md):
  inspiration for Bash/PowerShell pairing and lifecycle-log teaching. The
  exercises intentionally replace raw prompt logging with minimal metadata.
- Awesome Copilot, [Automating with Hooks](https://awesome-copilot.github.com/learning-hub/automating-with-hooks/):
  secondary guide that informed the comparison with instructions/skills,
  narrowly layered hooks, session/subagent context, post-edit feedback, and
  notifications. Treat it as further reading, not as the contract. These
  exercises intentionally do **not** adopt three of its patterns. Running a
  repository-wide formatter followed by `git add -A` can format and stage
  unrelated work. A nonzero exit is not a universal stop-block contract, so
  `agentStop` uses decision JSON. Accepted event-name aliases do not imply
  identical payloads. The official reference documents that PascalCase
  `PreToolUse` switches to snake_case inputs and tool-name mappings.
  The guide's prompt-context and local-response recipes are left out of
  the exercises. The reference says config-file `userPromptSubmitted` output
  from command and HTTP hooks is dropped (unlike SDK programmatic hooks). Its
  argument-rewrite example is version-specific. Treat the guide as
  inspiration, not a drop-in reference; see also the
  [compatibility notes](compatibility.md).
- [Secure Copilot Agents: Tools](https://guigui42.github.io/secure-copilot-agents/#tools):
  inspiration for synthetic-payload, timeout, and limitation discussions.

No upstream source text is reproduced as an exercise. No license file exists in
the starting repository; this workspace deliberately leaves license selection
for an explicit publication decision.

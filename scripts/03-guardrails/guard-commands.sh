#!/usr/bin/env bash
# preToolUse guard for shell tools (bash, powershell). A plain text match, not a shell parser.
# Reads:   the event JSON on stdin; looks at toolArgs.command.
# Env:     GUARD_MODE, "deny" (default) or "ask" (let a human decide).
# Returns: a decision for rm -rf, git push --force, git reset --hard and curl | sh; otherwise {}.
input=$(cat)
cmd=$(echo "$input" | jq -r '.toolArgs.command // empty')
block() {
  jq -n --arg mode "${GUARD_MODE:-deny}" --arg why "$1" '{permissionDecision: $mode, permissionDecisionReason: $why}'
  exit 0
}
case "$cmd" in
  *"rm -rf"*|*"rm -fr"*)                  block "rm -rf is blocked. Delete specific files instead." ;;
  *"git push"*"--force"*|*"git push"*" -f"*) block "Force push is blocked. Use a normal push or open a pull request." ;;
  *"git reset --hard"*)                   block "git reset --hard throws work away. Ask a human first." ;;
  *curl*"| sh"*|*curl*"| bash"*)          block "Piping a download into a shell is blocked." ;;
esac
echo '{}'

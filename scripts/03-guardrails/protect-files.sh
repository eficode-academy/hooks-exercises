#!/usr/bin/env bash
# preToolUse guard for file-editing tools (edit, create, apply_patch).
# Reads:   the event JSON on stdin; looks at toolArgs.path (or the patch text for apply_patch).
# Env:     PROTECTED_PATHS, ";"-separated list (default demo-app/config/production.json).
# Returns: a deny decision if the target contains a protected path, otherwise {} (no decision).
input=$(cat)
target=$(echo "$input" | jq -r '.toolArgs | (.path // .filePath // .input // .patch // empty)')
target=${target//\\//}
IFS=';' read -ra protected <<< "${PROTECTED_PATHS:-demo-app/config/production.json}"
for p in "${protected[@]}"; do
  case "$target" in
    *"$p"*)
      echo "{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$p is protected. Edit another file or ask a human.\"}"
      exit 0 ;;
  esac
done
echo '{}'

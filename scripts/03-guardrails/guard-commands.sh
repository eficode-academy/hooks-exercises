#!/usr/bin/env bash
# preToolUse bash/powershell toolArgs.command only. GUARD_MODE=deny (default) or ask.
# Text heuristics, not a shell parser: quoted examples can match; aliases, quoting,
# obfuscation, global git options, and equivalent PowerShell commands can evade them.
# This hook never executes the supplied command.
set -u
fail() { printf 'guard-commands: %s\n' "$1" >&2; printf '{}\n'; exit 2; }
command -v jq >/dev/null 2>&1 || fail 'jq is required.'
input=$(cat) || fail 'Cannot read hook input.'
printf '%s' "$input" | jq -e 'type == "object" and (.cwd | type == "string" and length > 0)' >/dev/null 2>&1 ||
  fail 'Expected an object with an absolute cwd.'
cwd=$(printf '%s' "$input" | jq -r '.cwd')
[[ "$cwd" = /* || "$cwd" =~ ^[A-Za-z]:[/\\] ]] && [[ -d "$cwd" ]] || fail 'cwd must be an existing absolute directory.'
mode=${GUARD_MODE-deny}
[[ "$mode" == deny || "$mode" == ask ]] || fail 'GUARD_MODE must be deny or ask.'
printf '%s' "$input" | jq -c --arg mode "$mode" '
  if (.toolName | type) == "string" and (.toolName != "bash" and .toolName != "powershell") then {}
  elif (.toolName != "bash" and .toolName != "powershell") or
     (.toolArgs | type) != "object" or (.toolArgs.command | type) != "string" then
    {permissionDecision:"deny", permissionDecisionReason:"Cannot safely inspect this command: expected bash/powershell toolArgs.command as a string."}
  else .toolArgs.command as $c
    | (if ($c | test("(^|[\\s;&|()])rm\\s+(-[A-Za-z]*r[A-Za-z]*f[A-Za-z]*|-[A-Za-z]*f[A-Za-z]*r[A-Za-z]*|-[A-Za-z]*r[A-Za-z]*\\s+-[A-Za-z]*f[A-Za-z]*|-[A-Za-z]*f[A-Za-z]*\\s+-[A-Za-z]*r[A-Za-z]*)(\\s|$)"; "i")) then
        "Recursive forced deletion (rm -rf)"
      elif ($c | test("(^|[\\s;&|()])git\\s+reset\\s+[^\\r\\n;&|]*--hard(\\s|$)"; "i")) then
        "Discarding changes (git reset --hard)"
      elif ($c | test("(^|[\\s;&|()])git\\s+push\\s+[^\\r\\n;&|]*(--force(?:-with-lease(?:=[^\\s;&|]+)?|-if-includes)?|-f)(\\s|$)"; "i")) then
        "Rewriting remote history (git push --force/-f)"
      else null end) as $risk
    | if $risk == null then {} else
        {permissionDecision:$mode, permissionDecisionReason:($risk + " is guarded. Inspect git status/diff, make a backup, and ask a human to run a reviewed recovery command instead. No command was executed by this hook.")}
      end
  end' || fail 'Malformed JSON input.'

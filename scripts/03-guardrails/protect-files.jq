# Lexical paths only: this intentionally does not resolve symlinks or inspect shell commands.
def path($cwd):
  if type != "string" or length == 0 or test("[\\x00-\\x1f]") then error("Invalid path") else . end
  | gsub("\\\\"; "/")
  | if test("^//") then error("UNC paths are not supported") else . end
  | if test("^[A-Za-z]:($|[^/])") then error("Drive-relative paths are not supported") else . end
  | if startswith("/") and ($cwd | test("^[A-Za-z]:[/\\\\]")) then $cwd[0:2] + . else . end
  | if startswith("/") or test("^[A-Za-z]:/") then . else ($cwd + "/" + .) end
  | if test("^[A-Za-z]:") then ascii_downcase else . end
  | split("/") | reduce .[] as $part
    ([]; if $part == "" or $part == "." then .
         elif $part == ".." then
           if length == 0 or (length == 1 and (.[0] | test("^[a-z]:$"))) then error("Path escapes root")
           else .[:-1] end
         else . + [$part] end)
  | if (.[0] // "" | test("^[a-z]:$")) then join("/") else "/" + join("/") end;
def patchpaths:
  if type != "string" then error("apply_patch needs string input or patch") else . end
  | gsub("\r\n"; "\n") | split("\n") | if .[-1] == "" then .[:-1] else . end
  | if .[0] != "*** Begin Patch" or .[-1] != "*** End Patch" then error("Unknown patch envelope") else .[1:-1] end
  | reduce .[] as $line
      ({paths:[], seen:false};
       if ($line | test("^\\*\\*\\* (Add File|Update File|Delete File|Move to): ")) then
         .paths += [($line | sub("^\\*\\*\\* (Add File|Update File|Delete File|Move to): "; ""))] | .seen = true
       elif $line == "*** End of File" or ($line | startswith("@@")) or
            ($line | test("^[ +\\-]")) or $line == "" then
         if .seen then . else error("Patch content before a file header") end
       else error("Unknown patch syntax") end)
  | .paths | if length == 0 then error("Patch has no file headers") else . end;
if (.toolName | type) == "string" and (.toolName != "edit" and .toolName != "create" and .toolName != "apply_patch") then {}
else try (
  . as $event
  | (.cwd | path(.)) as $cwd
  | ($protected | if length == 0 then error("PROTECTED_PATHS must not be empty") else split(";") end | map(path($cwd))) as $protectedPaths
  | if (.toolArgs | type) != "object" then error("toolArgs must be an object") else . end
  | (if .toolName == "edit" or .toolName == "create" then
       .toolArgs as $args
       | if ($args | has("path")) and ($args | has("filePath")) then
           ($args.path | path($cwd)) as $p | ($args.filePath | path($cwd)) as $alias
           | if $p != $alias then error("path and filePath disagree") else [$p] end
         elif ($args | has("path")) then [($args.path | path($cwd))]
         elif ($args | has("filePath")) then [($args.filePath | path($cwd))]
         else error("Missing path (or filePath alias)") end
     elif .toolName == "apply_patch" then
       .toolArgs as $args
       | if ($args | has("input")) and ($args | has("patch")) and $args.input != $args.patch then
           error("input and patch disagree")
         else (if ($args | has("input")) then $args.input else $args.patch end) end
       | patchpaths | map(path($cwd))
     else error("Unsupported tool; use matcher edit|create|apply_patch") end) as $paths
  | [$paths[] | select(. as $p | $protectedPaths | index($p))] as $blocked
  | if ($blocked | length) > 0 then
      {permissionDecision:"deny", permissionDecisionReason:("Protected file: " + ($blocked | unique | join(", ")) + ". Edit an unprotected example instead, or ask a human to change PROTECTED_PATHS.")}
    else {} end
) catch {permissionDecision:"deny", permissionDecisionReason:("Cannot safely inspect this edit: " + . + ". Use a direct edit/create path or a standard apply_patch input.")}
end

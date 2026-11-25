# Extra · A limited secret guard

**Stretch · about 10 minutes**

## Problem

Developers keep `.env` files next to code. A bank does not want an agent
rewriting a file that holds credentials. The file guard from exercise 03 already
blocks edits to a list of paths; point it at "secret" files.

## Task

Create a harmless practice file with a dummy marker, never a real secret:

```bash
echo '{"marker": "dummy"}' > demo-app/config/secret-demo.json
```

Write `.github/hooks/secret-guard.json`: a `preToolUse` entry with
`matcher: "edit|create|apply_patch"`, the `protect-files` commands from
exercise 03, and `"env": { "PROTECTED_PATHS": "demo-app/config/secret-demo.json;demo-app/.env.example" }`.

## Check

Copy `fixtures/events/preToolUse-edit-protected.json`, change its `path` to
`demo-app/config/secret-demo.json`, and run it through `try-hook` with your new
config. Expect a deny decision. Live: *"Change the marker in demo-app/config/secret-demo.json
using a direct edit. If denied, stop."*

This checks **paths**, not contents. It does not see shell commands, reads, or
anything already in the agent's context. Use permissions, secret scanning and
review for real protection.

## Stretch

Delete the practice file when you are done (`rm demo-app/config/secret-demo.json`)
and remove the extra JSON from `.github/hooks/`.

# Extra · Personal hooks

**Stretch · about 10 minutes**

## Problem

Some hooks are yours, not the team's: your own activity log, your own bell. They
should follow you into every repository without being committed to any of them.

## Task

Find where your client reads user-level hooks (see [sources](../../docs/sources.md);
the location is client-specific). Write a configuration there that runs
`log.sh` / `log.ps1` from this checkout. Other repositories do not contain this
folder, so use **absolute, quoted** script paths, and set `HOOK_LOG_DIR` to an
absolute folder so logs from different projects do not mix with this one.

## Check

Test the file offline from this checkout. Use a scratch copy of the config with
the same commands, because `try-hook` takes any path:

**Bash**

```bash
bash scripts/try-hook.sh solutions/01-activity-log/activity-log.json sessionStart fixtures/events/sessionStart-new.json
```

**PowerShell**

```powershell
pwsh -File scripts/try-hook.ps1 solutions/01-activity-log/activity-log.json sessionStart fixtures/events/sessionStart-new.json
```

Live: start a session in an unrelated disposable folder and look for a line in
your absolute log folder. Repository and personal hooks can both run, so check
the log for duplicates. Never commit personal paths to shared JSON.

## Stretch

Disable the personal hook and confirm the unrelated project no longer logs.

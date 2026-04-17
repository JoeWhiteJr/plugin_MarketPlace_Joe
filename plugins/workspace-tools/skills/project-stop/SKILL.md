---
name: project-stop
description: Stop background dev servers previously started via project-start.
disable-model-invocation: true
---

# Stop Workspace Project

Stop the background dev servers that `/workspace-tools:project-start` launched
for a project. Reads the tracked PIDs and sends SIGTERM (then SIGKILL if needed).

## Arguments

The user provides: `<project-name>`

## Steps

1. Invoke the script with `$ARGUMENTS`:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/project-stop.sh" $ARGUMENTS
   ```
   If `CLAUDE_PLUGIN_ROOT` is not set in the environment, fall back to:
   ```bash
   bash ~/.claude/plugins/marketplaces/joe-marketplace/plugins/workspace-tools/scripts/project-stop.sh $ARGUMENTS
   ```

2. Relay the script's stdout to the user verbatim.

3. If the script reports `No running processes tracked for <name>.`, let the
   user know nothing was running (this is a safe, idempotent result).

---
name: project-start
description: Load and start a saved workspace project — runs git checks, loads context, launches configured dev servers in the background.
disable-model-invocation: true
---

# Start Workspace Project

Load a saved project configuration, run git safety checks, and launch configured
dev servers in the background. The script does the work — relay its output
verbatim, then read the context files it lists so they enter the conversation.

## Arguments

The user provides: `<project-name> [--dry-run]`

- `<project-name>` — a saved project (see `/workspace-tools:project-list`)
- `--dry-run` — print the plan without launching any processes

If no name is given, the script lists available projects and exits with an error.

## Steps

1. Invoke the script with `$ARGUMENTS`:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/project-start.sh" $ARGUMENTS
   ```
   If `CLAUDE_PLUGIN_ROOT` is not set in the environment, fall back to:
   ```bash
   bash ~/.claude/plugins/marketplaces/joe-marketplace/plugins/workspace-tools/scripts/project-start.sh $ARGUMENTS
   ```

2. Relay the script's stdout to the user verbatim.

3. **Then read the context files.** The script prints a "── Context files ──"
   section with absolute paths but does NOT read their contents. After the script
   finishes, use the Read tool to load each listed file (skip any marked
   `(missing)`) so the project context enters the conversation.

4. If the script launched servers, remind the user they can stop them with
   `/workspace-tools:project-stop <name>`.

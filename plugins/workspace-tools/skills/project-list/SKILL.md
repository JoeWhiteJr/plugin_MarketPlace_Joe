---
name: project-list
description: List all saved workspace project configurations with their details.
disable-model-invocation: true
---

# List Workspace Projects

Run the list script and relay its output to the user verbatim. Do not summarize or reformat — the script's output is already formatted for the user.

## Steps

1. Invoke the script:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/project-list.sh"
   ```
   If `CLAUDE_PLUGIN_ROOT` is not set in the environment, fall back to:
   ```bash
   bash ~/.claude/plugins/marketplaces/joe-marketplace/plugins/workspace-tools/scripts/project-list.sh
   ```

2. Relay the script's stdout to the user.

3. If the script reports "No saved projects", remind the user they can run `/workspace-tools:project-seed` to pre-seed the 6 known projects.

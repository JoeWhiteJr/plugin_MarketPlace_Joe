---
name: project-seed
description: Pre-seed the 6 known workspace projects
disable-model-invocation: true
---

# Seed Workspace Projects

Run the seed script and relay its output to the user verbatim. Do not summarize or reformat — the script's output is already formatted for the user.

## Steps

1. Invoke the script:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/project-seed.sh"
   ```
   If `CLAUDE_PLUGIN_ROOT` is not set in the environment, fall back to:
   ```bash
   bash ~/.claude/plugins/marketplaces/joe-marketplace/plugins/workspace-tools/scripts/project-seed.sh
   ```

2. Relay the script's stdout to the user.

3. If the user wants to see what was seeded, suggest running `/workspace-tools:project-list`.

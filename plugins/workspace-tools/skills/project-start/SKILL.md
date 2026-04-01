---
name: project-start
description: Load and start a saved project configuration, opening context files and setting up the workspace.
user_invocable: true
---

## Start Workspace Project

Load a saved project configuration and set up the workspace.

### Arguments
The user should provide: `<project-name>`

If no name is provided, run `/workspace-tools:project-list` first to show available projects.

### Steps

1. **Load project configuration:**
   - Read `~/.claude/workspace-projects/<name>/project.json`
   - If not found, list available projects and ask user to pick one

2. **Validate the workspace:**
   - Check that the root directory exists
   - Check that terminal working directories exist
   - Warn (don't fail) if any directories are missing — offer to create them

3. **Load context files:**
   - Read each file listed in `context_files` from the project's `context/` directory
   - Display a summary of what context was loaded
   - These files inform the session about the project's architecture, goals, and current state

4. **Set up the environment:**
   - `cd` to the project root directory
   - Run `git status` to show current state
   - Detect available tools (same checks as session-start hook)

5. **Display terminal instructions:**
   If the project has multiple terminals configured:
   - Show the terminal names and their working directories
   - Suggest the user spawn additional terminals if needed
   - For WSL: remind about `wt.exe` for Windows Terminal tabs

   Example output:
   ```
   Project "wasden-watch" loaded.
   Root: /home/joe/Special-Sprinkle-Sauce
   
   Terminals:
     Backend  -> /home/joe/Special-Sprinkle-Sauce/backend
     Frontend -> /home/joe/Special-Sprinkle-Sauce/frontend
   
   Context loaded: README.md, docs/architecture.md
   
   Currently in: Backend terminal
   To open Frontend: wt.exe -w 0 new-tab wsl.exe -d Ubuntu-22.04 -e claude
   ```

6. **Report ready state:**
   - Summarize what was loaded
   - Show any warnings (missing dirs, stale context files)
   - Ready for the user to start working

### Important
- Always use absolute paths
- Never delete or modify project configurations during start
- If context files reference files that no longer exist, warn but continue

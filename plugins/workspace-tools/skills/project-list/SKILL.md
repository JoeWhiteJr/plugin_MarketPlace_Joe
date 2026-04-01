---
name: project-list
description: List all saved workspace project configurations with their details.
user_invocable: true
---

## List Workspace Projects

Show all saved project configurations.

### Steps

1. **Scan for projects:**
   - Look in `~/.claude/workspace-projects/` for subdirectories containing `project.json`
   - If the directory doesn't exist or is empty, tell the user:
     "No saved projects. Use `/workspace-tools:project-save <name>` to save your current workspace."

2. **Display each project:**
   For each project found, show:
   - **Name** and description
   - **Root directory** (and whether it still exists)
   - **Terminals** — count and names
   - **Context files** — count and names
   - **Created date**
   - **Project type** (Python, TypeScript, etc.)

3. **Format as a clean table or list:**

   Example:
   ```
   Saved Projects (3):
   
   wasden-watch
     Trading AI system — FastAPI + Next.js + Supabase
     Root: /home/joe/Special-Sprinkle-Sauce
     Terminals: Backend, Frontend (2)
     Context: README.md, architecture.md
     Created: 2026-03-15
   
   rydlnk
     Schedule-optimized ridesharing platform
     Root: /home/joe/Utah_Commuting
     Terminals: Analysis (1)
     Context: data-sources.md
     Created: 2026-03-20
   
   levelup
     Celestial-themed gamification app
     Root: /home/joe/LevelUp
     Terminals: Main (1)
     Created: 2026-03-25
   ```

4. **Show usage hint:**
   - `Use /workspace-tools:project-start <name> to launch a project`
   - `Use /workspace-tools:project-save <name> to save a new project`

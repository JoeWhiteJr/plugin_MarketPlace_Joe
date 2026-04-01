---
name: project-save
description: Save the current workspace as a named project configuration with terminals, working directories, and context files.
user_invocable: true
---

## Save Workspace Project

Save the current workspace setup as a reusable project configuration.

### Arguments
The user should provide: `<project-name> [description]`

If no name is provided, ask for one.

### Steps

1. **Gather project info:**
   - Project name from arguments (or ask)
   - Description (from arguments, or generate from repo/directory context)
   - Current working directory
   - Detect project type (Python, Node, TypeScript, etc.)

2. **Determine terminal configuration:**
   - Ask the user what terminals they want for this project (e.g., "Backend", "Frontend", "Tests")
   - For each terminal, record: name, working directory, and optional system prompt
   - If the user doesn't specify, create a sensible default based on project structure:
     - Monorepo with `backend/` + `frontend/`: 2 terminals
     - Single project: 1 terminal at project root

3. **Collect context files (optional):**
   - Ask if there are key files that should be auto-loaded when starting the project
   - Examples: README.md, architecture docs, task lists, API specs
   - Copy referenced files to `~/.claude/workspace-projects/<name>/context/`
   - Convert to `.md` format if needed

4. **Save the configuration:**
   Write a JSON file to `~/.claude/workspace-projects/<name>/project.json`:

   ```json
   {
     "name": "<project-name>",
     "description": "<description>",
     "created": "<ISO 8601 timestamp>",
     "root": "<absolute path to project root>",
     "terminals": [
       {
         "name": "<terminal-name>",
         "workdir": "<absolute path>",
         "system_prompt": "<optional custom instructions>"
       }
     ],
     "context_files": ["README.md", "docs/architecture.md"],
     "project_type": ["Python", "TypeScript"]
   }
   ```

5. **Confirm to user:**
   - Show the saved configuration summary
   - Remind them: `Use /workspace-tools:project-start <name> to launch this project`

### Important
- Use absolute paths, never relative (WSL cross-filesystem safety)
- Use `cp` + `rm` instead of `mv` for any cross-filesystem operations
- Never overwrite an existing project without confirming first
- Store projects in `~/.claude/workspace-projects/`, NOT `~/.claude/projects/` (avoid conflicts with Claude's internal directories)

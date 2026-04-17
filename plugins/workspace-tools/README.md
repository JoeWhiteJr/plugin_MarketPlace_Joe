# workspace-tools

PostToolUse code validation, session-start environment detection, and workspace project management for Claude Code.

Adapted from [Secrettestbot/claude_hooks](https://github.com/Secrettestbot/claude_hooks) with customizations for WSL2, ruff, vitest, and TypeScript workflows.

## Hooks

### PostToolUse — Code Validation

Automatically validates code after every Edit/Write operation, providing immediate feedback to Claude so it can self-correct.

**Supported languages:**
- **Python:** syntax check, ruff lint, mypy type check, pytest (for test files)
- **TypeScript/TSX:** tsc --noEmit, ESLint, vitest (for test files)
- **JavaScript/JSX:** Node syntax check
- **R:** syntax check, lintr, ML train/test split warning
- **Shell:** ShellCheck

### SessionStart — Environment Info

Displays project context at the start of every session:
- Platform detection (WSL2)
- Git repo, branch, uncommitted changes
- Available dev tools with versions
- Project type detection
- Saved project count

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| project-seed | `/workspace-tools:project-seed` | Pre-seed `~/.claude/workspace-projects/` with 6 known projects (idempotent — skips existing) |
| project-list | `/workspace-tools:project-list` | List all saved projects with root, dev commands, context, memory pointer |
| project-start | `/workspace-tools:project-start <name> [--dry-run]` | Load project, git-fetch, show status, launch dev servers in background, print PIDs + log tails |
| project-stop | `/workspace-tools:project-stop <name>` | Stop background dev servers previously launched by project-start |
| project-save | `/workspace-tools:project-save <name> [description]` | Save current cwd as a named project (interactive via Claude, not the shell) |

## Storage

Projects are stored at:
```
~/.claude/workspace-projects/<name>/
├── project.json      # config
├── context/          # copied markdown docs (optional)
├── logs/             # per-dev-command log files (created by project-start)
└── .pids             # tracked background PIDs (created by project-start)
```

**Note:** `~/.claude/projects/` is Claude's auto-memory dir and is never touched by this plugin.

## project.json schema

```json
{
  "name": "special-sprinkle-sauce",
  "description": "Trading AI: FastAPI + Next.js + Supabase",
  "created": "2026-04-17",
  "root": "/home/joe/Special-Sprinkle-Sauce",
  "terminals": [
    {"name": "backend", "workdir": "/abs/path", "system_prompt": ""}
  ],
  "context_files": ["docs/wasden_watch_progress.md"],
  "project_type": ["Python", "TypeScript"],
  "dev_commands": [
    {"name": "backend", "cwd": "backend", "cmd": "uvicorn app.main:app --reload", "port": 8000},
    {"name": "frontend", "cwd": "frontend", "cmd": "npm run dev", "port": 3000}
  ],
  "test_command": "make test",
  "memory_pointer": "MEMORY.md § Special Sprinkle Sauce"
}
```

All fields except `name` are optional. `cwd` is resolved relative to `root` unless absolute. `port` is optional per dev command. Background servers launch via `setsid nohup` so they survive the script.

## Pre-seeded projects

Running `/workspace-tools:project-seed` copies these into `~/.claude/workspace-projects/`:

- **special-sprinkle-sauce** — FastAPI + Next.js trading AI (backend:8000, frontend:3000)
- **rydlnk** — R/Python ridesharing data analysis
- **levelup** — Static site (python3 http.server on 8888)
- **meridian** — AI impact diagnostics (stack TBD)
- **plugin-marketplace** — joe-marketplace repo
- **dev-cycle** — dev-cycle plugin workspace

Existing projects are skipped — the seed command is safe to re-run.

## Installation

### Via marketplace
```
claude plugin install workspace-tools --from joe-marketplace
```

### Hook setup
After installing, add the hooks to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugins/marketplaces/joe-marketplace/plugins/workspace-tools/hooks/post-tool-use.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugins/marketplaces/joe-marketplace/plugins/workspace-tools/hooks/session-start.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## Dependencies

- `bash`
- `python3` (used for JSON parsing — no `jq` required)
- `git` (optional — used in project-start's safety gate)

## Credits

- Original hooks by [Secrettestbot/claude_hooks](https://github.com/Secrettestbot/claude_hooks)
- Adapted by JoeWhiteJr for WSL2 + ruff + TypeScript workflows

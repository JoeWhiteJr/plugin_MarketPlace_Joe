# workspace-tools

PostToolUse code validation, session-start environment detection, and project management for Claude Code.

Adapted from [Secrettestbot/claude_hooks](https://github.com/Secrettestbot/claude_hooks) with customizations for WSL2, ruff, vitest, and TypeScript workflows.

## Hooks

### PostToolUse — Code Validation

Automatically validates code after every Edit/Write operation, providing immediate feedback to Claude so it can self-correct before you even see the error.

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
| project-save | `/workspace-tools:project-save <name>` | Save workspace as a named project |
| project-start | `/workspace-tools:project-start <name>` | Load and start a saved project |
| project-list | `/workspace-tools:project-list` | List all saved projects |

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

## Credits

- Original hooks by [Secrettestbot/claude_hooks](https://github.com/Secrettestbot/claude_hooks)
- Adapted by JoeWhiteJr for WSL2 + ruff + TypeScript workflows

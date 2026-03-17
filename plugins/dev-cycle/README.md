# Dev-Cycle Plugin

A 4-team continuous improvement workflow for Claude Code. Runs autonomous audit, scout, develop, and QA cycles on any project.

## Quick Start

```bash
# Install the plugin
claude plugin add --from ./plugins/dev-cycle

# Navigate to any project
cd /path/to/your/project

# Start the loop
/dev-cycle:start

# Check progress
/dev-cycle:status

# Stop when done
/dev-cycle:stop
```

## How It Works

```
/dev-cycle:start
    │
    ▼
[Pre-flight + Project Detection]
    │
    ▼
╔═══ CYCLE N ═══════════════════════════════════╗
║                                                ║
║  [Code Auditor] ──┐                            ║
║                    ├──▶ [Aggregate top 5]       ║
║  [Improvement Scout]┘        │                  ║
║                              ▼                  ║
║                     [Create tasks.md]           ║
║                              │                  ║
║                    ┌─────────┘                  ║
║                    ▼                            ║
║           [Developer: Task 1]                   ║
║                    │                            ║
║                    ▼                            ║
║           [QA: Task 1] ──▶ PASS/FAIL/ESCALATE   ║
║                    │                            ║
║                   ...                           ║
║                    │                            ║
║                    ▼                            ║
║           [Cycle Summary + Archive]             ║
║                                                ║
╚════════════════════════════════════════════════╝
    │
    ├── "running" + no P0 ──▶ CYCLE N+1
    ├── "running" + had P0 ──▶ Ask user ──▶ CYCLE N+1
    └── "stopped" ──▶ END
```

## The 4 Teams

| Team | Agent | Role |
|------|-------|------|
| 1 | **Code Auditor** | Finds bugs, dead code, consolidation opportunities, security vulnerabilities |
| 2 | **Improvement Scout** | Finds UX gaps, dark mode issues, a11y problems, performance opportunities |
| 3 | **Developer** | Implements fixes/features, one branch per task, creates PRs |
| 4 | **QA Reviewer** | Reviews changes, runs tests, Playwright E2E, dependency scanning |

## Skills

| Skill | Description |
|-------|-------------|
| `/dev-cycle:start` | Initialize project detection and start continuous loop |
| `/dev-cycle:cycle` | Run a single improvement cycle (manual mode) |
| `/dev-cycle:status` | Show current state, task board, and history |
| `/dev-cycle:stop` | Gracefully stop the loop |

## Project Detection

The plugin auto-detects your project's stack:

- **Language**: JS/TS, Python, Rust, Go
- **Framework**: Next.js, FastAPI, Django, Express, React, Vue, Flask
- **Test Runner**: vitest, jest, pytest, cargo test, go test
- **Linter**: ESLint, Ruff, golangci-lint
- **Package Manager**: npm, yarn, pnpm, poetry, uv
- **CI**: GitHub Actions, GitLab CI, Jenkins

## Runtime Files

The plugin creates a `.workflow/` directory (auto-added to `.gitignore`):

```
.workflow/
├── state.json          # Workflow state and project profile
├── tasks.md            # Current cycle's task board
└── history/
    ├── cycle-1.md      # Archived task boards
    └── ...
```

## Priority Levels

| Priority | Meaning | Action |
|----------|---------|--------|
| P0 | Security vulnerability or crash | Fix immediately, triggers approval gate |
| P1 | Bug or significant issue | Fix this cycle |
| P2 | Dead code, minor improvement | Fix when convenient |
| P3 | Cosmetic, nice-to-have | Low priority |

## Escalation Chain

QA fail → Developer retry (1x) → Blocked → Main Claude → User

## Error Handling

- **Not a git repo**: Pre-flight stops with instructions
- **`gh` not authenticated**: Stops with setup guide
- **Zero findings**: Ends cycle gracefully
- **Protected files**: Developer marks task Blocked
- **Branch conflicts**: Developer rebases, resolves, or marks Blocked
- **Playwright install fails**: QA continues with unit tests

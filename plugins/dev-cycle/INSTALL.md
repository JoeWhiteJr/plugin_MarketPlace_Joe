# Dev-Cycle Plugin — Installation Guide

## Prerequisites

- [Claude Code CLI](https://claude.ai/download) installed
- Git
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated (`gh auth login`)

## Installation

### Step 1 — Clone the Marketplace

```bash
git clone https://github.com/JoeWhiteJr/plugin_MarketPlace_Joe.git
cd plugin_MarketPlace_Joe
```

### Step 2 — Launch Claude Code with the Plugin

```bash
claude --plugin-dir ./plugins/dev-cycle
```

This loads the dev-cycle plugin for that session. You'll see four new skills available:

| Skill | What it does |
|-------|-------------|
| `/dev-cycle:start` | Detect your project stack and start the continuous improvement loop |
| `/dev-cycle:cycle` | Run a single audit → develop → QA cycle (manual mode) |
| `/dev-cycle:status` | Show current state, task board, and cycle history |
| `/dev-cycle:stop` | Gracefully stop the loop |

### Persistent Installation (optional)

If you want the plugin available in every Claude Code session without the `--plugin-dir` flag, run these commands **inside a Claude Code session**:

```
/plugin marketplace add /path/to/plugin_MarketPlace_Joe
/plugin install dev-cycle@joe-marketplace
```

Replace `/path/to/` with wherever you cloned the repo.

## Usage

### 1. Navigate to any project

```bash
cd /path/to/your/project
```

The project should be a git repo with a remote on GitHub.

### 2. Start the loop

Launch Claude Code (with the plugin loaded) and run:

```
/dev-cycle:start
```

The plugin will:
1. **Detect your stack** — language, framework, test runner, linter, package manager, CI
2. **Create `.workflow/`** — local state directory (auto-added to `.gitignore`)
3. **Run improvement cycles** — each cycle:
   - **Audit**: Code Auditor + Improvement Scout scan in parallel (bugs, security, UX, performance, a11y)
   - **Plan**: Top 5 findings become tasks
   - **Develop**: Developer agent implements each task on its own branch
   - **QA**: QA agent reviews, runs tests, Playwright E2E, dependency scan
   - **PR**: Each task gets its own PR
4. **Loop** — continues to the next cycle until you stop it

### 3. Monitor progress

```
/dev-cycle:status
```

Shows: cycle number, project profile, current task board, history, and trends.

### 4. Stop when done

```
/dev-cycle:stop
```

Prints a final report with total cycles, tasks completed, and open PRs to review.

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
║                    ├──▶ [Top 5 findings]        ║
║  [Improvement Scout]┘        │                  ║
║                              ▼                  ║
║                     [Create task board]          ║
║                              │                  ║
║                    ┌─────────┘                  ║
║                    ▼                            ║
║           [Developer: Task 1]                   ║
║                    ▼                            ║
║           [QA: Task 1] ──▶ PASS/FAIL            ║
║                    ▼                            ║
║           [Developer: Task 2]                   ║
║                   ...                           ║
║                    ▼                            ║
║           [Cycle Summary + Archive]             ║
║                                                ║
╚════════════════════════════════════════════════╝
    │
    ├── running + no P0 ──▶ next cycle
    ├── running + had P0 ──▶ asks you first ──▶ next cycle
    └── stopped ──▶ done
```

## The 4 Teams

| Team | Agent | Focus |
|------|-------|-------|
| 1 | **Code Auditor** | Bugs, dead code, consolidation, security (OWASP Top 10), code smells |
| 2 | **Improvement Scout** | UX gaps, dark mode, accessibility, performance, QoL, features |
| 3 | **Developer** | Implements fixes/features, creates branches + PRs, runs linter + tests |
| 4 | **QA Reviewer** | Code review, test suite, Playwright E2E, dependency audit, PASS/FAIL/ESCALATE |

## Supported Stacks

Auto-detected — no configuration needed:

| Category | Supported |
|----------|-----------|
| Languages | JavaScript/TypeScript, Python, Rust, Go |
| Frameworks | Next.js, React, Vue, Express, FastAPI, Django, Flask |
| Test Runners | vitest, jest, pytest, cargo test, go test, make test |
| Linters | ESLint, Ruff, golangci-lint |
| Package Managers | npm, yarn, pnpm, poetry, uv |
| CI | GitHub Actions, GitLab CI, Jenkins |

## What Gets Created in Your Project

A `.workflow/` directory (automatically gitignored):

```
.workflow/
├── state.json          # Status, cycle number, project profile
├── tasks.md            # Current cycle's task board
└── history/
    ├── cycle-1.md      # Archived task boards
    └── ...
```

No other files in your project are created by the plugin — all changes come through normal branches and PRs.

## Priority Levels

| Priority | Meaning | Behavior |
|----------|---------|----------|
| **P0** | Security vulnerability or crash | Fixed first. Triggers approval gate before next cycle. |
| **P1** | Bug or significant issue | Fixed this cycle |
| **P2** | Dead code, minor improvement | Fixed when convenient |
| **P3** | Cosmetic, nice-to-have | Low priority |

## Tips

- **Review PRs as they come in** — the plugin creates them but never merges. You stay in control.
- **Run `/dev-cycle:status` anytime** — even mid-cycle, to see what's happening.
- **P0 tasks pause the loop** — you'll be asked to approve before continuing. This is a safety gate.
- **Blocked tasks are normal** — if QA fails twice or a protected file needs changes, the task gets blocked and the cycle continues with the rest.
- **Single cycle mode** — use `/dev-cycle:cycle` if you just want one pass without the continuous loop.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Not a git repository" | Run `git init` or `cd` to a repo |
| "GitHub CLI not authenticated" | Run `gh auth login` |
| Skills not showing up | Make sure you launched with `--plugin-dir` pointing to the dev-cycle directory |
| Plugin can't detect your stack | Works best with standard project layouts. Check that config files (package.json, requirements.txt, etc.) are in the repo root. |

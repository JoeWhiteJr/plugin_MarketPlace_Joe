---
name: start
description: "Start the continuous dev-cycle improvement loop: detect project, initialize state, and run audit/develop/QA cycles until stopped."
---

# Dev-Cycle: Start

You are executing the `start` skill — the entry point for the 4-team continuous improvement workflow. This skill detects the project, initializes state, and loops through improvement cycles until the user stops the workflow.

---

## Phase 1 — Pre-flight Checks

1. **Verify git repo**: Run `git rev-parse --is-inside-work-tree`. If not a git repo, stop:
   > This directory is not a git repository. Initialize one with `git init` or navigate to a repo.

2. **Verify GitHub CLI**: Run `gh auth status`. If not authenticated, stop:
   > GitHub CLI is not authenticated. Run `gh auth login` first.

3. **Detect default branch**: Run `git remote show origin | grep 'HEAD branch'` and extract the branch name. Store as `DEFAULT_BRANCH`. If no remote, use `main`.

4. **Verify clean state**: Run `git status --porcelain`. If there are uncommitted changes, warn:
   > You have uncommitted changes. Consider committing or stashing them before starting a dev cycle.
   >
   > Continue anyway? (The workflow creates branches and may conflict with uncommitted work.)

   Wait for user confirmation before proceeding.

---

## Phase 2 — Project Detection

Auto-detect the project profile by checking for these files. Store results in the profile.

### Language
| Check | Result |
|-------|--------|
| `package.json` exists | JavaScript/TypeScript |
| `requirements.txt` OR `pyproject.toml` exists | Python |
| `Cargo.toml` exists | Rust |
| `go.mod` exists | Go |
| Multiple detected | List all (e.g., "Python + JavaScript/TypeScript") |

### Framework
| Check | Result |
|-------|--------|
| `next` in package.json dependencies | Next.js |
| `fastapi` in requirements.txt or pyproject.toml | FastAPI |
| `django` in requirements.txt or pyproject.toml | Django |
| `express` in package.json dependencies | Express |
| `react` in package.json (no next) | React |
| `vue` in package.json | Vue |
| `flask` in requirements.txt | Flask |

### Test Runner
| Check | Result | Command |
|-------|--------|---------|
| `vitest.config.*` exists | vitest | `npx vitest run` |
| `jest.config.*` exists | jest | `npx jest` |
| `pytest.ini` OR `[tool.pytest]` in pyproject.toml | pytest | `python -m pytest` |
| `Makefile` with `test` target | make | `make test` |
| `Cargo.toml` | cargo | `cargo test` |
| `go.mod` | go | `go test ./...` |

### Linter
| Check | Result | Command |
|-------|--------|---------|
| `.eslintrc*` exists | ESLint | `npx eslint .` |
| `ruff.toml` OR `[tool.ruff]` in pyproject.toml | Ruff | `ruff check .` |
| `.golangci.yml` exists | golangci-lint | `golangci-lint run` |

### Package Manager
| Check | Result |
|-------|--------|
| `pnpm-lock.yaml` exists | pnpm |
| `yarn.lock` exists | yarn |
| `package-lock.json` exists | npm |
| `poetry.lock` exists | poetry |
| `uv.lock` exists | uv |

### CI
| Check | Result |
|-------|--------|
| `.github/workflows/*.yml` exists | GitHub Actions |
| `.gitlab-ci.yml` exists | GitLab CI |
| `Jenkinsfile` exists | Jenkins |

---

## Phase 3 — State Initialization

1. Create `.workflow/` directory if it doesn't exist.

2. **Add `.workflow/` to `.gitignore`**: Check if `.gitignore` exists and contains `.workflow/`. If not, append it:
   ```
   # Dev-cycle workflow artifacts
   .workflow/
   ```

3. Create `.workflow/state.json`:
   ```json
   {
     "status": "running",
     "cycle": 0,
     "started_at": "<ISO timestamp>",
     "project_profile": {
       "language": "<detected>",
       "framework": "<detected>",
       "test_runner": "<detected>",
       "test_command": "<detected>",
       "linter": "<detected>",
       "lint_command": "<detected>",
       "package_manager": "<detected>",
       "ci": "<detected>",
       "default_branch": "<detected>",
       "has_frontend": true/false
     },
     "cycle_history": []
   }
   ```

4. Create `.workflow/history/` directory.

5. Display the detected profile to the user:
   > **Dev Cycle initialized!**
   >
   > | Setting | Value |
   > |---------|-------|
   > | Language | ... |
   > | Framework | ... |
   > | Test Runner | ... |
   > | Linter | ... |
   > | Package Manager | ... |
   > | CI | ... |
   > | Default Branch | ... |
   >
   > Starting continuous improvement loop. Use `/dev-cycle:stop` to end.

---

## Phase 4 — Continuous Loop

**Maximum cycles**: 5 per session (safety cap). After 5 cycles, stop automatically and report. The user can restart with `/dev-cycle:start` if they want more.

Execute cycles in a loop:

1. Increment `cycle` in state.json.
2. **Check cycle cap**: if `cycle` > 5, stop:
   > **Cycle cap reached (5 cycles).** Stopping to let you review accumulated PRs. Run `/dev-cycle:start` to continue.
   Set status to "stopped" and print final report.
3. **Execute the cycle logic** — follow the exact same process defined in the `cycle` skill (SKILL.md in `skills/cycle/`). Do NOT invoke the cycle skill as a sub-skill — execute its logic inline.
4. After cycle completes, read `.workflow/state.json`:
   - If `status` is `"stopped"` → print final report and end.
   - If the cycle had any **P0 tasks** → ask user: "This cycle included P0 (critical) tasks. Review the PRs and confirm before continuing to the next cycle." Wait for approval.
   - If `status` is `"running"` and no P0 gate → proceed to next cycle.

### P0 Gate
When a cycle contains P0 tasks, pause and display:
> **P0 Gate**: Cycle {N} included critical fixes. Please review before continuing:
> - {P0 task title} → PR #{number}
>
> Continue to next cycle? (y/n)

If user says no, set status to "stopped".

---

## Error Handling

| Scenario | Action |
|----------|--------|
| Not a git repo | Stop with instructions |
| `gh` not authenticated | Stop with `gh auth login` instructions |
| Zero findings in a cycle | End cycle: "Codebase is in good shape. Stopping." Set status to stopped. |
| Broken CI on default branch | Pause, offer to investigate, alert user |
| State file corrupted | Re-create with safe defaults, warn user |

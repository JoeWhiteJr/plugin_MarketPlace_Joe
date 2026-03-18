---
name: save
description: "Save current session context to a handoff file for seamless continuation in a new terminal."
user_invocable: true
arguments: "[name] — optional name for the handoff; defaults to branch name or timestamp"
---

# /session-handoff:save

Save structured session context so another Claude Code terminal can pick up where you left off.

Use the context-summarizer agent guidelines (defined in `agents/context-summarizer.md`) to produce the summary.

---

## Phase 1 — Determine Handoff Name

1. If `$ARGUMENTS` is non-empty, use the first argument as the handoff name.
2. Otherwise, use the current git branch name (replace `/` with `-`).
3. If not in a git repo, use a timestamp: `handoff-YYYYMMDD-HHmmss`.
4. Sanitize the name: lowercase, replace spaces and special characters with `-`, max 64 characters.

**Name collision handling**: If `.handoff/<name>.md` already exists:
- Try `<name>-2`, `<name>-3`, etc. up to `-9`
- If all taken, abort and ask the user to choose a different name

---

## Phase 2 — Gather Context

Run these in parallel where possible:

1. **Git state**:
   - Current branch: `git branch --show-current`
   - Default branch: check for `main` or `master`
   - Working tree status: `git status --short`
   - Recent commits (last 5): `git log --oneline -5`
   - Changed files vs default branch: `git diff --name-only <default-branch>...HEAD`

2. **Session context** — reflect on the current conversation to identify:
   - What work was done this session
   - Key decisions and their rationale
   - Current state (working, broken, partially working)
   - Prioritized next steps
   - Critical files touched or referenced
   - Gotchas, warnings, or non-obvious constraints

> **Security check**: Before writing, scan your summary for secrets (API keys, tokens, passwords, patterns like `sk-`, `AKIA`, `ghp_`, `Bearer`). Strip any found.

---

## Phase 3 — Write Handoff File

1. Create `.handoff/` directory if it doesn't exist:
   ```bash
   mkdir -p .handoff
   ```

2. Add `.handoff/` to `.gitignore` if not already present:
   - Read `.gitignore` (create if missing)
   - If `.handoff/` is not listed, append it on a new line

3. Write the handoff file to `.handoff/<name>.md` using the format from the context-summarizer agent:

```markdown
# Session Handoff: <name>
> Saved: <ISO 8601 timestamp>

## Git State
- **Branch**: <branch>
- **Default branch**: <main/master>
- **Status**: <clean / modified files summary>
- **Recent commits**:
  - `<hash>` <message>

## Work Done
<bullet list with file references>

## Key Decisions
<numbered list with rationale>

## Current State
**Status**: Working / Broken / Partially Working

<description>

## Next Steps
1. <priority-ordered actions>

## Critical Files
| File | Role | Notes |
|------|------|-------|
| `path` | role | notes |

## Gotchas & Warnings
- <warnings for next session>
```

---

## Phase 4 — Confirm

Report to the user:
- Handoff saved to `.handoff/<name>.md`
- Number of next steps captured
- Suggest: `Run /session-handoff:load <name> in your next terminal to continue`

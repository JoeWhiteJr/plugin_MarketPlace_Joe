---
name: ship
description: Rebase onto main, run tests, commit changes, push, and create a PR. The full "done coding → PR ready" workflow.
disable-model-invocation: true
---

# Ship Workflow

You are executing the `ship` skill — a structured workflow that takes the current feature branch from "done coding" to "PR ready". Follow every phase in order. Stop and report to the user if any phase fails irrecoverably.

If the user provided arguments via `$ARGUMENTS`, treat that as the commit message. Otherwise, generate one from the staged changes.

---

## Phase 1 — Pre-flight Checks

1. Run `git branch --show-current` to get the current branch name. Store it as `BRANCH`.
2. Run `git remote show origin | grep 'HEAD branch'` to detect the default branch (usually `main` or `master`). Store it as `DEFAULT`.
3. **Guard: on default branch** — If `BRANCH` equals `DEFAULT`, stop immediately:
   > You're on `<DEFAULT>`. Create a feature branch first: `git checkout -b my-feature`
4. Run `git status --porcelain` to check for changes (staged, unstaged, or untracked).
5. **Guard: no changes** — If the working tree is clean AND there are no new commits ahead of `origin/<DEFAULT>`, stop:
   > No changes to ship. Make some changes first, then run `/git-workflow:ship` again.
6. Verify the remote exists: `git ls-remote --exit-code origin` (if this fails, stop and tell the user to add a remote).

---

## Phase 2 — Rebase onto Default Branch

1. Run `git fetch origin <DEFAULT>`.
2. Run `git rebase origin/<DEFAULT>`.
3. If the rebase succeeds with no conflicts, move to Phase 3.
4. If conflicts occur:
   a. Use the rebase-resolver agent (defined in `agents/rebase-resolver.md`) to resolve them. The agent will read conflict markers, understand both sides, edit files to resolve, and `git add` each resolved file.
   b. After resolution, run `git rebase --continue`.
   c. If more conflicts appear, repeat up to **3 total attempts**.
   d. If still unresolved after 3 attempts, run `git rebase --abort` and stop:
      > Rebase failed after 3 conflict-resolution attempts. Resolve manually, then re-run `/git-workflow:ship`.

---

## Phase 3 — Run Tests

Auto-detect the test runner by checking these files in order:

| File | Command |
|------|---------|
| `package.json` (with a `"test"` script) | `npm test` |
| `Makefile` (with a `test` target) | `make test` |
| `pytest.ini`, `pyproject.toml`, or `setup.cfg` with pytest config | `pytest` |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |

- If **no test runner** is detected, skip with a note:
  > No test runner found — skipping tests. Consider adding tests before merging.
- If tests **fail**:
  1. Analyze the failure output and attempt to fix the failing code.
  2. Re-run tests.
  3. If tests fail a **second time**, stop and report:
     > Tests are failing after rebase. Review the failures above, fix them, then re-run `/git-workflow:ship`.

---

## Phase 4 — Commit

1. Run `git add -A` to stage all changes (new, modified, deleted).
2. Determine the commit message:
   - If `$ARGUMENTS` is non-empty, use it as the commit message.
   - Otherwise, run `git diff --cached --stat` and `git diff --cached` to inspect staged changes, then generate a concise, conventional-commit-style message summarizing what changed and why.
3. Commit with the message. Include the co-author trailer:
   ```
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
4. If there is nothing new to commit (e.g., all changes were already committed before the rebase), skip this phase with a note:
   > All changes already committed — skipping commit phase.

---

## Phase 5 — Push and Create PR

1. Run `git push -u origin <BRANCH>`.
   - If push is **rejected** (e.g., diverged history after rebase), retry with `git push --force-with-lease -u origin <BRANCH>`.
2. Check for an existing PR: `gh pr view <BRANCH> --json url 2>/dev/null`.
   - If a PR already exists, report its URL and stop:
     > PR already exists: `<URL>`. Push complete — your PR has been updated.
3. If no PR exists, create one:
   ```
   gh pr create --fill --head <BRANCH> --base <DEFAULT>
   ```
   Use `--fill` to auto-populate the title and body from commit messages. If `--fill` produces a poor title, override it with a clear one derived from the branch name or commit message.
4. Report the new PR URL to the user:
   > PR created: `<URL>`

**This is the final step.** Do NOT merge the PR. The user will review, get CI results, and merge when ready.

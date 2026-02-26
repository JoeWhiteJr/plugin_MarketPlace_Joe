---
name: cleanup
description: Post-merge branch cleanup — delete the local and remote feature branch after a PR has been merged.
disable-model-invocation: true
---

# Cleanup Workflow

You are executing the `cleanup` skill. This runs **after** a PR has been reviewed, CI has passed, and the PR has been merged. It removes the now-stale feature branch locally and remotely.

---

## Step 1 — Identify Current Branch

1. Run `git branch --show-current` to get the current branch. Store it as `BRANCH`.
2. Run `git remote show origin | grep 'HEAD branch'` to detect the default branch. Store it as `DEFAULT`.
3. If `BRANCH` equals `DEFAULT`, check if `$ARGUMENTS` names a branch to clean up. If not, stop:
   > You're on `<DEFAULT>`. Either switch to the feature branch first, or run `/git-workflow:cleanup <branch-name>`.

If `$ARGUMENTS` is provided and names a branch, use that as `BRANCH` instead.

---

## Step 2 — Verify PR Was Merged

1. Run `gh pr view <BRANCH> --json state,mergedAt,statusCheckRollup`.
2. If the PR state is `MERGED`, continue.
3. If the PR state is `OPEN`:
   - Check `statusCheckRollup` for CI status.
   - If CI is still running, stop:
     > PR is still open and CI is running. Wait for CI to pass and merge the PR first.
   - If CI failed, stop:
     > PR is still open and CI has failed. Fix the failures before merging.
   - If CI passed but PR is not merged, stop:
     > PR is open and CI has passed, but the PR hasn't been merged yet. Merge it first, then run cleanup.
4. If no PR is found for this branch, warn but continue:
   > No PR found for branch `<BRANCH>`. Proceeding with branch cleanup anyway.

---

## Step 3 — Switch to Default Branch and Pull

1. Run `git checkout <DEFAULT>`.
2. Run `git pull origin <DEFAULT>`.

---

## Step 4 — Delete Branch

1. Delete the local branch: `git branch -d <BRANCH>`.
   - If `-d` fails (unmerged warning), use `git branch -D <BRANCH>` since we verified the PR was merged.
2. Delete the remote branch: `git push origin --delete <BRANCH>`.
   - If this fails because the branch was already deleted remotely (e.g., GitHub auto-delete), that's fine — report:
     > Remote branch already deleted (likely by GitHub auto-delete).
3. Prune stale remote-tracking refs: `git remote prune origin`.

---

## Step 5 — Report

> Cleanup complete. Branch `<BRANCH>` has been deleted locally and remotely. You're now on `<DEFAULT>` with the latest changes.

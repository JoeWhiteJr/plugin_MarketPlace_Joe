---
name: reconcile
description: Report-only audit of ticket drift — stale in-progress tickets, PR-merged tickets not moved to done, missing closed dates, orphan commits/branches. Never modifies or deletes files without explicit user consent.
disable-model-invocation: true
---

# Reconcile Tickets

You are executing the `reconcile` skill — auditing ticket state for drift between what the tickets claim and what the git/PR state actually shows.

**This skill is read-only.** It never moves files, never modifies frontmatter, never deletes tickets. It produces a report. The user decides what to act on.

`$ARGUMENTS` is an optional scope filter — currently ignored (reserved for future: `stale`, `merged`, `orphan` subsets). Always run the full audit.

---

## Phase 1 — Locate Repo and Tickets

1. Get `ROOT` via `git rev-parse --show-toplevel`. If not a git repo, stop:
   > Reconcile requires a git repo (it cross-references tickets with commits and PRs). Run this from inside a repo with ticketing initialized.

2. Verify `<ROOT>/docs/tickets/.config.json` exists. If not, stop:
   > Ticketing isn't initialized in this repo. Run `/ticketing:init` first.

3. Read the prefix from `.config.json`. Store as `PREFIX`.

4. Glob all ticket files:
   - `OPEN_FILES` = `<ROOT>/docs/tickets/open/*.md`
   - `PROG_FILES` = `<ROOT>/docs/tickets/in-progress/*.md`
   - `DONE_FILES` = `<ROOT>/docs/tickets/done/*.md`
   - Exclude INDEX.md and README.md.

5. Parse YAML frontmatter from each file: `id`, `title`, `status`, `priority`, `owner`, `created`, `updated`, `closed`, `related-pr`, `related-tickets`.

---

## Phase 2 — Check 1: Stale In-Progress Tickets

For each ticket in `PROG_FILES`:

1. Read the `updated:` field. If missing, fall back to `created:`. If both missing, fall back to file mtime via `ls -la`.
2. Compute days since that date.
3. If days ≥ 7, flag as **stale**.
4. If days ≥ 30, additionally mark as **candidate for archive** (but do NOT archive — per user policy, always advise).

Collect into `STALE_IN_PROGRESS[]` with: ID, title, last-update date, days-since, age-bucket (7-14d, 14-30d, 30+).

---

## Phase 3 — Check 2: Tickets with Merged PRs Still in Open/In-Progress

For each ticket in `OPEN_FILES` + `PROG_FILES`:

1. If `related-pr:` is empty, skip.
2. Parse the PR number from the value. Supported formats:
   - `#42`
   - `https://github.com/owner/repo/pull/42`
   - Just a number: `42`
3. Query `gh pr view <num> --json state,mergedAt,url 2>/dev/null`.
4. If the PR state is `MERGED`, flag as **should-be-done**.
5. If `gh` fails (no auth, offline, PR not in this repo), skip silently — this is an advisory check, not blocking.

Collect into `SHOULD_BE_DONE[]` with: ID, title, current state (open/in-progress), PR URL, merged date.

---

## Phase 4 — Check 3: Done Tickets Missing `closed:` Date

For each ticket in `DONE_FILES`:

1. If `closed:` field is missing or empty, flag as **needs-closed-date**.

Collect into `MISSING_CLOSED[]` with: ID, title, created date, file path.

---

## Phase 5 — Check 4: Orphan Commits (Ticket IDs in Git History Without Matching Tickets)

1. Run `git log --oneline -n 200 --since="30 days ago"` to get recent commit messages.
2. Regex-scan each commit message for ticket ID pattern: `<PREFIX>-T\d{3}` (e.g., `SSS-T001`).
3. Collect all referenced ticket IDs into `REFERENCED_IDS[]`.
4. Build the set of all existing ticket IDs from the parsed frontmatter.
5. Any ID in `REFERENCED_IDS` that is NOT in the existing set is an **orphan reference** (ticket deleted after being referenced, or typo).

Collect into `ORPHAN_COMMITS[]` with: commit SHA, commit subject, referenced ticket ID.

---

## Phase 6 — Check 5: Feature Branches Without Ticket References

1. Run `git branch -r --list 'origin/feature/*' 'origin/fix/*' 'origin/hotfix/*' 2>/dev/null` to list remote feature-style branches. Also check local: `git branch --list 'feature/*' 'fix/*' 'hotfix/*'`.
2. For each branch, check if it has been active in the last 14 days: `git log -1 --format=%cr origin/<branch>`. Skip branches older than 14 days (likely stale/abandoned, separate problem).
3. For each active branch, check if any commit on that branch (compared to main) references a ticket ID: `git log main..<branch> --oneline | grep -oE '<PREFIX>-T\d{3}'`.
4. If no ticket ID found, flag as **unlinked-branch**.

Collect into `UNLINKED_BRANCHES[]` with: branch name, last commit date, last commit subject.

Skip this check entirely if `gh`/`git` queries fail — it's advisory.

---

## Phase 7 — Check 6: Archive Candidates (Advisory Only — Never Auto-Delete)

For each ticket in `OPEN_FILES`:

1. Compute days since `updated:` (or `created:` fallback).
2. If days ≥ 60 AND `related-pr:` is empty AND priority is `low` or missing:
   - Flag as **archive-candidate**.

Collect into `ARCHIVE_CANDIDATES[]` with: ID, title, created date, days-stale.

---

## Phase 8 — Generate the Report

Write the report to the user **in the chat response** (not to a file — the user decides what to act on).

Structure:

```
# Reconcile Report — <REPO_NAME>

_Generated: <today ISO> — read-only audit, no files modified_

## Summary
| Check | Count | Severity |
|-------|-------|----------|
| Stale in-progress (≥7 days) | {N} | ⚠️ |
| PR-merged but not in done/ | {N} | 🔴 |
| Done tickets missing closed date | {N} | 🧹 |
| Orphan commit references | {N} | ⚠️ |
| Active branches without ticket | {N} | ⚠️ |
| Archive candidates (60+ days) | {N} | 💬 |

---

## 🔴 Action needed: PR merged but ticket not in done/

_These tickets reference a PR that's already been merged. Suggested: run `/ticketing:move <ID> done`._

| ID | Title | Current State | PR | Merged |
|----|-------|---------------|-----|--------|
| SSS-T001 | ... | in-progress | #42 | 2026-04-08 |

## ⚠️ Stale in-progress tickets

_In-progress > 7 days without update. Suggested: finish, move back to open, or add a status note._

| ID | Title | Days stale | Bucket |
|----|-------|------------|--------|
| SSS-T003 | ... | 12 | 7-14d |

## 🧹 Done tickets missing closed date

_Data-quality issue — suggested: edit frontmatter to add `closed: YYYY-MM-DD`._

| ID | Title | Created |
|----|-------|---------|
| SSS-T001 | ... | 2026-03-15 |

## ⚠️ Orphan commit references

_Commits mention these ticket IDs but no ticket file exists. Possible causes: ticket deleted, typo, or ticket never created._

| Commit | Subject | Referenced ID |
|--------|---------|---------------|
| a1b2c3d | fix: resolve rate limit | SSS-T099 |

## ⚠️ Active branches without ticket reference

_Active feature branches that don't reference a ticket ID in their commit messages. Suggested: create a ticket to track this work, or add the ID to the next commit._

| Branch | Last Activity | Last Commit |
|--------|---------------|-------------|
| feature/xyz | 3 days ago | refactor: cleanup |

## 💬 Archive candidates (advisory — NOT auto-archiving)

_Open tickets with no activity in 60+ days, no related PR, low/missing priority. Consider: still relevant? Delete? Bump priority?_

| ID | Title | Days since update | Priority |
|----|-------|-------------------|----------|
| SSS-T042 | ... | 87 | (none) |

---

## Next steps

Run `/ticketing:move <ID> <state>` for the specific tickets you want to transition. Reconcile will not modify any files on its own.

For the orphan commits and unlinked branches, decide case-by-case whether to create tickets retroactively.

For archive candidates, **this tool will never auto-delete** — if you decide to remove a ticket, do so manually via `git rm docs/tickets/open/<file>.md` and commit.
```

**Rendering rules:**
- Omit any section where the count is zero (don't print empty tables).
- If ALL counts are zero, print:
  > ✅ **No drift detected.** All tickets are up to date, all merged PRs are reflected, no orphan references, no stale branches. Nice.
- Always include the Summary table — even if all zeros — so the user knows the checks ran.
- Keep the report under 800 lines even for noisy repos (truncate tables at 20 rows with "... and N more" footer).

---

## Phase 9 — Post-Report

Do NOT modify any files. Do NOT move any tickets. Do NOT update any frontmatter.

If the user wants to act on findings, they invoke the individual skills (`/ticketing:move`, etc.) on the specific tickets.

The skill ends here.

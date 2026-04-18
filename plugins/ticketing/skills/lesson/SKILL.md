---
name: lesson
description: Create a new post-mortem / lessons-learned document in docs/lessons/ with today's date and regenerate the lessons index.
disable-model-invocation: true
---

# New Lesson / Post-Mortem

You are executing the `lesson` skill — creating a new post-mortem or lessons-learned document in `docs/lessons/`.

`$ARGUMENTS` is the lesson **title** (required). If empty, stop and report:
> Usage: `/ticketing:lesson "Rate-limit outage 2026-04-10"`

Lesson files are dated by filename (`YYYY-MM-DD-<slug>.md`) and kept in reverse chronological order in the index.

---

## Phase 1 — Locate Repo and Directory

1. Get `ROOT` via `git rev-parse --show-toplevel` (fallback to cwd).
2. Ensure `<ROOT>/docs/lessons/` exists (create with `mkdir -p` if not — lessons are self-contained like ADRs).

---

## Phase 2 — Build Filename

1. Get today's ISO date: `YYYY-MM-DD`. Store as `DATE`.
2. Slugify the title (same rules as other skills — lowercase, non-alphanum → `-`, strip, truncate to 40 chars).
3. Filename: `<DATE>-<SLUG>.md`, e.g., `2026-04-17-rate-limit-outage.md`.
4. Target path: `<ROOT>/docs/lessons/<filename>`.
5. Guard: if the file already exists, append a counter suffix: `<DATE>-<SLUG>-2.md`, `-3.md`, etc., until unique. This lets you log multiple lessons per day without collision.

---

## Phase 3 — Write Lesson from Template

Use the inline template below. Substitute:
- `{{date}}` → `DATE`
- `{{title}}` → raw title

Write the substituted content to the target path with the Write tool.

**Template:**

```markdown
---
date: {{date}}
title: {{title}}
severity: medium
tags:
---

# {{title}}

## Summary
_One paragraph: what happened, what was the impact._

## Timeline
- **{{date}} HH:MM** — Event

## Root Cause
_The actual underlying cause. Go 5-whys deep if needed._

## Impact
_Who/what was affected? Duration? Scope?_

## What We Changed
_Immediate fixes applied._

## How to Prevent Recurrence
_Systemic changes. Hooks, tests, process changes._

## Action Items
- [ ] Action 1 (owner, due date)
- [ ] Action 2

## Lessons
_Broader takeaways for future work._
```

**Per-repo override:** If `<ROOT>/docs/lessons/.templates/lesson.md.template` exists, read that file instead and use it as the template. Otherwise use the inline version above.

---

## Phase 4 — Regenerate docs/lessons/INDEX.md

Write `<ROOT>/docs/lessons/INDEX.md` with this structure:

```
# Lessons Learned

_Last updated: <today ISO date>_

| Date | Title | Severity | Tags |
|------|-------|----------|------|
| [2026-04-17](2026-04-17-rate-limit-outage.md) | Rate-limit outage | high | infra, rate-limit |
| [2026-04-10](2026-04-10-...) | ... | ... | ... |
```

To populate:
1. Glob `<ROOT>/docs/lessons/*.md` (exclude INDEX.md).
2. For each, read and parse YAML frontmatter: `date`, `title`, `severity`, `tags`.
3. Fall back to:
   - `date` from the leading `YYYY-MM-DD` of the filename if the frontmatter field is missing.
   - `title` from the first `# ` heading.
4. Sort by date **descending** (most recent first).
5. Render `tags` as a comma-separated string. If empty or missing, use `—`.
6. Render any missing field as `—`.

---

## Phase 5 — Report

> **Lesson logged: `<filename>`**
>
> - **Title:** `<title>`
> - **Date:** `<DATE>`
> - **Path:** `docs/lessons/<filename>`
>
> **Next:** open the file and fill in:
> - **Summary** — what happened, impact
> - **Timeline** — sequence of events with timestamps
> - **Root Cause** — 5-whys deep
> - **What We Changed** — immediate fixes
> - **How to Prevent Recurrence** — systemic changes, hooks, tests
> - **Action Items** — with owners and due dates

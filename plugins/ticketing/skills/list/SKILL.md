---
name: list
description: List tickets by state and regenerate docs/tickets/INDEX.md with live tables of open, in-progress, and done tickets.
disable-model-invocation: true
---

# List Tickets

You are executing the `list` skill — scanning `docs/tickets/` for ticket files, parsing their frontmatter, regenerating `INDEX.md`, and showing a summary.

`$ARGUMENTS` is an optional state filter for the chat display:
- `open`, `in-progress`, `done`, `all` (default)
- Aliases are normalized the same way as in `/ticketing:move`.

INDEX.md always includes all three states regardless of the filter — the filter only affects what you print in chat.

---

## Phase 1 — Locate Tickets

1. Get `ROOT` via `git rev-parse --show-toplevel` (fallback to cwd).
2. Verify `<ROOT>/docs/tickets/.config.json` exists. If not, stop:
   > Ticketing isn't initialized. Run `/ticketing:init` first.
3. Glob each state directory separately (use the Glob tool):
   - `OPEN_FILES` = `<ROOT>/docs/tickets/open/*.md`
   - `PROG_FILES` = `<ROOT>/docs/tickets/in-progress/*.md`
   - `DONE_FILES` = `<ROOT>/docs/tickets/done/*.md`
4. Exclude any `INDEX.md` or `README.md` that happen to match.

---

## Phase 2 — Parse Frontmatter

For each ticket file, read the YAML frontmatter block between `---` markers and extract these fields (all optional except `id` and `title`):

- `id` — e.g., `SSS-T001`
- `title`
- `priority` — `low`, `medium`, `high`, `critical`
- `owner`
- `type`
- `created` — ISO date
- `updated` — ISO date
- `closed` — ISO date (only on done tickets)

If a field is missing, render it as an em-dash `—` in the tables.

Handle malformed frontmatter gracefully — log a warning in the chat report but don't fail the whole skill. Skip the bad file in the tables.

---

## Phase 3 — Regenerate INDEX.md

Write `<ROOT>/docs/tickets/INDEX.md` with this exact structure:

```
# Tickets Index

_Last updated: <today ISO date>_

## Open (<N>)

| ID | Title | Priority | Owner | Created |
|----|-------|----------|-------|---------|
| [<id>](open/<filename>) | <title> | <priority> | <owner> | <created> |
...

## In Progress (<N>)

| ID | Title | Priority | Owner | Created |
|----|-------|----------|-------|---------|
| [<id>](in-progress/<filename>) | <title> | <priority> | <owner> | <created> |
...

## Done (<N>) — last 10

| ID | Title | Priority | Owner | Closed |
|----|-------|----------|-------|--------|
| [<id>](done/<filename>) | <title> | <priority> | <owner> | <closed> |
...
```

Rules:
- Counts `(<N>)` reflect the **total** per state, not the table row count (important for the Done section, which is capped at 10).
- Sort **Open** and **In Progress** by priority descending (critical → high → medium → low), then by `created` ascending (oldest first).
- Sort **Done** by `closed` descending (most recent first), then truncate to 10.
- If a state has zero tickets, render an italic line instead of a table: `_No tickets in this state._`
- Title column: escape any `|` characters in titles as `\|` to avoid breaking the table. Also collapse newlines to spaces.
- Link paths are relative to `docs/tickets/` (the INDEX.md location).

---

## Phase 4 — Chat Summary

Print a concise summary to the user based on `$ARGUMENTS`:

**Always include the counts header:**
> **Tickets: <open-count> open, <prog-count> in-progress, <done-count> done**

**If `$ARGUMENTS` is `all` or empty:**
- Show the open + in-progress tables inline (skip done to keep chat output short, since INDEX.md has the full list).
- If any open ticket has `priority: high` or `critical`, call them out:
  > **High-priority open:** `<id>` — <title>

**If `$ARGUMENTS` is a specific state:**
- Show only that state's table inline.

**Always end with:**
> Full index: `docs/tickets/INDEX.md`

---

## Phase 5 — Done

No file moves, no config changes. This skill is purely read + regenerate INDEX.md.

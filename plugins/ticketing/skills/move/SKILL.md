---
name: move
description: Move a ticket between states (open → in-progress → done), updating the status frontmatter field and regenerating INDEX.md.
disable-model-invocation: true
---

# Move Ticket

You are executing the `move` skill — transitioning a ticket file between the state directories `open/`, `in-progress/`, and `done/`.

`$ARGUMENTS` must contain two tokens: `<ID> <STATE>`, e.g., `SSS-T001 in-progress`. If `$ARGUMENTS` is missing or malformed, stop and report:
> Usage: `/ticketing:move <ID> <state>`
> Valid states: `open`, `in-progress`, `done`.

---

## Phase 1 — Parse Arguments

1. Split `$ARGUMENTS` on whitespace. First token = `ID`, second token = `STATE_RAW`.
2. Normalize `STATE_RAW` to one of `open`, `in-progress`, `done`:
   - Lowercase it.
   - Map aliases: `in_progress`, `inprogress`, `wip`, `progress`, `in-prog` → `in-progress`.
   - Map aliases: `closed`, `complete`, `completed`, `finished`, `close` → `done`.
   - Map aliases: `todo`, `new`, `backlog`, `reopen` → `open`.
3. Store as `NEW_STATE`. If it's not one of the three valid states, stop and report the valid options.

---

## Phase 2 — Locate the Ticket File

1. Get `ROOT` via `git rev-parse --show-toplevel` (fallback to cwd).
2. Search across all three state directories for a file matching `<ID>-*.md`:
   - `<ROOT>/docs/tickets/open/<ID>-*.md`
   - `<ROOT>/docs/tickets/in-progress/<ID>-*.md`
   - `<ROOT>/docs/tickets/done/<ID>-*.md`
3. Use the Glob tool. If no file matches, stop and report:
   > No ticket found with ID `<ID>`. Run `/ticketing:list` to see all tickets.
4. If multiple files match (shouldn't happen — IDs are unique), report all paths and ask the user which to move.
5. Store the found file as `OLD_PATH` and note its current state directory as `OLD_STATE`.

---

## Phase 3 — Idempotency Check

If `OLD_STATE == NEW_STATE`, report:
> Ticket `<ID>` is already in `<NEW_STATE>`. No move needed.

Still regenerate INDEX.md (Phase 6) in case frontmatter drifted — but skip the file move and frontmatter rewrite.

---

## Phase 4 — Update Frontmatter

1. Read `OLD_PATH` with the Read tool.
2. The file starts with a YAML frontmatter block between `---` markers. Parse it, preserving **all** existing fields and their order.
3. Set `status: <NEW_STATE>`.
4. Set `updated: <today's ISO date>`.
5. If `NEW_STATE == done`:
   - Add or update `closed: <today's ISO date>`.
6. If `NEW_STATE != done` and `closed:` exists, leave it — it's fine to have a closed date on a reopened ticket; the status field is authoritative. (Optionally clear it if you prefer a clean state — but do NOT silently drop other fields.)
7. Serialize the frontmatter back in the same order, followed by the rest of the file content (unchanged).

---

## Phase 5 — Move the File

1. New path: `<ROOT>/docs/tickets/<NEW_STATE>/<basename of OLD_PATH>`.
2. Guard: if the new path already exists and is different from `OLD_PATH`, stop and report the conflict. This should not happen for unique IDs.
3. Write the updated content (from Phase 4) to the **new path** using the Write tool.
4. Delete the old file using the Bash tool: `rm <OLD_PATH>`.

Rationale for write-then-delete (instead of `git mv`): keeps this skill decoupled from git and avoids issues when working on staged changes. Git will see it as a rename automatically.

---

## Phase 6 — Regenerate INDEX.md

Run the INDEX.md regeneration logic (same as `/ticketing:list`): glob all tickets across the 3 state dirs, parse frontmatter, rewrite INDEX.md with 3 tables.

---

## Phase 7 — Report

> **Ticket moved: `<ID>`**
>
> - **Title:** `<title>`
> - **Old:** `docs/tickets/<OLD_STATE>/<filename>`
> - **New:** `docs/tickets/<NEW_STATE>/<filename>`
> - **Status:** `<OLD_STATE>` → `<NEW_STATE>`
> <if done:> - **Closed:** `<today>`
>
> INDEX.md regenerated.

---
name: init
description: Initialize a file-based ticketing system in the current repo — creates docs/tickets/, docs/decisions/, docs/lessons/, derives an ID prefix, and writes config + README.
disable-model-invocation: true
---

# Ticketing Init

You are executing the `init` skill — scaffolding a file-based ticketing, ADR, and post-mortem system in the current repository.

If the user provided arguments via `$ARGUMENTS`, treat the first whitespace-delimited token as an explicit ticket ID prefix (uppercase letters/digits, typically 2-5 chars). Otherwise derive one from the repo name.

This skill is **idempotent**: running it a second time must not overwrite existing content. If `docs/tickets/.config.json` already exists, report "already initialized" and exit cleanly.

---

## Phase 1 — Detect Repo Root and Name

1. Try `git rev-parse --show-toplevel` to get the repo root. Store it as `ROOT`.
2. If the command fails (not a git repo), fall back to the current working directory (`pwd`) as `ROOT`, and warn the user:
   > Not a git repository — using `<ROOT>` as the repo root. Ticket filenames will still work, but you won't get a nice auto-detected repo name.
3. Derive `REPO_NAME`:
   - If git is available, use the basename of `ROOT`.
   - Otherwise, ask the user for a repo name via `$ARGUMENTS` (second token) or default to the basename of `ROOT`.

All paths in subsequent phases are relative to `ROOT`. Always use absolute paths when calling Write/Read/Bash tools.

---

## Phase 2 — Derive Ticket ID Prefix

If `$ARGUMENTS` contains an explicit prefix (a whitespace-delimited token matching `^[A-Z0-9]{2,6}$`), use it directly as `PREFIX`. Otherwise derive from `REPO_NAME`:

1. Split `REPO_NAME` on any of: `-`, `_`, `.`, space, or CamelCase boundary (a lowercase→uppercase transition).
2. Take the first letter of each non-empty part, uppercased.
3. If that produces only 1 character (single-word repo), use the first **two** letters of the word, uppercased (e.g., `LevelUp` → `LU` via CamelCase; `mkrepo` → `MK`).
4. Truncate to 5 characters max.

Examples to verify your logic against:
- `Special-Sprinkle-Sauce` → `SSS`
- `MK_Labs` → `MKL`
- `plugin_MarketPlace_Joe` → `PMJ` (plugin, MarketPlace, Joe — note CamelCase split makes "M" the start of MarketPlace)
- `LevelUp` → `LU`
- `my-app` → `MA`

Report the derived prefix and ask for confirmation only if it looks ambiguous (e.g., single-letter result). Otherwise proceed.

---

## Phase 3 — Idempotency Check

1. Check if `<ROOT>/docs/tickets/.config.json` exists.
2. If it exists, read it and report:
   > Ticketing is already initialized in this repo.
   > - Prefix: `<existing_prefix>`
   > - Next ID: `<existing_next_id>`
   > - Config: `<ROOT>/docs/tickets/.config.json`
   >
   > Run `/ticketing:new "Your title"` to create a ticket.

   Then stop. Do not overwrite anything.

---

## Phase 4 — Create Directory Structure

Create these directories (idempotent — `mkdir -p` is safe):

- `<ROOT>/docs/tickets/open/`
- `<ROOT>/docs/tickets/in-progress/`
- `<ROOT>/docs/tickets/done/`
- `<ROOT>/docs/tickets/.drafts/`
- `<ROOT>/docs/decisions/`
- `<ROOT>/docs/lessons/`

Use `mkdir -p` via the Bash tool. Keep the directories empty except for the files in Phase 5.

---

## Phase 5 — Write Config and Starter Files

1. **Write `<ROOT>/docs/tickets/.config.json`** with:
   ```json
   {
     "prefix": "<PREFIX>",
     "next_id": 1,
     "created": "<today ISO date, YYYY-MM-DD>"
   }
   ```

2. **Write `<ROOT>/docs/tickets/README.md`** using the inline template below. Substitute:
   - `{{repo_name}}` → `REPO_NAME`
   - `{{prefix}}` → `PREFIX`

   **README template:**

   ````markdown
   # Tickets — {{repo_name}}

   This repo uses a **file-based ticketing system** managed by the `ticketing` Claude Code plugin. Every ticket is a markdown file with YAML frontmatter. No database, no external service — everything lives in git alongside the code.

   **Ticket ID prefix:** `{{prefix}}` (e.g., `{{prefix}}-T001`, `{{prefix}}-T002`, ...)

   ---

   ## Directory layout

   ```
   docs/
     tickets/
       .config.json        # prefix + next_id (do not hand-edit unless needed)
       README.md           # this file
       INDEX.md            # auto-generated list of all tickets
       open/               # not yet started
       in-progress/        # actively being worked on
       done/               # completed
       .drafts/            # gitignored scratch space (optional)
     decisions/            # Architecture Decision Records (ADRs)
       INDEX.md
       0001-*.md
     lessons/              # Post-mortems / lessons learned
       INDEX.md
       YYYY-MM-DD-*.md
   ```

   ---

   ## The 6 skills

   | Skill | What it does |
   |-------|--------------|
   | `/ticketing:init` | One-time setup: creates directories, config, and index files. |
   | `/ticketing:new "Title"` | Creates a new ticket in `open/` with an auto-incremented ID. |
   | `/ticketing:move <ID> <state>` | Moves a ticket between `open`, `in-progress`, and `done`. |
   | `/ticketing:list [state]` | Regenerates `INDEX.md` and prints a summary. |
   | `/ticketing:adr "Title"` | Creates a new Architecture Decision Record in `docs/decisions/`. |
   | `/ticketing:lesson "Title"` | Creates a new post-mortem / lessons-learned doc in `docs/lessons/`. |

   ### Examples

   ```bash
   # Create a ticket
   /ticketing:new "Add MFA to login flow"
   # → docs/tickets/open/{{prefix}}-T001-add-mfa-to-login-flow.md

   # Start work
   /ticketing:move {{prefix}}-T001 in-progress

   # Finish
   /ticketing:move {{prefix}}-T001 done

   # See everything
   /ticketing:list

   # Log a decision
   /ticketing:adr "Use Postgres for primary store"

   # Log a post-mortem
   /ticketing:lesson "Rate-limit outage 2026-04-10"
   ```

   ---

   ## Workflow

   ```
   open  ──/ticketing:move <ID> in-progress──▶  in-progress  ──/ticketing:move <ID> done──▶  done
   ```

   - **One ticket per file.** Tickets are self-contained — the frontmatter has metadata, the body has the narrative.
   - **Status is the frontmatter `status` field.** The directory (`open/`, `in-progress/`, `done/`) mirrors it — the `move` skill keeps both in sync.
   - **IDs are immutable.** Once a ticket is created as `{{prefix}}-T042`, it keeps that ID forever, even across state changes.

   ---

   ## Frontmatter reference

   Every ticket starts with a YAML block:

   ```yaml
   ---
   id: {{prefix}}-T001              # immutable, auto-generated
   title: Short human title          # required
   status: open                      # open | in-progress | done
   priority: medium                  # low | medium | high | critical
   type: feature                     # feature | bug | chore | research | refactor
   owner: joe                        # who's responsible
   created: 2026-04-17               # auto-set on creation
   updated: 2026-04-17               # auto-bumped on move
   closed: 2026-04-20                # auto-set on move → done
   related-pr: https://...           # optional
   related-tickets: [{{prefix}}-T005] # optional
   ---
   ```

   Edit freely after creation — add custom fields, adjust priority, link related tickets. The `list` skill only reads the fields it knows about and ignores the rest.

   ---

   ## Conventions

   - **Filename:** `<ID>-<slug>.md` — e.g., `{{prefix}}-T001-add-mfa-to-login.md`.
   - **Slug:** lowercase, hyphenated, 40 chars max.
   - **ID format:** `{{prefix}}-T<3-digit-zero-padded>` for tickets, `<4-digit>-<slug>` for ADRs, `YYYY-MM-DD-<slug>` for lessons.
   - **INDEX.md files are auto-generated.** Don't hand-edit — re-run `/ticketing:list` (or the corresponding skill) to refresh.
   - **Commit tickets with the code change** that addresses them. A done ticket should point to the PR that closed it via `related-pr`.

   ---

   ## FAQ

   **Q: Can I rename a ticket after creating it?**
   Yes — edit the `title` field and the filename together, then run `/ticketing:list` to refresh INDEX.md. The ID stays the same.

   **Q: What if two of us create a ticket at the same time?**
   The `next_id` in `.config.json` is not lock-protected. In practice, just resolve the merge conflict by bumping the second ticket's ID and renaming the file. Rare enough not to worry about.

   **Q: How do I reopen a done ticket?**
   `/ticketing:move <ID> open` (or `in-progress`). It moves the file and updates the frontmatter. The `closed` date stays as a historical record.
   ````

3. **Write `<ROOT>/docs/tickets/INDEX.md`** with exactly this content:
   ```
   # Tickets Index

   _No tickets yet. Run `/ticketing:new "Title"` to create one._
   ```

---

## Phase 6 — Update .gitignore

1. Check if `<ROOT>/.gitignore` exists.
2. If it exists, check whether it already contains a line matching `docs/tickets/.drafts/` or `docs/tickets/.drafts`. If not, append:
   ```
   # Ticketing plugin local drafts
   docs/tickets/.drafts/
   ```
3. If `.gitignore` does not exist, skip this phase silently (don't create one).

---

## Phase 7 — Report

Report to the user:

> **Ticketing initialized**
>
> | Field | Value |
> |-------|-------|
> | Repo | `<REPO_NAME>` |
> | Prefix | `<PREFIX>` |
> | Root | `<ROOT>` |
>
> **Created:**
> - `docs/tickets/{open,in-progress,done,.drafts}/`
> - `docs/tickets/.config.json`
> - `docs/tickets/README.md`
> - `docs/tickets/INDEX.md`
> - `docs/decisions/`
> - `docs/lessons/`
>
> **Next steps:**
> - Create your first ticket: `/ticketing:new "Add MFA to login"`
> - Log a decision: `/ticketing:adr "Use Postgres for primary store"`
> - Record a post-mortem: `/ticketing:lesson "Rate-limit outage 2026-04-10"`

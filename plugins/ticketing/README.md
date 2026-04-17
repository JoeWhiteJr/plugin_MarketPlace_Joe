# ticketing

A Claude Code plugin that manages `.md`-based tickets, Architecture Decision Records, and post-mortems — one repo at a time, no database, no external service. Everything lives in git alongside your code.

## What it gives you

Run `/ticketing:init` in any repo and you get:

```
docs/
  tickets/
    .config.json        # prefix + next_id
    README.md           # usage guide (auto-customized with your repo name)
    INDEX.md            # auto-generated table of all tickets
    open/
    in-progress/
    done/
  decisions/            # ADRs (0001-*.md)
  lessons/              # Post-mortems (YYYY-MM-DD-*.md)
```

Ticket IDs are auto-prefixed per repo — e.g., `Special-Sprinkle-Sauce` → `SSS-T001`, `plugin_MarketPlace_Joe` → `PMJ-T001`.

## Skills

### `/ticketing:init`

One-time setup per repo. Creates the directory tree, derives a ticket ID prefix from the repo name, writes `.config.json`, customizes a starter `README.md`, and appends `.drafts/` to `.gitignore`. Idempotent — safe to run twice.

```bash
# Auto-derive prefix from repo name
/ticketing:init

# Or force a custom prefix
/ticketing:init ACME
```

### `/ticketing:new "Title"`

Creates a new ticket in `docs/tickets/open/` with an auto-incremented ID, slugified filename, and frontmatter template.

```bash
/ticketing:new "Add MFA to login flow"
# → docs/tickets/open/SSS-T001-add-mfa-to-login-flow.md
```

### `/ticketing:move <ID> <state>`

Moves a ticket between the three state directories, updating the `status:` frontmatter field. Adds `closed:` on move to done.

```bash
/ticketing:move SSS-T001 in-progress
/ticketing:move SSS-T001 done
```

Accepts aliases: `wip`, `in_progress`, `inprogress` → `in-progress`; `closed`, `complete`, `finished` → `done`.

### `/ticketing:list [state]`

Regenerates `docs/tickets/INDEX.md` with three tables (open, in-progress, done — last 10) and prints a chat summary. Optional state filter limits the chat display.

```bash
/ticketing:list              # all (default)
/ticketing:list open
/ticketing:list in-progress
```

### `/ticketing:adr "Title"`

Creates a new Architecture Decision Record with an auto-incremented 4-digit ID and standard Status/Context/Decision/Consequences sections.

```bash
/ticketing:adr "Use Postgres for primary store"
# → docs/decisions/0001-use-postgres-for-primary-store.md
```

### `/ticketing:lesson "Title"`

Logs a post-mortem / lessons-learned doc dated with today's ISO date. Structured template: Summary, Timeline, Root Cause, Impact, What We Changed, How to Prevent Recurrence, Action Items.

```bash
/ticketing:lesson "Rate-limit outage 2026-04-10"
# → docs/lessons/2026-04-17-rate-limit-outage-2026-04-10.md
```

## Frontmatter reference

```yaml
---
id: SSS-T001              # immutable, auto-generated
title: Short human title
status: open              # open | in-progress | done
priority: medium          # low | medium | high | critical
type: feature             # feature | bug | chore | research | refactor
owner: joe
created: 2026-04-17
updated: 2026-04-17
closed:                   # set on move → done
related-pr:
related-tickets:
---
```

Edit freely after creation — custom fields are preserved by `/ticketing:move` and ignored by `/ticketing:list`.

## Conventions

| Thing | Format | Example |
|-------|--------|---------|
| Ticket ID | `<PREFIX>-T<3-digit>` | `SSS-T042` |
| Ticket filename | `<ID>-<slug>.md` | `SSS-T042-fix-auth-redirect.md` |
| ADR filename | `<4-digit>-<slug>.md` | `0003-use-postgres.md` |
| Lesson filename | `YYYY-MM-DD-<slug>.md` | `2026-04-17-outage.md` |
| Slug | lowercase, hyphens, ≤ 40 chars | `add-mfa-to-login` |
| State dir mirrors `status:` | always kept in sync by `/ticketing:move` | |

## Requirements

- **git** — recent version (used to detect repo root). Not strictly required; the skills fall back to the current working directory if you're not in a git repo.
- No `gh`, no network calls, no external services.

## Edge cases

| Scenario | Behavior |
|----------|----------|
| Re-running `/ticketing:init` | Reports "already initialized" and exits — never overwrites |
| Not in a git repo | Falls back to cwd, warns |
| `/ticketing:new` before `init` | Stops — tells you to run `/ticketing:init` first |
| `/ticketing:move <ID>` to same state | Skips move, still regenerates INDEX.md |
| Two lessons on the same day | Second one gets `-2` suffix |
| Custom frontmatter fields | Preserved by `move`, ignored by `list` |
| Malformed frontmatter | Warning in chat, file skipped in INDEX.md, other tickets still render |
| Concurrent ticket creation | Resolve the `.config.json` merge conflict by bumping the second ticket's ID and renaming the file |

## Design choices

- **No database** — git is the source of truth. `grep` and `find` are your query language.
- **State = directory.** The `status:` frontmatter field is authoritative; the directory mirrors it. `/ticketing:move` keeps them aligned.
- **INDEX.md is always derivable** from the ticket files. Never hand-edit — regenerate with `/ticketing:list`.
- **Per-repo prefixes** make IDs unambiguous across a multi-repo GitHub org. `SSS-T042` and `PMJ-T042` are visibly different tickets.

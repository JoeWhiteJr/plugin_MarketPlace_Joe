---
name: new
description: Create a new ticket in docs/tickets/open/ with auto-incremented ID, slugified filename, and frontmatter from the template.
disable-model-invocation: true
---

# New Ticket

You are executing the `new` skill — creating a fresh ticket markdown file in `docs/tickets/open/`.

`$ARGUMENTS` is the ticket **title** (required). If empty, stop and report:
> Usage: `/ticketing:new "Ticket title here"`

---

## Phase 1 — Locate Repo and Config

1. Run `git rev-parse --show-toplevel` to get `ROOT`. If it fails, fall back to the current working directory and warn.
2. Read `<ROOT>/docs/tickets/.config.json`.
3. If the file does not exist, stop and report:
   > Ticketing isn't initialized yet. Run `/ticketing:init` first.
4. Parse `prefix` and `next_id` from the JSON. Store as `PREFIX` and `NEXT_ID`.

---

## Phase 2 — Build Filename

1. Format the ID: `<PREFIX>-T<NEXT_ID zero-padded to 3 digits>`. Examples: `SSS-T001`, `PMJ-T042`.
2. Slugify the title:
   - Lowercase everything.
   - Replace any run of non-alphanumeric characters with a single `-`.
   - Strip leading/trailing `-`.
   - Truncate to **40 characters max**, and re-strip trailing `-` after truncation.
3. Store as `SLUG`.
4. Filename: `<ID>-<SLUG>.md`, e.g., `SSS-T001-add-mfa-to-login.md`.
5. Target path: `<ROOT>/docs/tickets/open/<filename>`.
6. Guard: if that file already exists (should not happen, but just in case), stop and report:
   > Ticket file already exists at `<path>`. The .config.json `next_id` is out of sync. Inspect `docs/tickets/` and fix manually.

---

## Phase 3 — Write Ticket from Template

Use the inline template below. Substitute:
- `{{id}}` → the full ID (e.g., `SSS-T001`)
- `{{title}}` → the raw title from `$ARGUMENTS` (no slugification)
- `{{date}}` → today's ISO date (`YYYY-MM-DD`)

Write the substituted content to the target path with the Write tool.

**Template:**

```markdown
---
id: {{id}}
title: {{title}}
status: open
priority: medium
type: feature
owner: joe
created: {{date}}
updated: {{date}}
related-pr:
related-tickets:
---

# {{title}}

## Problem
_What's the problem we're solving? Who is affected?_

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Context & Notes
_Background, decisions made, links, gotchas._

## Implementation Plan
_How will we solve this? Break into steps if useful._

## Retrospective
_Fill in when moving to done/: what went well, what didn't, what we'd do differently._
```

**Per-repo override:** If `<ROOT>/docs/tickets/.templates/ticket.md.template` exists, read that file instead and use it as the template (enables per-repo customization). If it doesn't exist, use the inline version above.

---

## Phase 4 — Increment next_id

1. Re-read `<ROOT>/docs/tickets/.config.json` (in case another process changed it).
2. Set `next_id` to `NEXT_ID + 1`, preserving all other fields.
3. Write the updated config back.

---

## Phase 5 — Regenerate INDEX.md

Invoke the same logic as the `list` skill (Phase 2-3 of `/ticketing:list`) to rebuild `<ROOT>/docs/tickets/INDEX.md` so the new ticket shows up under "Open". You can do this inline rather than delegating — the steps are:

1. Glob `<ROOT>/docs/tickets/{open,in-progress,done}/*.md` (exclude INDEX.md and README.md).
2. Parse YAML frontmatter from each file (id, title, priority, owner, created, closed).
3. Write INDEX.md in the format documented in the `list` skill.

If regeneration fails for any reason, don't fail the whole skill — just warn the user that INDEX.md may be stale and they can run `/ticketing:list` manually.

---

## Phase 6 — Report

> **Ticket created: `<ID>`**
>
> - **Title:** `<title>`
> - **Path:** `docs/tickets/open/<filename>`
> - **Status:** open
>
> **Next:** open the file and fill in the frontmatter (priority, owner, type) and the Problem / Acceptance Criteria sections.
>
> Move to in-progress when you start work: `/ticketing:move <ID> in-progress`

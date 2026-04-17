---
name: adr
description: Create a new Architecture Decision Record in docs/decisions/ with an auto-incremented 4-digit ID and regenerate the decisions index.
disable-model-invocation: true
---

# New ADR

You are executing the `adr` skill — creating a new Architecture Decision Record (ADR) in `docs/decisions/`.

`$ARGUMENTS` is the ADR **title** (required). If empty, stop and report:
> Usage: `/ticketing:adr "Use Postgres for primary store"`

ADRs are numbered sequentially with 4-digit zero-padded IDs (`0001`, `0002`, ...). They are **not** prefixed per-repo (unlike tickets) — the ADR ID is the filename itself.

---

## Phase 1 — Locate Repo and Directory

1. Get `ROOT` via `git rev-parse --show-toplevel` (fallback to cwd).
2. Ensure `<ROOT>/docs/decisions/` exists (create with `mkdir -p` if not — this skill works even without `/ticketing:init` having been run, because ADRs are self-contained).

---

## Phase 2 — Compute Next ADR ID

1. Glob `<ROOT>/docs/decisions/*.md` and extract files matching the pattern `<4-digit>-*.md`. Exclude `INDEX.md`.
2. Parse the leading 4-digit number from each filename.
3. `NEXT_ID` = max existing number + 1, or `1` if no ADRs exist.
4. Format as zero-padded 4-digit string: `0001`, `0042`, `0123`.

---

## Phase 3 — Build Filename

1. Slugify the title (same rules as `/ticketing:new`):
   - Lowercase, replace non-alphanumeric runs with `-`, strip edges, truncate to 40 chars.
2. Filename: `<NEXT_ID>-<SLUG>.md`, e.g., `0003-use-postgres-for-primary-store.md`.
3. Target path: `<ROOT>/docs/decisions/<filename>`.
4. Guard: if the file already exists, stop — this means the ID calculation is stale (should not happen).

---

## Phase 4 — Write ADR from Template

Use the inline template below. Substitute:
- `{{id}}` → `NEXT_ID` (the 4-digit string)
- `{{title}}` → raw title
- `{{date}}` → today's ISO date

Write the substituted content to the target path with the Write tool.

**Template:**

```markdown
# ADR {{id}}: {{title}}

**Status:** Proposed
**Date:** {{date}}
**Deciders:** joe

## Context
_What's the situation that requires a decision? What forces are at play?_

## Decision
_What did we decide?_

## Rationale
_Why did we decide this over alternatives?_

## Alternatives Considered
- **Option A:** Pros / Cons
- **Option B:** Pros / Cons

## Consequences
### Positive
-

### Negative
-

### Risks
-

## Related
- Related ADRs:
- Related tickets:
```

**Per-repo override:** If `<ROOT>/docs/decisions/.templates/adr.md.template` exists, read that file instead and use it as the template. Otherwise use the inline version above.

---

## Phase 5 — Regenerate docs/decisions/INDEX.md

Write `<ROOT>/docs/decisions/INDEX.md` with this structure:

```
# Architecture Decision Records

_Last updated: <today ISO date>_

| ID | Title | Status | Date |
|----|-------|--------|------|
| [0001](0001-slug.md) | Title | Accepted | 2026-04-01 |
| [0002](0002-slug.md) | ... | ... | ... |
```

To populate:
1. Glob `<ROOT>/docs/decisions/*.md` (exclude INDEX.md).
2. For each, read the file and extract:
   - The 4-digit ID from the filename.
   - The title from the first `# ADR <id>: <title>` heading (or fall back to the filename slug, humanized).
   - The `**Status:**` field value (line starting with `**Status:**`).
   - The `**Date:**` field value.
3. Sort ascending by ID.
4. If any field is missing, render it as `—`.

---

## Phase 6 — Report

> **ADR created: `<NEXT_ID>`**
>
> - **Title:** `<title>`
> - **Path:** `docs/decisions/<filename>`
> - **Status:** Proposed
>
> **Next:** open the file and fill in the Context, Decision, Rationale, Alternatives, and Consequences sections. Change status to `Accepted` (or `Rejected` / `Superseded`) once the decision is finalized.

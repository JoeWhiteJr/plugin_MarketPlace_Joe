---
name: list
description: "List all saved session handoff files with summary info."
user_invocable: true
arguments: ""
---

# /session-handoff:list

List all saved session handoffs so the user can choose one to load.

---

## Phase 1 — Find Handoffs

1. Check if `.handoff/` directory exists.
   - If not, inform the user: "No handoffs found. Use `/session-handoff:save` to create one."
   - Stop here.

2. List all `.md` files in `.handoff/`, sorted by modification time (newest first).
   - If no files found, same message as above.

---

## Phase 2 — Build Summary Table

For each handoff file, read just enough to extract:
- **Name**: filename without `.md` extension
- **Saved**: timestamp from the `> Saved:` line
- **Branch**: from the `**Branch**:` line in Git State
- **Status**: from the `**Status**:` line in Current State
- **Summary**: first line of the "Work Done" section (truncated to 60 chars)

Present as a table:

```
| # | Name | Saved | Branch | Status | Summary |
|---|------|-------|--------|--------|---------|
| 1 | ... | ... | ... | ... | ... |
```

---

## Phase 3 — Usage Hint

After the table, display:
> Load a handoff with: `/session-handoff:load <name>`

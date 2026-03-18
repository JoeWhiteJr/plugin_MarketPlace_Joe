---
name: load
description: "Load a saved handoff file and present session context to resume work."
user_invocable: true
arguments: "[name] — optional name of the handoff to load; defaults to most recent"
---

# /session-handoff:load

Load a previously saved session handoff and present the context so you can continue where the last session left off.

---

## Phase 1 — Resolve Handoff File

1. If `$ARGUMENTS` is non-empty, use it as the handoff name:
   - Try exact match: `.handoff/<name>.md`
   - If not found, try fuzzy match: find files in `.handoff/` whose names contain the argument
   - If multiple fuzzy matches, list them and ask the user to choose
   - If no matches, list available handoffs and abort

2. If `$ARGUMENTS` is empty:
   - Find the most recently modified `.handoff/*.md` file
   - If no handoff files exist, inform the user and suggest `/session-handoff:save`

---

## Phase 2 — Load and Validate

1. Read the handoff file fully.
2. Check for branch mismatch:
   - Get current branch: `git branch --show-current`
   - Compare with the branch recorded in the handoff's **Git State** section
   - If different, display a warning:
     > **Warning**: This handoff was saved on branch `<saved-branch>`, but you're currently on `<current-branch>`. You may want to switch branches before continuing.

---

## Phase 3 — Present Context

Present the handoff content to the user with emphasis on actionable information:

1. Display the full handoff content as-is (it's already well-structured).
2. After the content, highlight the **Next Steps** section:
   > **Suggested starting point**: The next steps from your last session are listed above. Would you like to start with step 1, or is there something else you'd like to focus on?

---

## Phase 4 — Cleanup Prompt

After presenting, ask:
> Would you like to keep this handoff file, or delete it now that it's been loaded?

Do NOT delete automatically — always let the user decide.

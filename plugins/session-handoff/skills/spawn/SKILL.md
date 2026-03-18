---
name: spawn
description: "Save session context and provide instructions to continue in a new terminal."
user_invocable: true
arguments: "[name] — optional name for the handoff; defaults to branch name or timestamp"
---

# /session-handoff:spawn

Save the current session context and give the user clear instructions for continuing in a new Claude Code terminal.

---

## Phase 1 — Save (Inline)

Execute the full save logic from the save skill (`skills/save/SKILL.md`) inline:

1. Determine handoff name from `$ARGUMENTS`, branch name, or timestamp
2. Gather git state and session context
3. Write to `.handoff/<name>.md`
4. Ensure `.handoff/` is in `.gitignore`

Do NOT invoke the save skill as a sub-skill — execute its logic inline.

---

## Phase 2 — Spawn Instructions

After saving, display clear instructions:

```
Session saved to .handoff/<name>.md

To continue in a new terminal:
  1. Open a new terminal in this project directory
  2. Run: claude
  3. Then run: /session-handoff:load <name>

The new session will have full context of where you left off.
```

---

## Phase 3 — Optional Quick Reference

If there are next steps in the handoff, also display a quick preview:

```
Quick preview of next steps:
  1. <first next step>
  2. <second next step>
  ...
```

This helps the user confirm the handoff captured the right context before closing the current session.

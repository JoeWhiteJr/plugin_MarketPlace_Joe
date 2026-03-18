# session-handoff

Save and restore structured session context for seamless handoffs between Claude Code terminals.

## Problem

When a Claude Code session hits context limits or needs to be continued later, each new terminal starts from scratch. Users must re-explain what they were working on, what decisions were made, and what's next.

## Solution

This plugin saves structured context from one session and loads it into the next — enabling seamless handoffs between terminals.

Handoff files are stored locally at `.handoff/<name>.md` and are automatically added to `.gitignore`.

## Skills

| Skill | Description |
|-------|-------------|
| `/session-handoff:save [name]` | Save current session context to a handoff file |
| `/session-handoff:load [name]` | Load a saved handoff to resume work |
| `/session-handoff:list` | List all saved handoffs with summary info |
| `/session-handoff:spawn [name]` | Save context and get instructions for a new terminal |

## Usage

### End of a session
```
/session-handoff:save my-feature
```

### Start of a new session
```
/session-handoff:load my-feature
```

### When hitting context limits
```
/session-handoff:spawn
```
This saves context and tells you exactly how to continue in a new terminal.

## Handoff File Format

Each handoff captures:
- **Git State** — branch, status, recent commits
- **Work Done** — what was accomplished
- **Key Decisions** — why things were done a certain way
- **Current State** — working, broken, or partially working
- **Next Steps** — prioritized list of what to do next
- **Critical Files** — key files with their roles
- **Gotchas & Warnings** — things the next session needs to watch out for

## Installation

Add to your Claude Code settings:

```json
{
  "plugins": ["github:JoeWhiteJr/plugin_MarketPlace_Joe//plugins/session-handoff"]
}
```

# joe-marketplace

A curated collection of Claude Code plugins for developer workflows.

## Installation

Add this marketplace to Claude Code:

```bash
/plugin marketplace add JoeWhiteJr/plugin_MarketPlace_Joe
```

Or install a specific plugin directly:

```bash
claude plugin add --from JoeWhiteJr/plugin_MarketPlace_Joe/plugins/git-workflow
```

## Available Plugins

### git-workflow

Automates the "done coding → PR ready" cycle. Two skills:

| Skill | Command | What it does |
|-------|---------|-------------|
| **ship** | `/git-workflow:ship` | Rebase onto main, run tests, commit, push, and create a PR |
| **cleanup** | `/git-workflow:cleanup` | Delete the feature branch after the PR is merged |

[View plugin docs →](plugins/git-workflow/README.md)

## Testing Locally

Load a plugin from this repo during development:

```bash
claude --plugin-dir ./plugins/git-workflow
```

Then run `/help` to verify the skills appear.

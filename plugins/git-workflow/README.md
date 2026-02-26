# git-workflow

A Claude Code plugin that automates the "done coding → PR ready" cycle.

## Skills

### `/git-workflow:ship`

Takes your feature branch from "done coding" to "PR created" in one command:

1. **Pre-flight** — Verifies you're on a feature branch with changes
2. **Rebase** — Fetches and rebases onto the default branch, resolving conflicts automatically (up to 3 attempts)
3. **Test** — Auto-detects your test runner and runs tests
4. **Commit** — Stages all changes and commits with a generated message
5. **Push + PR** — Pushes the branch and creates a pull request via `gh`

```bash
# Auto-generate commit message from changes
/git-workflow:ship

# Provide your own commit message
/git-workflow:ship fix: resolve race condition in auth middleware
```

### `/git-workflow:cleanup`

Run after your PR has been merged to clean up the feature branch:

```bash
# From the feature branch
/git-workflow:cleanup

# Or from main, specifying the branch
/git-workflow:cleanup my-feature-branch
```

This will:
- Verify the PR was actually merged
- Switch to the default branch and pull latest
- Delete the local and remote branch
- Prune stale remote-tracking refs

## Requirements

- **git** — any recent version
- **[GitHub CLI (`gh`)](https://cli.github.com/)** — authenticated (`gh auth login`)
- A GitHub remote named `origin`

## Supported Test Runners

The `ship` skill auto-detects your test runner:

| Detected by | Command |
|-------------|---------|
| `package.json` with `"test"` script | `npm test` |
| `Makefile` with `test` target | `make test` |
| `pytest.ini` / `pyproject.toml` / `setup.cfg` | `pytest` |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |

If no test runner is found, testing is skipped with a note.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| On main/master | Stops — "create a feature branch first" |
| No changes to ship | Stops — "no changes to ship" |
| Rebase conflicts | Auto-resolves up to 3 attempts, then aborts |
| Tests fail after rebase | Attempts fix twice, then reports to user |
| PR already exists | Reports existing PR URL |
| Push rejected | Falls back to `--force-with-lease` |
| CI still running (cleanup) | Tells user to wait |
| Branch already deleted remotely | Handles gracefully |

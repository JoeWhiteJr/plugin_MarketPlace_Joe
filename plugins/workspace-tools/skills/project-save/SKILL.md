---
name: project-save
description: Save the current workspace as a named project configuration with dev commands and context files.
disable-model-invocation: true
---

# Save workspace project

Capture the current workspace as a reusable config at `~/.claude/workspace-projects/<name>/project.json`. The actual write is done by `scripts/project-save.sh` (non-interactive); your job is to gather inputs from the user and the environment, then invoke the script with concrete flags.

## Inputs

`$ARGUMENTS` is expected to be `<name> [description words...]`.

- If `<name>` is missing, ask the user for it before proceeding.
- If description words are present, join them into the `description`. If absent, ask.

Name must match `^[a-zA-Z0-9_-]+$` (kebab-case or snake_case). Reject spaces or slashes.

## Workflow

1. **Detect cwd.** Run `pwd` to determine the project root. Confirm the absolute path with the user if it looks wrong (e.g. you are inside a subdir of the real repo).

2. **Detect project type.** Check for these files at the root and build a deduplicated list:
   - `package.json` or `tsconfig.json` → add `TypeScript` (or `JavaScript` if no `tsconfig.json`)
   - `pyproject.toml`, `setup.py`, or `requirements.txt` → add `Python`
   - `Cargo.toml` → add `Rust`
   - `go.mod` → add `Go`

3. **Detect likely dev commands.** Inspect the repo and propose entries:
   - `package.json` with `scripts.dev` → `{"name": "frontend", "cwd": ".", "cmd": "npm run dev", "port": 3000}` (adjust port if visible)
   - `package.json` with `scripts.start` (no `dev`) → same shape with `npm start`
   - `backend/` + `frontend/` subdirs → propose two entries, one per subdir
   - FastAPI/`uvicorn` references in Python → `uvicorn app.main:app --reload` with port 8000
   - `Makefile` with a `dev` or `run` target → `make dev` / `make run`
   - If nothing detected, leave `dev_commands` as `[]`

4. **Propose the config to the user.** Show detected project type, proposed dev commands, and the description. Ask them to confirm or edit. Accept corrections before moving on.

5. **Ask about context files.** Suggest `README.md` if it exists, plus obvious docs (`docs/*.md`, `ARCHITECTURE.md`). Paths must be relative to the root.

6. **Ask about test command.** Common defaults: `make test`, `pytest`, `npm test`. Empty string is fine.

7. **Ask about memory pointer.** Usually `MEMORY.md § <Project Name>`. Empty string is fine.

8. **Invoke the script.** Resolve the plugin root (`${CLAUDE_PLUGIN_ROOT}` if set, else `~/.claude/plugins/marketplaces/joe-marketplace/plugins/workspace-tools`) and run:

   ```bash
   PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/marketplaces/joe-marketplace/plugins/workspace-tools}"
   bash "$PLUGIN_ROOT/scripts/project-save.sh" "$name" \
     --description "$desc" \
     --root "$root" \
     --project-type "$types_csv" \
     --dev-commands "$dev_commands_json" \
     --context-files "$context_csv" \
     --test-command "$test_cmd" \
     --memory-pointer "$memory_ptr"
   ```

   - `$types_csv` is a comma-separated list (e.g. `"Python,TypeScript"`); pass `""` for none.
   - `$dev_commands_json` is a raw JSON array string (e.g. `'[{"name":"api","cwd":"backend","cmd":"uvicorn app.main:app --reload","port":8000}]'`); pass `'[]'` for none.
   - `$context_csv` is comma-separated paths relative to root; omit the flag or pass `""` for none.
   - Add `--force` only if the user explicitly asked to overwrite an existing config.

9. **Relay the script output verbatim** (it already prints the saved path, a field summary, and the next-step hint). If the script exits non-zero, show the error and ask the user how to proceed — do not retry silently.

## Constraints

- Do not call `read` or prompt for stdin inside the script — all inputs flow through flags.
- Paths are always absolute for `--root` and relative (from root) for `--context-files`.
- Never touch `~/.claude/projects/` (Claude's auto-memory dir). This skill writes only to `$WORKSPACE_PROJECTS_DIR` (default `~/.claude/workspace-projects/`).

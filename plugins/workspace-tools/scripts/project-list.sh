#!/usr/bin/env bash
# project-list.sh — list all saved workspace projects
# Reads: ~/.claude/workspace-projects/<name>/project.json
set -euo pipefail

PROJECTS_DIR="${WORKSPACE_PROJECTS_DIR:-$HOME/.claude/workspace-projects}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required but not installed." >&2
  exit 1
fi

if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "No saved projects."
  echo "Use '/workspace-tools:project-seed' to load the 6 pre-configured projects,"
  echo "or '/workspace-tools:project-save <name>' to save the current workspace."
  exit 0
fi

python3 - "$PROJECTS_DIR" <<'PY'
import json
import os
import sys
from pathlib import Path

projects_dir = Path(sys.argv[1])
project_jsons = sorted(projects_dir.glob("*/project.json"))

if not project_jsons:
    print(f"No saved projects in {projects_dir}.")
    print("Use '/workspace-tools:project-seed' to pre-seed, or '/workspace-tools:project-save <name>'.")
    sys.exit(0)

print(f"Saved Projects ({len(project_jsons)}):")
print()

for pj in project_jsons:
    try:
        data = json.loads(pj.read_text())
    except json.JSONDecodeError:
        print(f"  ⚠ Skipping invalid JSON: {pj}")
        continue

    name = data.get("name", "(unnamed)")
    desc = data.get("description", "")
    root = data.get("root", "")
    created = data.get("created", "")
    project_types = ", ".join(data.get("project_type", []) or [])
    terminals = data.get("terminals", []) or []
    terminal_names = ", ".join(t.get("name", "") for t in terminals)
    context_files = ", ".join(data.get("context_files", []) or [])
    dev_cmds = data.get("dev_commands", []) or []
    dev_cmd_names = ", ".join(c.get("name", "") for c in dev_cmds)
    test_cmd = data.get("test_command", "")
    memory_pointer = data.get("memory_pointer", "")

    root_marker = ""
    if root and not Path(root).is_dir():
        root_marker = " ⚠ missing"

    print(name)
    if desc:
        print(f"  {desc}")
    if root:
        print(f"  Root: {root}{root_marker}")
    if terminal_names:
        print(f"  Terminals: {terminal_names} ({len(terminals)})")
    if dev_cmd_names:
        print(f"  Dev commands: {dev_cmd_names}")
    if test_cmd:
        print(f"  Test: {test_cmd}")
    if context_files:
        print(f"  Context: {context_files}")
    if project_types:
        print(f"  Type: {project_types}")
    if created:
        print(f"  Created: {created}")
    if memory_pointer:
        print(f"  Memory: {memory_pointer}")
    print()

print("Use '/workspace-tools:project-start <name>' to launch a project.")
print("Use '/workspace-tools:project-start <name> --dry-run' to preview.")
PY

#!/usr/bin/env bash
# project-stop.sh — stop background dev servers started by project-start.sh.
# Reads PIDs from ~/.claude/workspace-projects/<name>/.pids (one "name=PID" per line).
# Sends SIGTERM then SIGKILL (if still alive) to each PID and its process group.
#
# Usage: project-stop.sh <name>
# Env:   WORKSPACE_PROJECTS_DIR (default: $HOME/.claude/workspace-projects)
set -euo pipefail

PROJECTS_DIR="${WORKSPACE_PROJECTS_DIR:-$HOME/.claude/workspace-projects}"

if [[ $# -lt 1 ]]; then
  echo "Usage: project-stop.sh <name>" >&2
  exit 1
fi

NAME="$1"
PROJECT_DIR="$PROJECTS_DIR/$NAME"
PIDS_FILE="$PROJECT_DIR/.pids"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: no saved project named '$NAME' at $PROJECT_DIR" >&2
  exit 1
fi

if [[ ! -s "$PIDS_FILE" ]]; then
  echo "No running processes tracked for $NAME."
  exit 0
fi

is_alive() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

stop_one() {
  local label="$1" pid="$2"

  if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    echo "⚠ $label: invalid PID '$pid' — skipping"
    return
  fi

  if ! is_alive "$pid"; then
    echo "  $label (PID $pid): already stopped"
    return
  fi

  # Try killing the whole process group first (setsid put it in its own group).
  kill -TERM "-$pid" 2>/dev/null || true
  kill -TERM "$pid" 2>/dev/null || true

  # Give it up to ~3s to exit cleanly.
  for _ in 1 2 3 4 5 6; do
    if ! is_alive "$pid"; then
      break
    fi
    sleep 0.5
  done

  if is_alive "$pid"; then
    kill -KILL "-$pid" 2>/dev/null || true
    kill -KILL "$pid" 2>/dev/null || true
    sleep 0.3
    if is_alive "$pid"; then
      echo "⚠ $label (PID $pid): still alive after SIGKILL"
      return
    fi
    echo "✓ $label (PID $pid): killed (SIGKILL)"
  else
    echo "✓ $label (PID $pid): stopped (SIGTERM)"
  fi
}

echo "── Stopping '$NAME' ──"
while IFS='=' read -r label pid; do
  [[ -z "$label" || -z "$pid" ]] && continue
  stop_one "$label" "$pid"
done < "$PIDS_FILE"

# Truncate on completion so a re-run is idempotent.
: > "$PIDS_FILE"
echo "Cleared PID file: $PIDS_FILE"
exit 0

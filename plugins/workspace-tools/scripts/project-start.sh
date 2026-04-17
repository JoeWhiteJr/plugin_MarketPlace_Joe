#!/usr/bin/env bash
# project-start.sh — load a saved workspace project, run git safety checks,
# print context + memory pointers, and launch configured dev commands in the
# background (or just print the plan with --dry-run).
#
# Usage: project-start.sh <name> [--dry-run]
# Env:   WORKSPACE_PROJECTS_DIR (default: $HOME/.claude/workspace-projects)
set -euo pipefail

PROJECTS_DIR="${WORKSPACE_PROJECTS_DIR:-$HOME/.claude/workspace-projects}"

list_available() {
  if [[ -d "$PROJECTS_DIR" ]]; then
    local found=0
    for pj in "$PROJECTS_DIR"/*/project.json; do
      [[ -f "$pj" ]] || continue
      found=1
      local dir
      dir="$(dirname "$pj")"
      echo "  - $(basename "$dir")"
    done
    if [[ $found -eq 0 ]]; then
      echo "  (none — run '/workspace-tools:project-seed' to pre-seed)"
    fi
  else
    echo "  (no projects directory at $PROJECTS_DIR)"
  fi
}

usage() {
  cat >&2 <<EOF
Usage: project-start.sh <name> [--dry-run]

Starts a saved workspace project: runs git safety checks, prints linked
context files and memory pointer, and launches configured dev commands in
the background. Use --dry-run to preview without launching.

Available projects:
EOF
  list_available >&2
}

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required but not installed." >&2
  exit 1
fi

# --- parse args ---
NAME=""
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "Error: unknown flag: $arg" >&2; usage; exit 1 ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$arg"
      else
        echo "Error: unexpected positional arg: $arg" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  usage
  exit 1
fi

PROJECT_DIR="$PROJECTS_DIR/$NAME"
PROJECT_JSON="$PROJECT_DIR/project.json"

if [[ ! -f "$PROJECT_JSON" ]]; then
  echo "Error: no saved project named '$NAME' at $PROJECT_JSON" >&2
  echo "" >&2
  echo "Available projects:" >&2
  list_available >&2
  exit 1
fi

# --- parse project.json via python, emit shell-evaluable key=value lines ---
# Fields exported to the shell:
#   P_NAME, P_DESCRIPTION, P_ROOT, P_MEMORY_POINTER
#   P_CONTEXT_FILES     — newline-separated
#   P_DEV_CMD_COUNT     — integer
#   P_DEV_CMD_i_NAME / CWD / CMD / PORT   (0-indexed)
PY_OUT="$(python3 - "$PROJECT_JSON" <<'PY'
import json
import sys
import shlex
from pathlib import Path

pj = Path(sys.argv[1])
try:
    data = json.loads(pj.read_text())
except Exception as exc:  # noqa: BLE001
    print(f"echo 'Error: failed to parse {pj}: {exc}' >&2", file=sys.stderr)
    sys.exit(2)

def emit(key, value):
    print(f"{key}={shlex.quote(str(value))}")

emit("P_NAME", data.get("name", ""))
emit("P_DESCRIPTION", data.get("description", ""))
emit("P_ROOT", data.get("root", ""))
emit("P_MEMORY_POINTER", data.get("memory_pointer", ""))

ctx = data.get("context_files") or []
# join newline-separated; shlex.quote will handle it safely
emit("P_CONTEXT_FILES", "\n".join(ctx))

dev_cmds = data.get("dev_commands") or []
emit("P_DEV_CMD_COUNT", len(dev_cmds))
for i, cmd in enumerate(dev_cmds):
    emit(f"P_DEV_CMD_{i}_NAME", cmd.get("name", f"cmd{i}"))
    emit(f"P_DEV_CMD_{i}_CWD", cmd.get("cwd", "."))
    emit(f"P_DEV_CMD_{i}_CMD", cmd.get("cmd", ""))
    emit(f"P_DEV_CMD_{i}_PORT", cmd.get("port", ""))
PY
)"

# shellcheck disable=SC1090
eval "$PY_OUT"

# --- validate root ---
if [[ -z "${P_ROOT:-}" ]]; then
  echo "Error: project '$NAME' has no 'root' field." >&2
  exit 1
fi
if [[ ! -d "$P_ROOT" ]]; then
  echo "Error: project root does not exist: $P_ROOT" >&2
  exit 1
fi

# --- print plan header ---
echo "=============================================="
echo "Project: $P_NAME"
[[ -n "${P_DESCRIPTION:-}" ]] && echo "  $P_DESCRIPTION"
echo "  Root: $P_ROOT"
echo "  Dev commands: ${P_DEV_CMD_COUNT:-0}"
echo "=============================================="
echo ""

# --- git safety gate ---
if [[ -d "$P_ROOT/.git" ]]; then
  echo "── Git status ──"
  if ! (cd "$P_ROOT" && git fetch origin 2>/dev/null); then
    echo "⚠ git fetch origin failed (offline? no remote?) — continuing"
  fi

  # detect default branch
  DEFAULT_BRANCH="$(cd "$P_ROOT" && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || true)"
  [[ -z "$DEFAULT_BRANCH" ]] && DEFAULT_BRANCH="main"

  CURRENT_BRANCH="$(cd "$P_ROOT" && git branch --show-current 2>/dev/null || echo "(detached)")"

  if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
    echo "⚠ On branch '$CURRENT_BRANCH' (default: '$DEFAULT_BRANCH')"
  else
    echo "  On branch '$CURRENT_BRANCH'"
  fi

  DIRTY="$(cd "$P_ROOT" && git status --porcelain 2>/dev/null || true)"
  if [[ -n "$DIRTY" ]]; then
    echo "⚠ Working tree is dirty:"
    (cd "$P_ROOT" && git status --short) | sed 's/^/    /'
    echo "  (continuing — re-run after committing/stashing if you prefer a clean start)"
  else
    echo "  Working tree clean"
  fi
  echo ""
fi

# --- context files ---
if [[ -n "${P_CONTEXT_FILES:-}" ]]; then
  echo "── Context files ──"
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    if [[ "$rel" = /* ]]; then
      abs="$rel"
    else
      abs="$P_ROOT/$rel"
    fi
    if [[ -r "$abs" ]]; then
      echo "  - $abs"
    else
      echo "  - $abs (missing)"
    fi
  done <<< "$P_CONTEXT_FILES"
  echo ""
fi

# --- memory pointer ---
if [[ -n "${P_MEMORY_POINTER:-}" ]]; then
  echo "── Memory pointer ──"
  echo "  $P_MEMORY_POINTER"
  echo ""
fi

# --- dev commands ---
COUNT="${P_DEV_CMD_COUNT:-0}"

if [[ "$COUNT" -eq 0 ]]; then
  echo "No dev_commands configured for '$NAME'. Nothing to launch."
  exit 0
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo "── Dev commands (dry-run) ──"
  for (( i=0; i<COUNT; i++ )); do
    nvar="P_DEV_CMD_${i}_NAME";   cname="${!nvar}"
    cvar="P_DEV_CMD_${i}_CWD";    ccwd="${!cvar}"
    xvar="P_DEV_CMD_${i}_CMD";    xcmd="${!xvar}"
    pvar="P_DEV_CMD_${i}_PORT";   pport="${!pvar:-}"

    if [[ -z "$ccwd" ]]; then
      ccwd="."
    fi
    if [[ "$ccwd" = /* ]]; then
      resolved="$ccwd"
    else
      resolved="$P_ROOT/$ccwd"
    fi

    echo "  [$cname]"
    echo "    cwd:  $resolved"
    echo "    cmd:  $xcmd"
    [[ -n "$pport" ]] && echo "    port: $pport"
  done
  echo ""
  echo "(dry-run — nothing launched)"
  exit 0
fi

# --- real launch ---
LOG_DIR="$PROJECT_DIR/logs"
PIDS_FILE="$PROJECT_DIR/.pids"
mkdir -p "$LOG_DIR"
: > "$PIDS_FILE"

echo "── Launching dev commands ──"
for (( i=0; i<COUNT; i++ )); do
  nvar="P_DEV_CMD_${i}_NAME";   cname="${!nvar}"
  cvar="P_DEV_CMD_${i}_CWD";    ccwd="${!cvar}"
  xvar="P_DEV_CMD_${i}_CMD";    xcmd="${!xvar}"
  pvar="P_DEV_CMD_${i}_PORT";   pport="${!pvar:-}"

  if [[ -z "$ccwd" ]]; then
    ccwd="."
  fi
  if [[ "$ccwd" = /* ]]; then
    resolved="$ccwd"
  else
    resolved="$P_ROOT/$ccwd"
  fi

  if [[ ! -d "$resolved" ]]; then
    echo "⚠ Skipping '$cname' — cwd does not exist: $resolved"
    continue
  fi

  log_path="$LOG_DIR/${cname}.log"

  # Launch: subshell cd's then setsid+nohup so the process survives this script.
  # stdin is redirected from /dev/null; stdout+stderr merged into log.
  pid="$(
    cd "$resolved"
    setsid bash -c "$xcmd" </dev/null >"$log_path" 2>&1 &
    echo $!
  )"

  if [[ -z "$pid" ]]; then
    echo "⚠ Failed to launch '$cname'"
    continue
  fi

  echo "${cname}=${pid}" >> "$PIDS_FILE"
  port_note=""
  [[ -n "$pport" ]] && port_note=" (port $pport)"
  echo "✓ Started $cname (PID $pid)${port_note} — logs: $log_path"

  # brief pause then show first output
  sleep 1
  if [[ -s "$log_path" ]]; then
    echo "  --- first log lines ---"
    tail -n 5 "$log_path" | sed 's/^/    /'
  fi
  echo ""
done

echo "All tracked PIDs written to: $PIDS_FILE"
echo "Stop with: /workspace-tools:project-stop $NAME"
exit 0

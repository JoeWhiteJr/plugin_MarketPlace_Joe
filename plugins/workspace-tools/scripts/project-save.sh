#!/usr/bin/env bash
#
# project-save.sh — non-interactive saver for a workspace project config.
#
# Writes "$WORKSPACE_PROJECTS_DIR/<name>/project.json" and (optionally) copies
# context files into "$WORKSPACE_PROJECTS_DIR/<name>/context/". Designed to be
# invoked by the project-save skill (Claude collects the inputs conversationally
# and then calls this script with concrete flags) — not by a user at a prompt.
#
# Usage:
#   project-save.sh <name> --description "<desc>" --root <abs path> \
#     [--project-type "Python,TypeScript"] \
#     [--dev-commands '<json array>'] \
#     [--test-command "<cmd>"] \
#     [--memory-pointer "<pointer>"] \
#     [--context-files "path1,path2"] \
#     [--terminals '<json array>'] \
#     [--force]
#
# Env:
#   WORKSPACE_PROJECTS_DIR  default: $HOME/.claude/workspace-projects
#
# Notes:
#   - python3 for JSON construction/validation (jq is not installed).
#   - `cp` for context files (WSL cross-filesystem safe).

set -euo pipefail

TARGET_DIR_ROOT="${WORKSPACE_PROJECTS_DIR:-${HOME}/.claude/workspace-projects}"

usage() {
  sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "Error: $*" >&2
  exit 1
}

if ! command -v python3 >/dev/null 2>&1; then
  die "python3 is required but was not found in PATH."
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  die "missing required <name> argument."
fi

# Handle --help/-h as the first arg.
case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
esac

NAME="$1"
shift

# Validate kebab-case-ish name (alnum + dash + underscore, no spaces, no slashes, no leading dash).
if [[ ! "${NAME}" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  die "name must start with a letter/digit/underscore and contain only letters, digits, '-', or '_': got '${NAME}'"
fi

DESCRIPTION=""
ROOT=""
PROJECT_TYPE_CSV=""
DEV_COMMANDS_JSON="[]"
TEST_COMMAND=""
MEMORY_POINTER=""
CONTEXT_FILES_CSV=""
TERMINALS_JSON="[]"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --description)
      [[ $# -ge 2 ]] || die "--description requires a value"
      DESCRIPTION="$2"
      shift 2
      ;;
    --root)
      [[ $# -ge 2 ]] || die "--root requires a value"
      ROOT="$2"
      shift 2
      ;;
    --project-type)
      [[ $# -ge 2 ]] || die "--project-type requires a value"
      PROJECT_TYPE_CSV="$2"
      shift 2
      ;;
    --dev-commands)
      [[ $# -ge 2 ]] || die "--dev-commands requires a JSON array value"
      DEV_COMMANDS_JSON="$2"
      shift 2
      ;;
    --test-command)
      [[ $# -ge 2 ]] || die "--test-command requires a value"
      TEST_COMMAND="$2"
      shift 2
      ;;
    --memory-pointer)
      [[ $# -ge 2 ]] || die "--memory-pointer requires a value"
      MEMORY_POINTER="$2"
      shift 2
      ;;
    --context-files)
      [[ $# -ge 2 ]] || die "--context-files requires a value"
      CONTEXT_FILES_CSV="$2"
      shift 2
      ;;
    --terminals)
      [[ $# -ge 2 ]] || die "--terminals requires a JSON array value"
      TERMINALS_JSON="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "${DESCRIPTION}" ]] || die "--description is required"
[[ -n "${ROOT}" ]]        || die "--root is required"

# Root must be absolute and exist.
if [[ "${ROOT}" != /* ]]; then
  die "--root must be an absolute path: got '${ROOT}'"
fi
if [[ ! -d "${ROOT}" ]]; then
  die "--root directory does not exist: ${ROOT}"
fi

TARGET_DIR="${TARGET_DIR_ROOT}/${NAME}"
TARGET_FILE="${TARGET_DIR}/project.json"

if [[ -f "${TARGET_FILE}" && "${FORCE}" -ne 1 ]]; then
  die "project '${NAME}' already exists at ${TARGET_FILE} (use --force to overwrite)"
fi

# Validate / copy context files BEFORE writing anything destructive.
CONTEXT_REL_PATHS=()
if [[ -n "${CONTEXT_FILES_CSV}" ]]; then
  IFS=',' read -r -a raw_paths <<< "${CONTEXT_FILES_CSV}"
  for raw in "${raw_paths[@]}"; do
    # Trim whitespace.
    trimmed="${raw#"${raw%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -n "${trimmed}" ]] || continue

    # Must be relative to root.
    if [[ "${trimmed}" = /* ]]; then
      die "context file must be relative to --root: '${trimmed}'"
    fi
    abs_src="${ROOT}/${trimmed}"
    if [[ ! -f "${abs_src}" ]]; then
      die "context file not found under root: ${abs_src}"
    fi
    CONTEXT_REL_PATHS+=("${trimmed}")
  done
fi

CREATED="$(date +%Y-%m-%d)"

# Parse CSV project types into a JSON array via python3.
PROJECT_TYPE_JSON="$(python3 - "${PROJECT_TYPE_CSV}" <<'PY'
import json, sys
csv = sys.argv[1]
items = [p.strip() for p in csv.split(",") if p.strip()] if csv else []
print(json.dumps(items))
PY
)"

# Build the full project.json.
FINAL_JSON="$(
  NAME="${NAME}" \
  DESCRIPTION="${DESCRIPTION}" \
  CREATED="${CREATED}" \
  ROOT="${ROOT}" \
  TERMINALS_JSON="${TERMINALS_JSON}" \
  CONTEXT_FILES_JSON="$(printf '%s\n' "${CONTEXT_REL_PATHS[@]+"${CONTEXT_REL_PATHS[@]}"}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))')" \
  PROJECT_TYPE_JSON="${PROJECT_TYPE_JSON}" \
  DEV_COMMANDS_JSON="${DEV_COMMANDS_JSON}" \
  TEST_COMMAND="${TEST_COMMAND}" \
  MEMORY_POINTER="${MEMORY_POINTER}" \
  python3 <<'PY'
import json, os, sys

def parse_array(env_name: str) -> list:
    raw = os.environ.get(env_name, "").strip()
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"Error: {env_name} is not valid JSON: {exc}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(parsed, list):
        print(f"Error: {env_name} must be a JSON array, got {type(parsed).__name__}",
              file=sys.stderr)
        sys.exit(1)
    return parsed

def parse_list_env(env_name: str) -> list:
    raw = os.environ.get(env_name, "").strip()
    if not raw:
        return []
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"Error: {env_name} is not valid JSON: {exc}", file=sys.stderr)
        sys.exit(1)

config = {
    "name":           os.environ["NAME"],
    "description":    os.environ["DESCRIPTION"],
    "created":        os.environ["CREATED"],
    "root":           os.environ["ROOT"],
    "terminals":      parse_array("TERMINALS_JSON"),
    "context_files":  parse_list_env("CONTEXT_FILES_JSON"),
    "project_type":   parse_list_env("PROJECT_TYPE_JSON"),
    "dev_commands":   parse_array("DEV_COMMANDS_JSON"),
    "test_command":   os.environ.get("TEST_COMMAND", ""),
    "memory_pointer": os.environ.get("MEMORY_POINTER", ""),
}
print(json.dumps(config, indent=2))
PY
)"

# Write-out phase — only reached after all validation passed.
mkdir -p "${TARGET_DIR}/context"

printf '%s\n' "${FINAL_JSON}" > "${TARGET_FILE}"

# Copy context files with cp (WSL-safe), always into <target>/context/<basename>.
for rel in "${CONTEXT_REL_PATHS[@]+"${CONTEXT_REL_PATHS[@]}"}"; do
  src="${ROOT}/${rel}"
  dst="${TARGET_DIR}/context/$(basename "${rel}")"
  cp "${src}" "${dst}"
done

# Re-validate the written file to catch any surprise corruption.
python3 -m json.tool "${TARGET_FILE}" >/dev/null || die "written JSON failed validation: ${TARGET_FILE}"

# Summary output.
echo "Saved: ${TARGET_FILE}"
echo ""
echo "Summary"
echo "  name:           ${NAME}"
echo "  description:    ${DESCRIPTION}"
echo "  root:           ${ROOT}"
echo "  project_type:   ${PROJECT_TYPE_JSON}"
echo "  dev_commands:   ${DEV_COMMANDS_JSON}"
echo "  test_command:   ${TEST_COMMAND:-<none>}"
echo "  memory_pointer: ${MEMORY_POINTER:-<none>}"
if [[ "${#CONTEXT_REL_PATHS[@]}" -gt 0 ]]; then
  echo "  context_files:  ${CONTEXT_REL_PATHS[*]}"
else
  echo "  context_files:  <none>"
fi
echo ""
echo "Use /workspace-tools:project-start ${NAME} to launch."
exit 0

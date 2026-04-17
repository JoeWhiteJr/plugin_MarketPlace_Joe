#!/usr/bin/env bash
#
# project-seed.sh — copy bundled seed project.json files into the workspace projects dir.
#
# Behavior:
#   - Source defaults to "<script_dir>/../seeds" (override with WORKSPACE_SEEDS_DIR).
#   - Target defaults to "$HOME/.claude/workspace-projects" (override with WORKSPACE_PROJECTS_DIR).
#   - Never overwrites an existing project.json; skipped ones are reported.
#   - Validates every seed JSON with python3 before copying (jq is not installed).
#   - Uses `cp` (never `mv`) per the WSL cross-filesystem rule.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEEDS_DIR="${WORKSPACE_SEEDS_DIR:-${SCRIPT_DIR}/../seeds}"
TARGET_DIR="${WORKSPACE_PROJECTS_DIR:-${HOME}/.claude/workspace-projects}"

if [[ ! -d "${SEEDS_DIR}" ]]; then
  echo "Error: seeds directory not found: ${SEEDS_DIR}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required for JSON validation but was not found in PATH." >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}"

seeded_projects=()
skipped_projects=()
total_seeds=0

# Iterate every seeds/<name>/project.json deterministically.
shopt -s nullglob
for seed_file in "${SEEDS_DIR}"/*/project.json; do
  total_seeds=$((total_seeds + 1))

  seed_project_dir="$(dirname "${seed_file}")"
  project_name="$(basename "${seed_project_dir}")"

  # Validate the seed JSON before touching the target.
  if ! python3 -m json.tool "${seed_file}" >/dev/null 2>&1; then
    echo "Error: invalid JSON in seed file: ${seed_file}" >&2
    exit 1
  fi

  target_project_dir="${TARGET_DIR}/${project_name}"
  target_file="${target_project_dir}/project.json"

  if [[ -f "${target_file}" ]]; then
    skipped_projects+=("${project_name}")
    continue
  fi

  mkdir -p "${target_project_dir}"
  cp "${seed_file}" "${target_file}"
  seeded_projects+=("${project_name}")
done
shopt -u nullglob

if [[ "${total_seeds}" -eq 0 ]]; then
  echo "No seeds found in ${SEEDS_DIR}."
  exit 0
fi

seeded_count="${#seeded_projects[@]}"

echo "Seeded ${seeded_count} of ${total_seeds} projects."
if [[ "${seeded_count}" -gt 0 ]]; then
  echo "Created:"
  for name in "${seeded_projects[@]}"; do
    echo "  - ${name}"
  done
fi

if [[ "${#skipped_projects[@]}" -gt 0 ]]; then
  printf 'Skipped: ['
  printf '%s' "${skipped_projects[0]}"
  for ((i = 1; i < ${#skipped_projects[@]}; i++)); do
    printf ', %s' "${skipped_projects[$i]}"
  done
  printf ']\n'
else
  echo "Skipped: []"
fi

echo "Target: ${TARGET_DIR}"
exit 0

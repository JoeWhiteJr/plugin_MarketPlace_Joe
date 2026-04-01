#!/bin/bash
# SessionStart hook — environment detection and project context
# Runs when a new Claude Code session starts
# Adapted from Secrettestbot/claude_hooks for Joe's WSL2 stack

echo "=== Session Start ==="
echo ""

# ═══════════════════════════════════════
# PLATFORM
# ═══════════════════════════════════════
if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "Platform: WSL2"
else
  echo "Platform: $(uname -s)"
fi

# ═══════════════════════════════════════
# GIT REPOSITORY
# ═══════════════════════════════════════
if git rev-parse --git-dir >/dev/null 2>&1; then
  REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
  BRANCH=$(git branch --show-current 2>/dev/null)
  echo "Repo: $REPO_NAME ($BRANCH)"

  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    MOD=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    echo "  Uncommitted: ${MOD} modified, ${STAGED} staged"
  else
    echo "  Working tree clean"
  fi
  echo ""
fi

# ═══════════════════════════════════════
# TOOLS
# ═══════════════════════════════════════
echo "Tools:"

# Python
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1 | cut -d' ' -f2)
  PY_TOOLS=()
  command -v ruff &>/dev/null && PY_TOOLS+=("ruff")
  command -v mypy &>/dev/null && PY_TOOLS+=("mypy")
  command -v pytest &>/dev/null && PY_TOOLS+=("pytest")
  command -v black &>/dev/null && PY_TOOLS+=("black")
  TOOLS_STR=""
  [[ ${#PY_TOOLS[@]} -gt 0 ]] && TOOLS_STR=" [${PY_TOOLS[*]}]"
  echo "  Python $PY_VER$TOOLS_STR"
fi

# Node
if command -v node &>/dev/null; then
  NODE_VER=$(node --version)
  JS_TOOLS=()
  command -v tsc &>/dev/null && JS_TOOLS+=("tsc")
  command -v eslint &>/dev/null && JS_TOOLS+=("eslint")
  command -v vitest &>/dev/null && JS_TOOLS+=("vitest")
  command -v prettier &>/dev/null && JS_TOOLS+=("prettier")
  TOOLS_STR=""
  [[ ${#JS_TOOLS[@]} -gt 0 ]] && TOOLS_STR=" [${JS_TOOLS[*]}]"
  echo "  Node $NODE_VER$TOOLS_STR"
fi

# R
if command -v R &>/dev/null; then
  R_VER=$(R --version 2>/dev/null | head -1 | cut -d' ' -f3)
  echo "  R $R_VER"
fi

# Shell tools
command -v shellcheck &>/dev/null && echo "  ShellCheck $(shellcheck --version 2>/dev/null | grep '^version:' | cut -d' ' -f2)"
command -v gh &>/dev/null && echo "  gh $(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
command -v docker &>/dev/null && echo "  Docker $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"

echo ""

# ═══════════════════════════════════════
# PROJECT TYPE DETECTION
# ═══════════════════════════════════════
TYPES=()
[[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" ]] && TYPES+=("Python")
[[ -f "package.json" ]] && TYPES+=("Node")
[[ -f "tsconfig.json" ]] && TYPES+=("TypeScript")
[[ -f "Makefile" ]] && TYPES+=("Make")
[[ -f "docker-compose.yml" || -f "docker-compose.yaml" ]] && TYPES+=("Docker")
[[ -f "DESCRIPTION" ]] && TYPES+=("R")
[[ -f "Cargo.toml" ]] && TYPES+=("Rust")
[[ -f "go.mod" ]] && TYPES+=("Go")

if [[ ${#TYPES[@]} -gt 0 ]]; then
  echo "Project: ${TYPES[*]}"

  # Package manager detection
  [[ -f "package-lock.json" ]] && echo "  Package manager: npm"
  [[ -f "yarn.lock" ]] && echo "  Package manager: yarn"
  [[ -f "pnpm-lock.yaml" ]] && echo "  Package manager: pnpm"
fi

# ═══════════════════════════════════════
# SAVED PROJECT CHECK
# ═══════════════════════════════════════
PROJECTS_DIR="$HOME/.claude/workspace-projects"
if [[ -d "$PROJECTS_DIR" ]]; then
  PROJECT_COUNT=$(find "$PROJECTS_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$PROJECT_COUNT" -gt 0 ]]; then
    echo ""
    echo "Saved projects: $PROJECT_COUNT (use /workspace-tools:project-list to view)"
  fi
fi

echo ""
exit 0

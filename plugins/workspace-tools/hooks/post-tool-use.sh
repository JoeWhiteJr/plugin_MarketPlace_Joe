#!/bin/bash
# PostToolUse hook — automatic code validation after Edit/Write operations
# Adapted from Secrettestbot/claude_hooks for Joe's stack:
#   Python: ruff (not flake8), mypy, pytest
#   JS/TS: TypeScript compiler, ESLint
#   R: syntax check, lintr
#   WSL2-aware
#
# Exit codes:
#   0 = success (validation passed or not applicable)
#   2 = blocking error (feedback sent to Claude via stderr)

# Parse input JSON from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin).get('tool_input',{}); print(d.get('file_path', d.get('path','')))" 2>/dev/null)

# Only run on Edit/Write operations
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

FILE_PATH="$TOOL_INPUT"

# Skip if no file path or file doesn't exist
if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

EXTENSION="${FILE_PATH##*.}"
ERRORS_FOUND=false
FEEDBACK=""

# ═══════════════════════════════════════
# PYTHON VALIDATION
# ═══════════════════════════════════════
if [[ "$EXTENSION" == "py" ]]; then
  FEEDBACK="=== Python Validation: $(basename "$FILE_PATH") ===\n"

  # 1. Syntax check (always available)
  SYNTAX_OUT=$(python3 -m py_compile "$FILE_PATH" 2>&1)
  if [[ $? -ne 0 ]]; then
    FEEDBACK+="\nSYNTAX ERROR:\n$SYNTAX_OUT\n"
    ERRORS_FOUND=true
  else
    FEEDBACK+="Syntax OK\n"
  fi

  # 2. Ruff linting (preferred over flake8)
  if command -v ruff &>/dev/null; then
    RUFF_OUT=$(ruff check "$FILE_PATH" --select=E,F,W --ignore=E501 2>&1)
    if [[ $? -ne 0 ]]; then
      FEEDBACK+="\nRuff issues:\n$RUFF_OUT\n"
    else
      FEEDBACK+="Ruff OK\n"
    fi
  fi

  # 3. Type checking with mypy (if installed)
  if command -v mypy &>/dev/null; then
    MYPY_OUT=$(mypy "$FILE_PATH" --no-error-summary 2>&1)
    if [[ $? -ne 0 ]]; then
      FEEDBACK+="\nType issues:\n$MYPY_OUT\n"
    else
      FEEDBACK+="Types OK\n"
    fi
  fi

  # 4. Run tests if this is a test file
  if [[ "$FILE_PATH" == *"test_"* ]] || [[ "$FILE_PATH" == *"_test.py" ]]; then
    if command -v pytest &>/dev/null; then
      TEST_OUT=$(python3 -m pytest "$FILE_PATH" -x -q --tb=short 2>&1 | tail -15)
      if [[ $? -ne 0 ]]; then
        FEEDBACK+="\nTESTS FAILED:\n$TEST_OUT\n"
        ERRORS_FOUND=true
      else
        FEEDBACK+="Tests passed\n"
      fi
    fi
  fi

# ═══════════════════════════════════════
# TYPESCRIPT / JAVASCRIPT VALIDATION
# ═══════════════════════════════════════
elif [[ "$EXTENSION" == "ts" || "$EXTENSION" == "tsx" ]]; then
  FEEDBACK="=== TypeScript Validation: $(basename "$FILE_PATH") ===\n"

  # Find the project root (nearest tsconfig.json)
  DIR="$FILE_PATH"
  TSCONFIG_DIR=""
  while [[ "$DIR" != "/" ]]; do
    DIR=$(dirname "$DIR")
    if [[ -f "$DIR/tsconfig.json" ]]; then
      TSCONFIG_DIR="$DIR"
      break
    fi
  done

  # TypeScript compiler check (no emit)
  if [[ -n "$TSCONFIG_DIR" ]]; then
    if [[ -f "$TSCONFIG_DIR/node_modules/.bin/tsc" ]]; then
      TSC_OUT=$("$TSCONFIG_DIR/node_modules/.bin/tsc" --noEmit --pretty false 2>&1 | grep "$(basename "$FILE_PATH")" | head -10)
      if [[ -n "$TSC_OUT" ]]; then
        FEEDBACK+="\nTypeScript errors:\n$TSC_OUT\n"
        ERRORS_FOUND=true
      else
        FEEDBACK+="TypeScript OK\n"
      fi
    fi
  fi

  # ESLint check
  if [[ -n "$TSCONFIG_DIR" && -f "$TSCONFIG_DIR/node_modules/.bin/eslint" ]]; then
    ESLINT_OUT=$("$TSCONFIG_DIR/node_modules/.bin/eslint" "$FILE_PATH" --no-color 2>&1 | tail -10)
    if [[ $? -ne 0 ]]; then
      FEEDBACK+="\nESLint issues:\n$ESLINT_OUT\n"
    else
      FEEDBACK+="ESLint OK\n"
    fi
  fi

  # Run test if it's a test file
  if [[ "$FILE_PATH" == *".test."* || "$FILE_PATH" == *".spec."* || "$FILE_PATH" == *"__tests__"* ]]; then
    if [[ -n "$TSCONFIG_DIR" && -f "$TSCONFIG_DIR/node_modules/.bin/vitest" ]]; then
      TEST_OUT=$(cd "$TSCONFIG_DIR" && npx vitest run "$FILE_PATH" --reporter=verbose 2>&1 | tail -15)
      if [[ $? -ne 0 ]]; then
        FEEDBACK+="\nTests FAILED:\n$TEST_OUT\n"
        ERRORS_FOUND=true
      else
        FEEDBACK+="Tests passed\n"
      fi
    fi
  fi

elif [[ "$EXTENSION" == "js" || "$EXTENSION" == "jsx" ]]; then
  FEEDBACK="=== JavaScript Validation: $(basename "$FILE_PATH") ===\n"

  # Syntax check via Node
  NODE_OUT=$(node --check "$FILE_PATH" 2>&1)
  if [[ $? -ne 0 ]]; then
    FEEDBACK+="\nSyntax error:\n$NODE_OUT\n"
    ERRORS_FOUND=true
  else
    FEEDBACK+="Syntax OK\n"
  fi

# ═══════════════════════════════════════
# R VALIDATION
# ═══════════════════════════════════════
elif [[ "$EXTENSION" == "R" || "$EXTENSION" == "r" ]]; then
  FEEDBACK="=== R Validation: $(basename "$FILE_PATH") ===\n"

  # Syntax check
  R_OUT=$(Rscript -e "tryCatch(parse('$FILE_PATH'), error=function(e) { cat('ERROR:', e\$message); quit(status=1) })" 2>&1)
  if [[ $? -ne 0 ]]; then
    FEEDBACK+="\nSyntax error:\n$R_OUT\n"
    ERRORS_FOUND=true
  else
    FEEDBACK+="Syntax OK\n"
  fi

  # lintr
  if command -v Rscript &>/dev/null; then
    LINTR_OUT=$(Rscript -e "if(requireNamespace('lintr',quietly=TRUE)){lintr::lint('$FILE_PATH')}else{cat('skip')}" 2>&1)
    if [[ "$LINTR_OUT" != *"skip"* && -n "$LINTR_OUT" ]]; then
      FEEDBACK+="\nLint issues:\n$LINTR_OUT\n"
    fi
  fi

  # ML train/test split warning
  if grep -q "library(caret)\|library(randomForest)\|library(xgboost)\|library(tidymodels)" "$FILE_PATH"; then
    if ! grep -q "createDataPartition\|initial_split\|sample\|train_test_split" "$FILE_PATH"; then
      FEEDBACK+="\nWarning: ML code detected but no train/test split found.\n"
    fi
  fi

# ═══════════════════════════════════════
# SHELL SCRIPT VALIDATION
# ═══════════════════════════════════════
elif [[ "$EXTENSION" == "sh" || "$EXTENSION" == "bash" ]]; then
  FEEDBACK="=== Shell Validation: $(basename "$FILE_PATH") ===\n"

  # shellcheck
  if command -v shellcheck &>/dev/null; then
    SC_OUT=$(shellcheck -f gcc "$FILE_PATH" 2>&1 | head -10)
    if [[ $? -ne 0 && -n "$SC_OUT" ]]; then
      FEEDBACK+="\nShellCheck issues:\n$SC_OUT\n"
    else
      FEEDBACK+="ShellCheck OK\n"
    fi
  fi

else
  # Not a supported file type
  exit 0
fi

# Output feedback
if [[ "$ERRORS_FOUND" == true ]]; then
  echo -e "$FEEDBACK" >&2
  exit 2
else
  echo -e "$FEEDBACK"
  exit 0
fi

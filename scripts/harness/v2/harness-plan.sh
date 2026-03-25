#!/usr/bin/env bash
# Generate or find specs for a feature, prepare for execution
# v2: Uses Spec Kit (spec.md + plan.md + tasks.md) instead of prd.json
# v1 fallback: if no specs exist and harness-spec.sh fails, falls back to prd.json generation
# Usage: harness-plan.sh <project> "<description>"
# Exit codes: 0=success, 1=prereq, 2=claude fail, 3=validation fail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 2 ]]; then
  log_error "Usage: harness-plan.sh <project> \"<description>\""
  exit $EXIT_PREREQ
fi

PROJECT="$1"
DESCRIPTION="$2"
PROJECT_DIR=$(validate_project "$PROJECT")

# Detect issue
ISSUE_FLAG=""
if echo "$DESCRIPTION" | grep -qE '(issue\s*)?#[0-9]+'; then
  ISSUE_NUMBER=$(echo "$DESCRIPTION" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
  ISSUE_FLAG="--issue $ISSUE_NUMBER"
  log_info "Detected GitHub Issue #$ISSUE_NUMBER"
fi

# Health checks
command -v claude > /dev/null 2>&1 || { log_error "claude not found"; exit $EXIT_PREREQ; }
command -v gh > /dev/null 2>&1 || { log_error "gh not found"; exit $EXIT_PREREQ; }
gh auth status > /dev/null 2>&1 || { log_error "gh not authenticated"; exit $EXIT_PREREQ; }
mkdir -p "$LOGS_DIR"

# Check remote push access (non-fatal)
if ! git -C "$PROJECT_DIR" ls-remote --exit-code origin > /dev/null 2>&1; then
  log_warn "Cannot reach git remote — push may fail later"
fi

# Setup .harness/
mkdir -p "$PROJECT_DIR/.harness"
cp -n "$SCRIPT_DIR/templates/CLAUDE.md" "$PROJECT_DIR/.harness/CLAUDE.md" 2>/dev/null || true
cp -n "$SCRIPT_DIR/templates/AGENTS.md" "$PROJECT_DIR/.harness/AGENTS.md" 2>/dev/null || true

for entry in '.harness/' 'progress.txt'; do
  grep -qxF "$entry" "$PROJECT_DIR/.gitignore" 2>/dev/null || echo "$entry" >> "$PROJECT_DIR/.gitignore"
done

# Always generate a new spec for each feature
# Each call = new spec directory (specs/001-xxx/, specs/002-yyy/, etc.)
log_info "Generating specs via Spec Kit pipeline..."
SPEC_DIR=$("$SCRIPT_DIR/harness-spec.sh" "$PROJECT" "$DESCRIPTION" $ISSUE_FLAG) || true
if [[ -z "$SPEC_DIR" || ! -f "$SPEC_DIR/tasks.md" ]]; then
  log_error "Spec generation failed"
  exit $EXIT_CLAUDE_FAIL
fi

# Validate
for file in spec.md plan.md tasks.md; do
  if [[ ! -f "$SPEC_DIR/$file" ]]; then
    log_error "Missing $file in $SPEC_DIR"
    exit 3
  fi
done

TASK_COUNT=$(grep -c '^- \[ \] T[0-9]' "$SPEC_DIR/tasks.md" 2>/dev/null || echo 0)
if [[ "$TASK_COUNT" -eq 0 ]]; then
  log_error "tasks.md has no parseable tasks"
  exit 3
fi

# Save spec path for show-plan and run
echo "$SPEC_DIR" > "$PROJECT_DIR/.harness/spec-dir"

log_ok "Plan ready: $TASK_COUNT tasks in $(basename "$SPEC_DIR")/"

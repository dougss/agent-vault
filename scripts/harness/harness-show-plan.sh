#!/usr/bin/env bash
# Format plan for approval display
# v2: reads tasks.md (Spec Kit) via .harness/spec-dir
# v1 fallback: reads prd.json
# Usage: harness-show-plan.sh <project>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 1 ]]; then
  log_error "Usage: harness-show-plan.sh <project>"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
PROJECT_DIR=$(validate_project "$PROJECT")

# v2: read spec-dir pointer
if [[ -f "$PROJECT_DIR/.harness/spec-dir" ]]; then
  SPEC_DIR=$(cat "$PROJECT_DIR/.harness/spec-dir")
  TASKS_MD="$SPEC_DIR/tasks.md"

  if [[ ! -f "$TASKS_MD" ]]; then
    log_error "tasks.md not found: $TASKS_MD"
    exit $EXIT_PREREQ
  fi

  TASK_COUNT=$(grep -c '^- \[ \] T[0-9]' "$TASKS_MD" 2>/dev/null) || TASK_COUNT=0
  SPEC_NAME=$(basename "$SPEC_DIR")

  echo "📋 Plano: $SPEC_NAME — $PROJECT ($TASK_COUNT tasks)"
  echo ""
  # tasks.md is already human-readable — show it directly
  cat "$TASKS_MD"
  echo ""
  echo "Aprovar? (responda \"aprovado\", \"regenera\", ou peça ajustes)"
  exit 0
fi

# Fallback: v1 (prd.json)
PRD_PATH="$PROJECT_DIR/prd.json"
if [[ -f "$PRD_PATH" ]]; then
  validate_prd_schema "$PRD_PATH"
  FEATURE=$(jq -r '.feature' "$PRD_PATH")
  TASK_COUNT=$(jq '.tasks | length' "$PRD_PATH")
  COST=$(jq -r '.estimated_cost // "unknown"' "$PRD_PATH")

  echo "📋 Plano: $FEATURE — $PROJECT ($TASK_COUNT tasks, ~$COST)"
  echo ""
  jq -r '
    [.tasks[] | {id, title, deps: (.depends_on // [] | join(", ")), priority}]
    | sort_by(.priority)
    | to_entries[]
    | "\(.key + 1). [\(.value.id)] \(.value.title)\(if .value.deps != "" then " ← depende de \(.value.deps)" else "" end)"
  ' "$PRD_PATH"
  echo ""
  echo "Aprovar? (responda \"aprovado\", \"regenera\", ou peça ajustes)"
  exit 0
fi

log_error "No spec or prd.json found. Run harness-plan.sh first."
exit $EXIT_PREREQ

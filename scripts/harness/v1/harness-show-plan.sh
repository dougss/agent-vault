#!/usr/bin/env bash
# Read prd.json and output formatted plan for Telegram
# Usage: harness-show-plan.sh <project>
# Exit codes: 0=success, 1=prereq, 3=schema fail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 1 ]]; then
  log_error "Usage: harness-show-plan.sh <project>"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
PROJECT_DIR="$APPS_DIR/$PROJECT"
PRD_PATH="$PROJECT_DIR/prd.json"

if [[ ! -f "$PRD_PATH" ]]; then
  log_error "prd.json not found: $PRD_PATH"
  exit $EXIT_PREREQ
fi

validate_prd_schema "$PRD_PATH"

# Format output (stdout — agent copies this exactly)
FEATURE=$(jq -r '.feature' "$PRD_PATH")
PROJ=$(jq -r '.project' "$PRD_PATH")
COST=$(jq -r '.estimated_cost // "unknown"' "$PRD_PATH")
TASK_COUNT=$(jq '.tasks | length' "$PRD_PATH")

echo "📋 Plano: ${FEATURE} — ${PROJ} (${TASK_COUNT} tasks, ~${COST})"
echo ""

# List tasks with dependency info (all formatting done in jq — no fragile text pipelines)
jq -r '
  [.tasks[] | {id, title, deps: (.depends_on // [] | join(", ")), priority}]
  | sort_by(.priority)
  | to_entries[]
  | "\(.key + 1). [\(.value.id)] \(.value.title)\(if .value.deps != "" then " ← depende de \(.value.deps)" else "" end)"
' "$PRD_PATH"

echo ""
echo "Aprovar? (responda \"aprovado\", \"regenera\", ou peça ajustes)"

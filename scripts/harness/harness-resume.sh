#!/usr/bin/env bash
# Resume a stopped harness
# v2: re-invokes harness-run.sh (SDD skips completed tasks via [x] checkboxes)
# v1 fallback: uses harness-loop.sh.v1-backup if prd.json exists
# Usage: harness-resume.sh <project>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 1 ]]; then
  log_error "Usage: harness-resume.sh <project>"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
PROJECT_DIR=$(validate_project "$PROJECT")
LOCK_FILE="$PROJECT_DIR/.harness.lock"

# Check lockfile
if [[ -f "$LOCK_FILE" ]]; then
  PID=$(cat "$LOCK_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    log_error "Harness already running (PID $PID)"
    exit $EXIT_PREREQ
  fi
  rm -f "$LOCK_FILE"
fi

# v2: resume via harness-run.sh
if [[ -f "$PROJECT_DIR/.harness/spec-dir" ]]; then
  SPEC_DIR=$(cat "$PROJECT_DIR/.harness/spec-dir")
  if [[ -f "$SPEC_DIR/tasks.md" ]]; then
    PENDING=$(grep -c '^\- \[ \] T[0-9]' "$SPEC_DIR/tasks.md" 2>/dev/null) || PENDING=0
    if [[ "$PENDING" -eq 0 ]]; then
      echo "No pending tasks to resume"
      exit 0
    fi

    FEATURE_SLUG=$(basename "$SPEC_DIR" | sed 's/^[0-9]*-//')
    nohup "$SCRIPT_DIR/harness-run.sh" "$PROJECT" --spec-dir "$SPEC_DIR" \
      > "$HOME/server/logs/harness/${PROJECT}-${FEATURE_SLUG}-resume.log" 2>&1 &

    echo "🔄 Harness v2 resumed for $PROJECT ($PENDING pending tasks). PID: $!"
    exit 0
  fi
fi

# v1 fallback
PRD_PATH="$PROJECT_DIR/prd.json"
if [[ -f "$PRD_PATH" && -f "$SCRIPT_DIR/harness-loop.sh.v1-backup" ]]; then
  STATUS=$(jq -r '.status' "$PRD_PATH")
  if [[ "$STATUS" != "stopped" && "$STATUS" != "completed" ]]; then
    log_error "Cannot resume v1: status is '$STATUS'"
    exit $EXIT_PREREQ
  fi

  PENDING=$(jq '[.tasks[] | select(.status == "pending")] | length' "$PRD_PATH")
  if [[ "$PENDING" -eq 0 ]]; then
    echo "No pending tasks to resume"
    exit 0
  fi

  update_prd_status "$PRD_PATH" "approved"
  FEATURE_SLUG=$(jq -r '.feature_slug' "$PRD_PATH")
  nohup "$SCRIPT_DIR/harness-loop.sh.v1-backup" --run "$PROJECT" \
    > "$HOME/server/logs/harness/${PROJECT}-${FEATURE_SLUG}-resume.log" 2>&1 &
  echo "🔄 Harness v1 resumed for $PROJECT ($PENDING pending tasks). PID: $!"
  exit 0
fi

log_error "No spec or prd.json found for $PROJECT"
exit $EXIT_PREREQ

#!/usr/bin/env bash
# Resume a stopped harness
# Usage: harness-resume.sh <project>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 1 ]]; then
  log_error "Usage: harness-resume.sh <project>"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
PROJECT_DIR=$(validate_project "$PROJECT")
PRD_PATH="$PROJECT_DIR/prd.json"
LOCK_FILE="$PROJECT_DIR/.harness.lock"

if [[ ! -f "$PRD_PATH" ]]; then
  log_error "No prd.json found for $PROJECT"
  exit $EXIT_PREREQ
fi

STATUS=$(jq -r '.status' "$PRD_PATH")
if [[ "$STATUS" != "stopped" && "$STATUS" != "completed" ]]; then
  log_error "Cannot resume: status is '$STATUS' (expected 'stopped' or 'completed')"
  exit $EXIT_PREREQ
fi

# Check for remaining work
PENDING=$(jq '[.tasks[] | select(.status == "pending")] | length' "$PRD_PATH")
if [[ "$PENDING" -eq 0 ]]; then
  echo "No pending tasks to resume"
  exit 0
fi

if [[ -f "$LOCK_FILE" ]]; then
  PID=$(cat "$LOCK_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    log_error "Harness already running (PID $PID)"
    exit $EXIT_PREREQ
  fi
  rm -f "$LOCK_FILE"
fi

# Set status to approved for preflight
update_prd_status "$PRD_PATH" "approved"

# Run preflight
if ! "$SCRIPT_DIR/harness-loop.sh" --preflight "$PROJECT"; then
  log_error "Preflight failed — cannot resume"
  update_prd_status "$PRD_PATH" "stopped"
  exit $EXIT_PREREQ
fi

# Start loop
FEATURE_SLUG=$(jq -r '.feature_slug' "$PRD_PATH")
nohup "$SCRIPT_DIR/harness-loop.sh" --run "$PROJECT" \
  > "$HOME/server/logs/harness/${PROJECT}-${FEATURE_SLUG}-resume.log" 2>&1 &

echo "🔄 Harness resumed for $PROJECT ($PENDING pending tasks). PID: $!"

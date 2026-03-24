#!/usr/bin/env bash
# Stop a running harness
# Usage: harness-stop.sh <project>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
load_secrets

if [[ $# -lt 1 ]]; then
  # List running projects
  echo "Running harness processes:"
  found=0
  for dir in "$APPS_DIR"/*/; do
    lock="$dir/.harness.lock"
    if [[ -f "$lock" ]]; then
      pid=$(cat "$lock")
      project=$(basename "$dir")
      if kill -0 "$pid" 2>/dev/null; then
        echo "  $project (PID $pid)"
        found=1
      fi
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "  (none)"
  else
    log_error "Specify which project to stop"
  fi
  exit $EXIT_PREREQ
fi

PROJECT="$1"
PROJECT_DIR="$APPS_DIR/$PROJECT"
LOCK_FILE="$PROJECT_DIR/.harness.lock"
PRD_PATH="$PROJECT_DIR/prd.json"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
NOTIFY_CHANNEL="${HARNESS_NOTIFY_CHANNEL:-telegram}"

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "No harness running for $PROJECT"
  exit 0
fi

PID=$(cat "$LOCK_FILE")

if ! kill -0 "$PID" 2>/dev/null; then
  echo "Process $PID not running (stale lock). Cleaning up."
  rm -f "$LOCK_FILE"
  exit 0
fi

echo "Stopping harness for $PROJECT (PID $PID)..."

# Send SIGTERM
kill "$PID" 2>/dev/null

# Wait up to 10 seconds
for i in $(seq 1 10); do
  if ! kill -0 "$PID" 2>/dev/null; then
    break
  fi
  sleep 1
done

# Force kill if still running
if kill -0 "$PID" 2>/dev/null; then
  echo "Process didn't stop, sending SIGKILL..."
  kill -9 "$PID" 2>/dev/null
  sleep 1
fi

# Cleanup
rm -f "$LOCK_FILE"

if [[ -f "$PRD_PATH" ]]; then
  update_prd_status "$PRD_PATH" "stopped"
fi

if [[ -f "$PROGRESS_FILE" ]]; then
  echo "[$(date -Iseconds)] ⏹️ Harness parado manualmente" >> "$PROGRESS_FILE"
fi

"$SCRIPT_DIR/harness-notify.sh" --channel "$NOTIFY_CHANNEL" "⏹️ Harness parado manualmente: $PROJECT" 2>/dev/null || true

echo "✅ Harness stopped for $PROJECT"

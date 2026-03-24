#!/usr/bin/env bash
# Show harness status for a project or all projects
# Usage: harness-status.sh [<project>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -eq 0 ]]; then
  # List all projects with harness activity
  echo "📊 Harness Status Overview"
  echo ""
  found=0
  for dir in "$APPS_DIR"/*/; do
    project=$(basename "$dir")
    lock="$dir/.harness.lock"
    prd="$dir/prd.json"

    if [[ -f "$prd" ]]; then
      status=$(jq -r '.status // "unknown"' "$prd" 2>/dev/null)
      feature=$(jq -r '.feature // "?"' "$prd" 2>/dev/null)
      done_count=$(jq '[.tasks[] | select(.status == "done")] | length' "$prd" 2>/dev/null)
      total=$(jq '.tasks | length' "$prd" 2>/dev/null)

      running=""
      if [[ -f "$lock" ]]; then
        pid=$(cat "$lock")
        if kill -0 "$pid" 2>/dev/null; then
          running=" [RUNNING PID $pid]"
        else
          running=" [STALE LOCK]"
        fi
      fi

      echo "  $project: $feature — $status ($done_count/$total done)$running"
      found=1
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo "  (no projects with harness activity)"
  fi
else
  PROJECT="$1"
  PROJECT_DIR="$APPS_DIR/$PROJECT"
  PRD_PATH="$PROJECT_DIR/prd.json"
  LOCK_FILE="$PROJECT_DIR/.harness.lock"
  PROGRESS_FILE="$PROJECT_DIR/progress.txt"

  if [[ ! -f "$PRD_PATH" ]]; then
    echo "No harness activity for $PROJECT"
    exit 0
  fi

  echo "📊 Harness Status: $PROJECT"
  echo ""

  # Top-level status
  status=$(jq -r '.status' "$PRD_PATH")
  feature=$(jq -r '.feature' "$PRD_PATH")
  echo "Feature: $feature"
  echo "Status: $status"

  # Process status
  if [[ -f "$LOCK_FILE" ]]; then
    pid=$(cat "$LOCK_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "Process: RUNNING (PID $pid)"
    else
      echo "Process: STALE LOCK (PID $pid not running)"
    fi
  else
    echo "Process: not running"
  fi

  # Branch
  branch=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
  echo "Branch: $branch"

  # Task summary
  echo ""
  echo "Tasks:"
  done_count=$(jq '[.tasks[] | select(.status == "done")] | length' "$PRD_PATH")
  blocked_count=$(jq '[.tasks[] | select(.status == "blocked")] | length' "$PRD_PATH")
  skipped_count=$(jq '[.tasks[] | select(.status == "skipped")] | length' "$PRD_PATH")
  pending_count=$(jq '[.tasks[] | select(.status == "pending")] | length' "$PRD_PATH")
  in_progress=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "$PRD_PATH")
  total=$(jq '.tasks | length' "$PRD_PATH")
  echo "  ✅ Done: $done_count/$total"
  echo "  ❌ Blocked: $blocked_count"
  echo "  ⏭️ Skipped: $skipped_count"
  echo "  🔄 In Progress: $in_progress"
  echo "  ⏳ Pending: $pending_count"

  # Blocked details
  if [[ $blocked_count -gt 0 ]]; then
    echo ""
    echo "Blocked tasks:"
    jq -r '.tasks[] | select(.status == "blocked") | "  \(.id): \(.blocked_reason)"' "$PRD_PATH"
  fi

  # Recent progress
  if [[ -f "$PROGRESS_FILE" ]]; then
    echo ""
    echo "Recent progress:"
    tail -10 "$PROGRESS_FILE" | sed 's/^/  /'
  fi
fi

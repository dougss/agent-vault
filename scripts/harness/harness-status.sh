#!/usr/bin/env bash
# Show harness status for a project or all projects
# v2: reads tasks.md checkboxes + .harness/spec-dir
# v1 fallback: reads prd.json
# Usage: harness-status.sh [<project>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Helper: show status for one project directory
show_project_summary() {
  local proj_dir="$1"
  local project
  project=$(basename "$proj_dir")
  local lock="$proj_dir/.harness.lock"
  local running=""

  if [[ -f "$lock" ]]; then
    local pid
    pid=$(cat "$lock")
    if kill -0 "$pid" 2>/dev/null; then
      running=" [RUNNING PID $pid]"
    else
      running=" [STALE LOCK]"
    fi
  fi

  # v2: check tasks.md via spec-dir
  if [[ -f "$proj_dir/.harness/spec-dir" ]]; then
    local spec_dir
    spec_dir=$(cat "$proj_dir/.harness/spec-dir")
    if [[ -f "$spec_dir/tasks.md" ]]; then
      local done_count total_tasks
      done_count=$(grep -c '^\- \[x\] T[0-9]' "$spec_dir/tasks.md" 2>/dev/null) || done_count=0
      local pending_count
      pending_count=$(grep -c '^\- \[ \] T[0-9]' "$spec_dir/tasks.md" 2>/dev/null) || pending_count=0
      total_tasks=$((done_count + pending_count))
      echo "  $project: $(basename "$spec_dir") — $done_count/$total_tasks done (v2)$running"
      return 0
    fi
  fi

  # v1 fallback: prd.json
  local prd="$proj_dir/prd.json"
  if [[ -f "$prd" ]]; then
    local status feature done_count total
    status=$(jq -r '.status // "unknown"' "$prd" 2>/dev/null)
    feature=$(jq -r '.feature // "?"' "$prd" 2>/dev/null)
    done_count=$(jq '[.tasks[] | select(.status == "done")] | length' "$prd" 2>/dev/null)
    total=$(jq '.tasks | length' "$prd" 2>/dev/null)
    echo "  $project: $feature — $status ($done_count/$total done)$running"
    return 0
  fi

  return 1
}

if [[ $# -eq 0 ]]; then
  # List all projects
  echo "📊 Harness Status Overview"
  echo ""
  found=0
  for dir in "$APPS_DIR"/*/; do
    if show_project_summary "$dir"; then
      found=1
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo "  (no projects with harness activity)"
  fi
else
  PROJECT="$1"
  PROJECT_DIR="$APPS_DIR/$PROJECT"
  LOCK_FILE="$PROJECT_DIR/.harness.lock"
  PROGRESS_FILE="$PROJECT_DIR/progress.txt"

  echo "📊 Harness Status: $PROJECT"
  echo ""

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

  # v2: tasks.md
  if [[ -f "$PROJECT_DIR/.harness/spec-dir" ]]; then
    SPEC_DIR=$(cat "$PROJECT_DIR/.harness/spec-dir")
    TASKS_MD="$SPEC_DIR/tasks.md"
    if [[ -f "$TASKS_MD" ]]; then
      echo "Spec: $(basename "$SPEC_DIR")/"
      echo ""
      echo "Tasks:"
      DONE=$(grep -c '^\- \[x\] T[0-9]' "$TASKS_MD" 2>/dev/null) || DONE=0
      PENDING=$(grep -c '^\- \[ \] T[0-9]' "$TASKS_MD" 2>/dev/null) || PENDING=0
      TOTAL=$((DONE + PENDING))
      echo "  ✅ Done: $DONE/$TOTAL"
      echo "  ⏳ Pending: $PENDING"
    fi
  # v1 fallback
  elif [[ -f "$PROJECT_DIR/prd.json" ]]; then
    PRD_PATH="$PROJECT_DIR/prd.json"
    feature=$(jq -r '.feature' "$PRD_PATH")
    status=$(jq -r '.status' "$PRD_PATH")
    echo "Feature: $feature"
    echo "Status: $status"
    echo ""
    echo "Tasks:"
    echo "  ✅ Done: $(jq '[.tasks[] | select(.status == "done")] | length' "$PRD_PATH")/$( jq '.tasks | length' "$PRD_PATH")"
    echo "  ❌ Blocked: $(jq '[.tasks[] | select(.status == "blocked")] | length' "$PRD_PATH")"
    echo "  ⏳ Pending: $(jq '[.tasks[] | select(.status == "pending")] | length' "$PRD_PATH")"
  else
    echo "No harness activity for $PROJECT"
    exit 0
  fi

  # Recent progress
  if [[ -f "$PROGRESS_FILE" ]]; then
    echo ""
    echo "Recent progress:"
    tail -10 "$PROGRESS_FILE" | sed 's/^/  /'
  fi
fi

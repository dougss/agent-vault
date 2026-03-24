#!/usr/bin/env bash
# Shared functions for harness scripts

set -euo pipefail

# Exit codes
readonly EXIT_OK=0
readonly EXIT_PREREQ=1
readonly EXIT_CLAUDE_FAIL=2
readonly EXIT_SCHEMA_FAIL=3

# Paths
readonly APPS_DIR="$HOME/server/apps"
readonly LOGS_DIR="$HOME/server/logs/harness"
readonly SECRETS_ENV="$HOME/.openclaw/secrets/.env"
readonly HARNESS_WORKSPACE="$HOME/.openclaw/workspaces/harness-engineer"

# Colors (stderr only)
_red()    { echo -e "\033[0;31m$*\033[0m" >&2; }
_green()  { echo -e "\033[0;32m$*\033[0m" >&2; }
_yellow() { echo -e "\033[0;33m$*\033[0m" >&2; }

# Logging
log_info()  { echo "[$(date -Iseconds)] INFO: $*" >&2; }
log_error() { _red "[$(date -Iseconds)] ERROR: $*"; }
log_ok()    { _green "[$(date -Iseconds)] OK: $*"; }
log_warn()  { _yellow "[$(date -Iseconds)] WARN: $*"; }

# Load secrets
load_secrets() {
  if [[ -f "$SECRETS_ENV" ]]; then
    set -a
    source "$SECRETS_ENV"
    set +a
  else
    log_warn "Secrets file not found: $SECRETS_ENV"
  fi
}

# Validate project exists
validate_project() {
  local project="$1"
  local project_dir="$APPS_DIR/$project"

  if [[ ! -d "$project_dir" ]]; then
    log_error "Project directory not found: $project_dir"
    exit $EXIT_PREREQ
  fi

  if [[ ! -f "$project_dir/package.json" ]]; then
    log_error "No package.json in $project_dir"
    exit $EXIT_PREREQ
  fi

  if ! git -C "$project_dir" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_error "Not a git repository: $project_dir"
    exit $EXIT_PREREQ
  fi

  echo "$project_dir"
}

# Validate prd.json schema (minimal)
validate_prd_schema() {
  local prd_path="$1"

  if [[ ! -f "$prd_path" ]]; then
    log_error "prd.json not found: $prd_path"
    exit $EXIT_SCHEMA_FAIL
  fi

  # Check required top-level fields
  local missing=""
  for field in project feature feature_slug status tasks; do
    if ! jq -e ".$field" "$prd_path" > /dev/null 2>&1; then
      missing="$missing $field"
    fi
  done

  if [[ -n "$missing" ]]; then
    log_error "prd.json missing required fields:$missing"
    exit $EXIT_SCHEMA_FAIL
  fi

  # Check each task has required fields
  local task_errors
  task_errors=$(jq -r '.tasks[] | select(.id == null or .title == null or .status == null or .acceptance_criteria == null) | .id // "unknown"' "$prd_path" 2>/dev/null)
  if [[ -n "$task_errors" ]]; then
    log_error "Tasks with missing required fields: $task_errors"
    exit $EXIT_SCHEMA_FAIL
  fi

  log_ok "prd.json schema valid"
}

# Update prd.json status (top-level)
update_prd_status() {
  local prd_path="$1"
  local new_status="$2"
  local tmp
  tmp=$(mktemp)
  jq --arg s "$new_status" '.status = $s' "$prd_path" > "$tmp" && mv "$tmp" "$prd_path"
}

# Update task status in prd.json
update_task_status() {
  local prd_path="$1"
  local task_id="$2"
  local new_status="$3"
  local tmp
  tmp=$(mktemp)
  jq --arg id "$task_id" --arg s "$new_status" \
    '(.tasks[] | select(.id == $id)).status = $s' "$prd_path" > "$tmp" && mv "$tmp" "$prd_path"
}

# Update task retries in prd.json
increment_task_retries() {
  local prd_path="$1"
  local task_id="$2"
  local tmp
  tmp=$(mktemp)
  jq --arg id "$task_id" \
    '(.tasks[] | select(.id == $id)).retries += 1' "$prd_path" > "$tmp" && mv "$tmp" "$prd_path"
}

# Set task blocked_reason in prd.json
set_task_blocked_reason() {
  local prd_path="$1"
  local task_id="$2"
  local reason="$3"
  local tmp
  tmp=$(mktemp)
  jq --arg id "$task_id" --arg r "$reason" \
    '(.tasks[] | select(.id == $id)).blocked_reason = $r' "$prd_path" > "$tmp" && mv "$tmp" "$prd_path"
}

# Get task retries
get_task_retries() {
  local prd_path="$1"
  local task_id="$2"
  jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .retries // 0' "$prd_path"
}

# Get task timeout
get_task_timeout() {
  local prd_path="$1"
  local task_id="$2"
  jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .timeout_minutes // 20' "$prd_path"
}

# Detect package manager from lockfile
detect_pkg_manager() {
  local project_dir="$1"
  if [[ -f "$project_dir/bun.lockb" ]]; then
    echo "bun"
  elif [[ -f "$project_dir/pnpm-lock.yaml" ]]; then
    echo "pnpm"
  elif [[ -f "$project_dir/yarn.lock" ]]; then
    echo "yarn"
  else
    echo "npm"
  fi
}

# Get the runner command (npx, bunx, pnpm exec, yarn)
get_runner() {
  local pm="$1"
  case "$pm" in
    bun)  echo "bunx" ;;
    pnpm) echo "pnpm exec" ;;
    yarn) echo "yarn" ;;
    *)    echo "npx" ;;
  esac
}

# Stage files safely — add all, then reset dangerous paths
safe_git_stage() {
  local project_dir="$1"
  git -C "$project_dir" add -A
  git -C "$project_dir" reset -- \
    node_modules/ \
    .env* \
    .harness/ \
    progress.txt \
    2>/dev/null || true

  # Re-add whichever lockfile the project uses
  for lockfile in package-lock.json bun.lockb pnpm-lock.yaml yarn.lock; do
    if git -C "$project_dir" diff --name-only | grep -q "^${lockfile}$" 2>/dev/null; then
      git -C "$project_dir" add "$lockfile"
    fi
  done

  # Warn about unexpected files
  local suspicious
  suspicious=$(git -C "$project_dir" diff --cached --name-only | grep -E '(node_modules/|\.env|\.secret|\.key)' || true)
  if [[ -n "$suspicious" ]]; then
    log_warn "Suspicious files staged: $suspicious"
  fi
}

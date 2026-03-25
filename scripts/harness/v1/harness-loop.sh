#!/usr/bin/env bash
# Harness execution loop
# Usage:
#   harness-loop.sh --preflight <project>   (sync health check)
#   harness-loop.sh --run <project>          (execute loop, called via nohup)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
load_secrets

# --- Parse args ---
MODE=""
PROJECT=""

case "${1:-}" in
  --preflight) MODE="preflight"; PROJECT="${2:-}" ;;
  --run)       MODE="run";       PROJECT="${2:-}" ;;
  *)
    log_error "Usage: harness-loop.sh --preflight|--run <project>"
    exit $EXIT_PREREQ
    ;;
esac

if [[ -z "$PROJECT" ]]; then
  log_error "Project name required"
  exit $EXIT_PREREQ
fi

PROJECT_DIR=$(validate_project "$PROJECT")
PRD_PATH="$PROJECT_DIR/prd.json"
LOCK_FILE="$PROJECT_DIR/.harness.lock"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
TASK_NOTES="$PROJECT_DIR/.harness/task-notes.txt"

CLAUDE_MODEL="${HARNESS_CLAUDE_MODEL:-claude-sonnet-4-6}"
MAX_BLOCKED="${HARNESS_MAX_BLOCKED:-3}"
NOTIFY_CHANNEL="${HARNESS_NOTIFY_CHANNEL:-telegram}"

notify() {
  "$SCRIPT_DIR/harness-notify.sh" --channel "$NOTIFY_CHANNEL" "$1" 2>/dev/null || true
}

# ===== PREFLIGHT =====
preflight() {
  local errors=0

  # Check tools
  for cmd in claude gh gtimeout jq python3; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
      log_error "$cmd not found in PATH"
      errors=$((errors + 1))
    fi
  done

  # gh auth
  if ! gh auth status > /dev/null 2>&1; then
    log_error "gh not authenticated"
    errors=$((errors + 1))
  fi

  # Claude Code auth (OAuth token refresh)
  if ! echo "ok" | claude -p --max-turns 1 > /dev/null 2>&1; then
    log_error "Claude Code not authenticated (token may have expired — run: claude auth login)"
    errors=$((errors + 1))
  fi

  # Logs dir
  mkdir -p "$LOGS_DIR"
  if [[ ! -w "$LOGS_DIR" ]]; then
    log_error "Logs dir not writable: $LOGS_DIR"
    errors=$((errors + 1))
  fi

  # Git config
  if [[ -z "$(git -C "$PROJECT_DIR" config user.name 2>/dev/null)" ]]; then
    log_error "git user.name not set"
    errors=$((errors + 1))
  fi

  # prd.json
  if [[ ! -f "$PRD_PATH" ]]; then
    log_error "prd.json not found"
    errors=$((errors + 1))
  else
    local status
    status=$(jq -r '.status' "$PRD_PATH" 2>/dev/null)
    if [[ "$status" != "approved" ]]; then
      log_error "prd.json status is '$status', expected 'approved'"
      errors=$((errors + 1))
    fi
  fi

  # Lockfile
  if [[ -f "$LOCK_FILE" ]]; then
    local pid
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
      log_error "Harness already running (PID $pid)"
      errors=$((errors + 1))
    else
      log_warn "Stale lockfile found (PID $pid not running), removing"
      rm -f "$LOCK_FILE"
    fi
  fi

  # Remote access
  if ! git -C "$PROJECT_DIR" ls-remote --exit-code origin > /dev/null 2>&1; then
    log_warn "Cannot reach git remote — push may fail"
  fi

  if [[ $errors -gt 0 ]]; then
    log_error "Preflight failed with $errors error(s)"
    exit $EXIT_PREREQ
  fi

  log_ok "Preflight passed"
  exit $EXIT_OK
}

# ===== CLEANUP (trap) =====
cleanup() {
  local exit_code=$?
  if [[ -f "$LOCK_FILE" ]]; then
    rm -f "$LOCK_FILE"
    log_info "Lockfile removed"
  fi
  if [[ $exit_code -ne 0 ]]; then
    echo "[$(date -Iseconds)] 💥 Harness crashed (exit $exit_code)" >> "$PROGRESS_FILE" 2>/dev/null
    notify "💥 Harness crashed for $PROJECT (exit $exit_code). Check logs: $LOGS_DIR"
    update_prd_status "$PRD_PATH" "stopped"
  fi
}

# ===== RUN =====
run_loop() {
  trap cleanup EXIT

  # Create lockfile
  echo $$ > "$LOCK_FILE"
  log_info "Lockfile created (PID $$)"

  # Update status
  update_prd_status "$PRD_PATH" "running"

  # Detect package manager
  local pkg_manager runner
  pkg_manager=$(detect_pkg_manager "$PROJECT_DIR")
  runner=$(get_runner "$pkg_manager")
  log_info "Package manager: $pkg_manager (runner: $runner)"

  # Get feature slug for branch name
  local feature_slug
  feature_slug=$(jq -r '.feature_slug' "$PRD_PATH")
  local branch_name="harness/${feature_slug}"

  # Create branch (if not on one)
  local current_branch
  current_branch=$(git -C "$PROJECT_DIR" branch --show-current)
  if [[ "$current_branch" != "$branch_name" ]]; then
    git -C "$PROJECT_DIR" checkout -b "$branch_name" 2>/dev/null || \
      git -C "$PROJECT_DIR" checkout "$branch_name"
    log_info "On branch: $branch_name"
  fi

  # Safety: abort if still on main/master (branch creation failed silently)
  current_branch=$(git -C "$PROJECT_DIR" branch --show-current)
  if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    log_error "ABORT: still on $current_branch after branch creation. Refusing to commit to protected branch."
    notify "❌ Harness abortou ($PROJECT): falha ao criar branch, recusando commitar no $current_branch"
    exit $EXIT_PREREQ
  fi

  # Ensure .harness/ directory exists (templates may not be copied yet)
  mkdir -p "$PROJECT_DIR/.harness"

  # Ensure .harness/ and progress.txt in .gitignore
  for entry in '.harness/' 'progress.txt'; do
    if ! grep -qxF "$entry" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
      echo "$entry" >> "$PROJECT_DIR/.gitignore"
    fi
  done

  # Initialize progress.txt
  local feature
  feature=$(jq -r '.feature' "$PRD_PATH")
  local task_count
  task_count=$(jq '.tasks | length' "$PRD_PATH")

  cat > "$PROGRESS_FILE" << EOF
# Harness Progress Log
# Project: $PROJECT
# Feature: $feature
# Branch: $branch_name
# Started: $(date -Iseconds)

[$(date -Iseconds)] 🚀 Harness iniciado. $task_count tasks no prd.json.
EOF

  notify "🚀 Harness iniciado: $feature ($PROJECT). $task_count tasks."

  local done_count=0
  local blocked_consecutive=0

  # ===== MAIN LOOP =====
  # Re-read prd.json each iteration to get next pending task (avoids subshell issues)
  while true; do
    # Get fresh task order from prd.json
    local task_order
    task_order=$(python3 "$SCRIPT_DIR/lib/topo-sort.py" "$PRD_PATH")

    # Find next executable task
    local task_id=""
    local task_action=""
    while IFS= read -r task_entry; do
      local entry_id entry_action entry_reason
      entry_id=$(echo "$task_entry" | jq -r '.id')
      entry_action=$(echo "$task_entry" | jq -r '.action')
      entry_reason=$(echo "$task_entry" | jq -r '.reason // empty')

      if [[ "$entry_action" == "skip" ]]; then
        # Mark skipped tasks (dependency blocked)
        local current_status
        current_status=$(jq -r --arg id "$entry_id" '.tasks[] | select(.id == $id) | .status' "$PRD_PATH")
        if [[ "$current_status" == "pending" && "$entry_reason" == *"depends on blocked"* ]]; then
          update_task_status "$PRD_PATH" "$entry_id" "skipped"
          echo "[$(date -Iseconds)] ⏭️ $entry_id skipped ($entry_reason)" >> "$PROGRESS_FILE"
          log_info "Skipping $entry_id: $entry_reason"
        fi
        continue
      fi

      if [[ "$entry_action" == "execute" ]]; then
        task_id="$entry_id"
        task_action="execute"
        break
      fi
    done < <(echo "$task_order" | jq -c '.[]')

    # No more tasks to execute
    if [[ -z "$task_id" ]]; then
      break
    fi

    # Get task details
    local task_title task_desc task_criteria task_files task_timeout
    task_title=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .title' "$PRD_PATH")
    task_desc=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .description' "$PRD_PATH")
    task_criteria=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .acceptance_criteria | join("\n- ")' "$PRD_PATH")
    task_files=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .suggested_files | join(", ")' "$PRD_PATH")
    task_timeout=$(get_task_timeout "$PRD_PATH" "$task_id")

    log_info "Starting: $task_id — $task_title"
    update_task_status "$PRD_PATH" "$task_id" "in_progress"

    # Get context
    local progress_context
    progress_context=$(tail -20 "$PROGRESS_FILE" 2>/dev/null || echo "(no prior context)")

    # Check if retry
    local retries
    retries=$(get_task_retries "$PRD_PATH" "$task_id")
    local retry_context=""
    if [[ $retries -gt 0 ]] && [[ -f "$PROJECT_DIR/.harness/last-error.txt" ]]; then
      retry_context="
PREVIOUS ATTEMPT FAILED. Error:
$(cat "$PROJECT_DIR/.harness/last-error.txt")
Fix the problem without modifying existing tests."
    fi

    # Build prompt
    local prompt="You are implementing ONE specific task in a TypeScript/Node/React project.

Task: ${task_id} — ${task_title}
Description: ${task_desc}

Acceptance Criteria:
- ${task_criteria}

Suggested files: ${task_files}
(You can create additional files if necessary)

Recent context:
${progress_context}
${retry_context}

Rules:
1. Read .harness/AGENTS.md for complete rules
2. Implement ONLY this task, nothing else
3. Write tests BEFORE implementation (TDD)
4. Run: tsc --noEmit && $runner vitest run
5. Do NOT run git add, git commit, or git push (the orchestrator handles git)
6. Do NOT modify existing tests to make them pass
7. Do NOT use placeholder implementations (TODO, throw Error('not implemented'))
8. If you install dependencies, record in .harness/task-notes.txt
9. To communicate with the orchestrator, write to .harness/task-notes.txt
10. Do NOT write to progress.txt (the script manages that file)"

    # Warm-up: ensure OAuth token is fresh before each task
    if ! echo "ok" | claude -p --max-turns 1 > /dev/null 2>&1; then
      log_error "Claude Code auth failed before $task_id — token expired?"
      echo "[$(date -Iseconds)] ❌ $task_id: Claude auth failed" >> "$PROGRESS_FILE"
      notify "❌ Harness parado ($PROJECT): Claude Code auth expirou. Rode: claude auth login"
      update_prd_status "$PRD_PATH" "stopped"
      rm -f "$LOCK_FILE"
      trap - EXIT
      exit 1
    fi

    # Execute Claude Code with timeout — cd to project dir
    local claude_exit=0
    (cd "$PROJECT_DIR" && echo "$prompt" | gtimeout "${task_timeout}m" claude -p \
      --model "$CLAUDE_MODEL" \
      --allowedTools "Read Glob Grep Bash Edit Write") \
      > "$LOGS_DIR/task-${PROJECT}-${task_id}.log" 2>&1 || claude_exit=$?

    # Read task notes (if any)
    if [[ -f "$TASK_NOTES" ]]; then
      local notes
      notes=$(cat "$TASK_NOTES")
      echo "[$(date -Iseconds)] 📝 $task_id notes: $notes" >> "$PROGRESS_FILE"
      rm -f "$TASK_NOTES"
    fi

    # Verify (in subshell to avoid cd side effects)
    local verify_ok=true
    local verify_errors=""

    if ! (cd "$PROJECT_DIR" && $runner tsc --noEmit) > /tmp/harness-tsc.log 2>&1; then
      verify_ok=false
      verify_errors="TypeScript errors:\n$(tail -20 /tmp/harness-tsc.log)"
    fi

    if ! (cd "$PROJECT_DIR" && $runner vitest run --reporter=dot) > /tmp/harness-test.log 2>&1; then
      verify_ok=false
      verify_errors="${verify_errors}\nTest failures:\n$(tail -20 /tmp/harness-test.log)"
    fi

    if ! (cd "$PROJECT_DIR" && $runner eslint . --quiet) > /tmp/harness-lint.log 2>&1; then
      verify_ok=false
      verify_errors="${verify_errors}\nLint errors:\n$(tail -20 /tmp/harness-lint.log)"
    fi

    if [[ "$verify_ok" == true ]]; then
      # Stage and commit (uses safe_git_stage from common.sh)
      safe_git_stage "$PROJECT_DIR"
      git -C "$PROJECT_DIR" commit -m "feat(${task_id}): ${task_title}" --allow-empty 2>/dev/null || true

      update_task_status "$PRD_PATH" "$task_id" "done"
      echo "[$(date -Iseconds)] ✅ $task_id: $task_title" >> "$PROGRESS_FILE"
      log_ok "$task_id completed"

      done_count=$((done_count + 1))
      blocked_consecutive=0

      # Checkpoint notification every 3 tasks
      if [[ $((done_count % 3)) -eq 0 ]]; then
        notify "📊 $done_count/$task_count tasks concluídas ($PROJECT: $feature)"
      fi
    else
      # Save error for retry context
      mkdir -p "$PROJECT_DIR/.harness"
      echo -e "$verify_errors" > "$PROJECT_DIR/.harness/last-error.txt"
      increment_task_retries "$PRD_PATH" "$task_id"
      retries=$((retries + 1))

      if [[ $retries -lt 3 ]]; then
        log_warn "$task_id failed verification (attempt $retries/3). Retrying..."
        echo "[$(date -Iseconds)] 🔄 $task_id retry $retries/3" >> "$PROGRESS_FILE"

        # Reset changes for retry (preserve prd.json — has retry counters)
        cp "$PRD_PATH" /tmp/harness-prd-backup.json
        git -C "$PROJECT_DIR" checkout -- . 2>/dev/null || true
        git -C "$PROJECT_DIR" clean -fd -- src/ tests/ 2>/dev/null || true
        cp /tmp/harness-prd-backup.json "$PRD_PATH"

        # Set back to pending — next iteration of while true will re-read prd.json
        update_task_status "$PRD_PATH" "$task_id" "pending"
      else
        update_task_status "$PRD_PATH" "$task_id" "blocked"
        set_task_blocked_reason "$PRD_PATH" "$task_id" "$(echo -e "$verify_errors" | head -5)"
        echo "[$(date -Iseconds)] ❌ $task_id: Blocked (3 attempts). Error: $(echo -e "$verify_errors" | head -3)" >> "$PROGRESS_FILE"
        notify "⚠️ $task_id blocked ($PROJECT): $(echo -e "$verify_errors" | head -2)"
        log_error "$task_id blocked after 3 attempts"

        blocked_consecutive=$((blocked_consecutive + 1))

        if [[ $blocked_consecutive -ge $MAX_BLOCKED ]]; then
          echo "[$(date -Iseconds)] ⛔ Harness parado: $blocked_consecutive tasks consecutivas bloqueadas" >> "$PROGRESS_FILE"
          notify "⛔ Harness parado ($PROJECT): $blocked_consecutive tasks consecutivas bloqueadas. $done_count/$task_count concluídas."
          update_prd_status "$PRD_PATH" "stopped"
          rm -f "$LOCK_FILE"
          trap - EXIT
          exit 0
        fi
      fi
    fi

    # Cool-down
    sleep 3
  done

  # --- Finalization ---
  log_info "All tasks processed. Running final verification..."

  local final_ok=true
  (cd "$PROJECT_DIR" && $runner tsc --noEmit) > /dev/null 2>&1 || final_ok=false
  (cd "$PROJECT_DIR" && $runner vitest run) > /dev/null 2>&1 || final_ok=false
  (cd "$PROJECT_DIR" && $runner eslint . --quiet) > /dev/null 2>&1 || final_ok=false

  if [[ "$final_ok" == false ]]; then
    log_warn "Final verification had issues but proceeding with PR"
    echo "[$(date -Iseconds)] ⚠️ Final verification had issues" >> "$PROGRESS_FILE"
  fi

  # Push and create PR
  git -C "$PROJECT_DIR" push -u origin "$branch_name" 2>/dev/null

  local done_tasks blocked_tasks skipped_tasks pending_tasks
  done_tasks=$(jq '[.tasks[] | select(.status == "done")] | length' "$PRD_PATH")
  blocked_tasks=$(jq '[.tasks[] | select(.status == "blocked")] | length' "$PRD_PATH")
  skipped_tasks=$(jq '[.tasks[] | select(.status == "skipped")] | length' "$PRD_PATH")
  pending_tasks=$(jq '[.tasks[] | select(.status == "pending")] | length' "$PRD_PATH")

  # Check if prd.json has an issue reference
  local closes_line=""
  local issue_ref
  issue_ref=$(jq -r '.description // ""' "$PRD_PATH" | grep -oE '#[0-9]+' | head -1)
  if [[ -n "$issue_ref" ]]; then
    closes_line="
Closes $issue_ref"
  fi

  local pr_body="## Summary
- ✅ Done: $done_tasks/$task_count
- ❌ Blocked: $blocked_tasks
- ⏭️ Skipped: $skipped_tasks
- ⏳ Pending: $pending_tasks
$closes_line

## Progress Log
\`\`\`
$(cat "$PROGRESS_FILE")
\`\`\`

---
🤖 Generated by Harness Engineer"

  local feature_title
  feature_title=$(jq -r '.feature' "$PRD_PATH")
  local pr_url
  pr_url=$(cd "$PROJECT_DIR" && gh pr create \
    --title "feat: $feature_title" \
    --body "$pr_body" \
    --head "$branch_name" 2>/dev/null || echo "PR_CREATION_FAILED")

  if [[ "$pr_url" == "PR_CREATION_FAILED" ]]; then
    log_error "Failed to create PR"
    echo "[$(date -Iseconds)] ❌ PR creation failed" >> "$PROGRESS_FILE"
    notify "⚠️ Harness concluído ($PROJECT) mas PR falhou. $done_tasks/$task_count tasks. Branch: $branch_name"
  else
    echo "[$(date -Iseconds)] ✅ PR criado: $pr_url" >> "$PROGRESS_FILE"
    log_ok "PR created: $pr_url"

    # --- Automated Review ---
    local pr_number
    pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
    if [[ -n "$pr_number" ]]; then
      log_info "Starting automated review for PR #$pr_number..."
      echo "[$(date -Iseconds)] 🔍 Iniciando review automático do PR #$pr_number" >> "$PROGRESS_FILE"

      if "$SCRIPT_DIR/harness-review.sh" "$PROJECT" "$pr_number"; then
        echo "[$(date -Iseconds)] ✅ Review aprovado — PR pronto para merge" >> "$PROGRESS_FILE"
        notify "✅ Harness concluído + review aprovado: $feature_title ($PROJECT). $done_tasks/$task_count tasks. PR: $pr_url"
      else
        echo "[$(date -Iseconds)] ⚠️ Review encontrou issues — ver PR para detalhes" >> "$PROGRESS_FILE"
        notify "⚠️ Harness concluído ($PROJECT). $done_tasks/$task_count tasks. PR precisa de review: $pr_url"
      fi
    else
      notify "✅ Harness concluído: $feature_title ($PROJECT). $done_tasks/$task_count tasks. PR: $pr_url"
    fi
  fi

  update_prd_status "$PRD_PATH" "completed"
  rm -f "$LOCK_FILE"
  trap - EXIT
}

# --- Main ---
case "$MODE" in
  preflight) preflight ;;
  run) run_loop ;;
esac

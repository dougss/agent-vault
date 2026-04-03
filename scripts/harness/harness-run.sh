#!/usr/bin/env bash
# Execute implementation via Claude Code SDD + Ralph Loop
# Usage: harness-run.sh <project> [--spec-dir <path>]
# Exit codes: 0=success, 1=prereq, 2=claude fail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
load_secrets

if [[ $# -lt 1 ]]; then
  log_error "Usage: harness-run.sh <project> [--spec-dir <path>]"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
shift

SPEC_DIR_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec-dir) SPEC_DIR_OVERRIDE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

PROJECT_DIR=$(validate_project "$PROJECT")
LOCK_FILE="$PROJECT_DIR/.harness.lock"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
CLAUDE_MODEL="${HARNESS_CLAUDE_MODEL:-claude-sonnet-4-6}"
MAX_ITERATIONS="${HARNESS_MAX_ITERATIONS:-50}"
NOTIFY_CHANNEL="${HARNESS_NOTIFY_CHANNEL:-telegram}"

notify() {
  "$SCRIPT_DIR/harness-notify.sh" --channel "$NOTIFY_CHANNEL" "$1" 2>/dev/null || true
}

# --- Preflight ---
for cmd in claude gh gtimeout jq python3; do
  command -v "$cmd" > /dev/null 2>&1 || { log_error "$cmd not found"; exit $EXIT_PREREQ; }
done
gh auth status > /dev/null 2>&1 || { log_error "gh not authenticated"; exit $EXIT_PREREQ; }
if ! echo "ok" | claude -p --max-turns 1 > /dev/null 2>&1; then
  log_error "Claude Code auth failed"; exit $EXIT_PREREQ
fi
mkdir -p "$LOGS_DIR"

# --- Find spec ---
# Priority: --spec-dir flag > .harness/spec-dir (written by harness-plan.sh)
# No guessing — harness-plan.sh MUST run first to set the spec-dir pointer
SPEC_DIR=""
if [[ -n "$SPEC_DIR_OVERRIDE" ]]; then
  SPEC_DIR="$SPEC_DIR_OVERRIDE"
elif [[ -f "$PROJECT_DIR/.harness/spec-dir" ]]; then
  SPEC_DIR=$(cat "$PROJECT_DIR/.harness/spec-dir")
fi

if [[ -z "$SPEC_DIR" || ! -f "$SPEC_DIR/tasks.md" ]]; then
  log_error "No tasks.md found. Run harness-plan.sh first."
  exit $EXIT_PREREQ
fi

TASKS_MD="$SPEC_DIR/tasks.md"
TASK_COUNT=$(grep -c '^- \[ \] T[0-9]' "$TASKS_MD" 2>/dev/null) || TASK_COUNT=0
FEATURE_SLUG=$(basename "$SPEC_DIR" | sed 's/^[0-9]*-//')
BRANCH_NAME="harness/${FEATURE_SLUG}"

# --- Lockfile ---
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    log_error "Harness already running (PID $LOCK_PID)"
    exit $EXIT_PREREQ
  fi
  log_warn "Stale lockfile (PID $LOCK_PID not running), removing"
  rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

# --- Cleanup trap ---
cleanup() {
  local exit_code=$?
  rm -f "$LOCK_FILE" 2>/dev/null
  if [[ $exit_code -ne 0 ]]; then
    echo "[$(date -Iseconds)] Harness crashed (exit $exit_code)" >> "$PROGRESS_FILE" 2>/dev/null
    notify "Harness crashed ($PROJECT) exit $exit_code"
  fi
}
trap cleanup EXIT

# --- Sync main and create branch ---
log_info "Syncing main before starting..."
DEFAULT_BRANCH=$(git -C "$PROJECT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || DEFAULT_BRANCH="main"
git -C "$PROJECT_DIR" checkout "$DEFAULT_BRANCH" 2>/dev/null || true
git -C "$PROJECT_DIR" pull --ff-only origin "$DEFAULT_BRANCH" 2>/dev/null || {
  log_error "Failed to pull latest $DEFAULT_BRANCH"
  notify "Harness abortou ($PROJECT): git pull falhou"
  exit $EXIT_PREREQ
}
log_ok "Main synced"

# Create feature branch from latest main
if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
  log_warn "Branch $BRANCH_NAME already exists — rebasing onto $DEFAULT_BRANCH"
  git -C "$PROJECT_DIR" checkout "$BRANCH_NAME"
  git -C "$PROJECT_DIR" rebase "$DEFAULT_BRANCH" 2>/dev/null || {
    git -C "$PROJECT_DIR" rebase --abort 2>/dev/null
    log_error "Rebase failed — aborting"
    notify "Harness abortou ($PROJECT): rebase falhou para $BRANCH_NAME"
    exit $EXIT_PREREQ
  }
else
  git -C "$PROJECT_DIR" checkout -b "$BRANCH_NAME"
fi

CURRENT=$(git -C "$PROJECT_DIR" branch --show-current)
if [[ "$CURRENT" == "main" || "$CURRENT" == "master" ]]; then
  log_error "ABORT: still on $CURRENT"
  notify "Harness abortou ($PROJECT): still on $CURRENT"
  exit $EXIT_PREREQ
fi

# --- Setup ---
mkdir -p "$PROJECT_DIR/.harness"
for entry in '.harness/' '.harness.lock' 'progress.txt'; do
  grep -qxF "$entry" "$PROJECT_DIR/.gitignore" 2>/dev/null || echo "$entry" >> "$PROJECT_DIR/.gitignore"
done
cp -n "$SCRIPT_DIR/templates/CLAUDE.md" "$PROJECT_DIR/.harness/CLAUDE.md" 2>/dev/null || true
cp -n "$SCRIPT_DIR/templates/AGENTS.md" "$PROJECT_DIR/.harness/AGENTS.md" 2>/dev/null || true

# --- Progress ---
cat > "$PROGRESS_FILE" << EOF
# Harness v2 Progress
# Project: $PROJECT | Feature: $FEATURE_SLUG | Branch: $BRANCH_NAME
# Started: $(date -Iseconds) | Tasks: $TASK_COUNT
EOF

notify "Harness v2 iniciado: $FEATURE_SLUG ($PROJECT). $TASK_COUNT tasks."
log_info "Starting SDD execution: $TASK_COUNT tasks from $SPEC_DIR"

# --- Detect package manager ---
PKG_MANAGER=$(detect_pkg_manager "$PROJECT_DIR")
RUNNER=$(get_runner "$PKG_MANAGER")

# --- Detect tsconfig for typecheck ---
if [[ -f "$PROJECT_DIR/tsconfig.app.json" ]]; then
  TSCONFIG="tsconfig.app.json"
elif [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then
  TSCONFIG="tsconfig.json"
else
  TSCONFIG=""
fi

# --- Build the SDD prompt ---
SPEC_REL=$(python3 -c "import os; print(os.path.relpath('$SPEC_DIR', '$PROJECT_DIR'))")

IMPL_PROMPT="You are implementing a feature task-by-task with commits.

## Context
Project: $PROJECT | Branch: $BRANCH_NAME | Runner: $RUNNER

## Read these files FIRST
1. $SPEC_REL/spec.md — requirements
2. $SPEC_REL/plan.md — architecture
3. $SPEC_REL/tasks.md — task list
4. .harness/AGENTS.md — rules

## CRITICAL WORKFLOW — follow this EXACTLY for each task

Go through tasks.md from top to bottom. For EACH unchecked task (- [ ]):

### Step 1: Implement
- Write tests FIRST (TDD), then implementation
- Follow the spec and plan

### Step 2: Verify
Run: \`$RUNNER tsc --noEmit${TSCONFIG:+ -p $TSCONFIG} && $RUNNER vitest run && $RUNNER eslint . --quiet\`
If verification fails, fix and re-verify.

### Step 3: Commit (MANDATORY before next task)
Run these EXACT commands:
\`\`\`bash
git add -A
git reset -- .harness/ progress.txt node_modules/ .env*
git commit -m \"feat(TASK_ID): short description\"
\`\`\`
YOU MUST COMMIT before moving to the next task. No exceptions.

### Step 4: Update tasks.md
Change \`- [ ] TXXX\` to \`- [x] TXXX\` for the completed task.

### Step 5: Next task
Move to the next unchecked task. Repeat Steps 1-4.

## Rules
- ONE task at a time. Implement → verify → commit → update → next.
- Skip tasks already marked [x].
- Do NOT implement multiple tasks before committing.
- Do NOT push (the orchestrator handles push).
- If stuck after 3 attempts on a task, write BLOCKED in progress.txt and skip it.

## When done
After all tasks are checked [x] or blocked, write a summary to progress.txt."

# --- Execute with retry ---
MAX_TIMEOUT_MIN="${HARNESS_MAX_TIMEOUT_MINUTES:-360}"
MAX_RETRIES="${HARNESS_MAX_RETRIES:-3}"
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_RETRIES ]]; do
  ATTEMPT=$((ATTEMPT + 1))

  # Count pending tasks before this attempt
  PENDING_BEFORE=$(grep -c '^\- \[ \] T[0-9]' "$TASKS_MD" 2>/dev/null) || PENDING_BEFORE=0

  if [[ $PENDING_BEFORE -eq 0 ]]; then
    log_info "All tasks already completed"
    break
  fi

  log_info "Attempt $ATTEMPT/$MAX_RETRIES — $PENDING_BEFORE tasks pending..."

  # Build context for retries: show what was already done
  RETRY_CONTEXT=""
  if [[ $ATTEMPT -gt 1 ]]; then
    DONE_SO_FAR=$(grep -c '^\- \[x\] T[0-9]' "$TASKS_MD" 2>/dev/null) || DONE_SO_FAR=0
    CHANGED_FILES=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | head -20)
    UNTRACKED=$(git -C "$PROJECT_DIR" ls-files --others --exclude-standard 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|css|sql)$' | head -20)
    RETRY_CONTEXT="

## RETRY CONTEXT (attempt $ATTEMPT)
Previous attempt completed $DONE_SO_FAR tasks.
Files already modified:
$CHANGED_FILES
$UNTRACKED

Continue from where the previous attempt left off.
Focus on the NEXT unchecked task in tasks.md."
  fi

  CLAUDE_EXIT=0
  (cd "$PROJECT_DIR" && echo "${IMPL_PROMPT}${RETRY_CONTEXT}" | gtimeout "${MAX_TIMEOUT_MIN}m" claude -p \
    --model "$CLAUDE_MODEL" \
    --permission-mode dontAsk) \
    > "$LOGS_DIR/run-${PROJECT}-${FEATURE_SLUG}-attempt${ATTEMPT}.log" 2>&1 || CLAUDE_EXIT=$?

  # Count what was accomplished
  DONE_AFTER=$(grep -c '^\- \[x\] T[0-9]' "$TASKS_MD" 2>/dev/null) || DONE_AFTER=0
  PENDING_AFTER=$(grep -c '^\- \[ \] T[0-9]' "$TASKS_MD" 2>/dev/null) || PENDING_AFTER=0
  PROGRESS_THIS_ATTEMPT=$((DONE_AFTER - ${DONE_SO_FAR:-0}))

  # Check for new files even if tasks.md wasn't updated
  NEW_FILES=$(git -C "$PROJECT_DIR" ls-files --others --exclude-standard 2>/dev/null | grep -cE '\.(ts|tsx|js|jsx|css|sql)$') || NEW_FILES=0
  MODIFIED_FILES=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  HAS_WORK=$((NEW_FILES + MODIFIED_FILES))

  echo "[$(date -Iseconds)] Attempt $ATTEMPT: exit=$CLAUDE_EXIT, tasks done=$DONE_AFTER, pending=$PENDING_AFTER, new_files=$NEW_FILES, modified=$MODIFIED_FILES" >> "$PROGRESS_FILE"
  log_info "Attempt $ATTEMPT result: $DONE_AFTER done, $PENDING_AFTER pending, $HAS_WORK file changes"

  # If all tasks done, stop
  if [[ $PENDING_AFTER -eq 0 ]]; then
    log_ok "All tasks completed"
    break
  fi

  # If no progress at all (no tasks checked, no files changed), stop retrying
  if [[ $HAS_WORK -eq 0 && $DONE_AFTER -eq ${DONE_SO_FAR:-0} ]]; then
    log_warn "No progress in attempt $ATTEMPT — stopping retries"
    echo "[$(date -Iseconds)] No progress in attempt $ATTEMPT — stopped" >> "$PROGRESS_FILE"
    break
  fi

  # If we made progress but still have pending tasks, continue
  if [[ $PENDING_AFTER -gt 0 && $ATTEMPT -lt $MAX_RETRIES ]]; then
    log_info "Progress made but $PENDING_AFTER tasks remaining — retrying..."
    notify "Harness ($PROJECT): attempt $ATTEMPT done ($DONE_AFTER/$TASK_COUNT). Retrying..."
    sleep 5
  fi

  DONE_SO_FAR=$DONE_AFTER
done

# --- Final counts ---
DONE_COUNT=$(grep -c '^\- \[x\] T[0-9]' "$TASKS_MD" 2>/dev/null) || DONE_COUNT=0
PENDING_COUNT=$(grep -c '^\- \[ \] T[0-9]' "$TASKS_MD" 2>/dev/null) || PENDING_COUNT=0

# Generate task report in progress.txt
{
  echo ""
  echo "## Task Report ($(date -Iseconds))"
  echo ""
  echo "### Completed ($DONE_COUNT)"
  grep '^\- \[x\] T[0-9]' "$TASKS_MD" 2>/dev/null | sed 's/^- \[x\] /  ✅ /' || echo "  (none)"
  echo ""
  echo "### Pending ($PENDING_COUNT)"
  grep '^\- \[ \] T[0-9]' "$TASKS_MD" 2>/dev/null | sed 's/^- \[ \] /  ⏳ /' || echo "  (none)"
  echo ""
  echo "### Summary: $DONE_COUNT/$TASK_COUNT done, $PENDING_COUNT pending ($ATTEMPT attempts)"
} >> "$PROGRESS_FILE"

log_info "Results: $DONE_COUNT/$TASK_COUNT done, $PENDING_COUNT pending"

# --- Safety commit: catch uncommitted work from Claude ---
# Claude often implements without committing. This catches that work.
HAS_CHANGES=false
if ! git -C "$PROJECT_DIR" diff --quiet 2>/dev/null || \
   [[ -n "$(git -C "$PROJECT_DIR" ls-files --others --exclude-standard 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|css|sql|json|md)$' | head -1)" ]]; then
  HAS_CHANGES=true
fi

if [[ "$HAS_CHANGES" == true ]]; then
  log_info "Uncommitted changes detected — creating safety commit..."
  safe_git_stage "$PROJECT_DIR"
  # Reset files that shouldn't be committed
  git -C "$PROJECT_DIR" reset -- .harness.lock 2>/dev/null || true
  # Stage project config + specs
  git -C "$PROJECT_DIR" add .specify/ .claude/commands/ specs/ 2>/dev/null || true
  if ! git -C "$PROJECT_DIR" diff --cached --quiet 2>/dev/null; then
    git -C "$PROJECT_DIR" commit -m "feat: implement $(basename "$SPEC_DIR" | sed 's/^[0-9]*-//' | tr '-' ' ')

Tasks: $DONE_COUNT/$TASK_COUNT completed
Spec: $SPEC_REL/

Generated by Harness v2" 2>/dev/null || true
    log_ok "Safety commit created"
  fi
fi

# --- Check if there are commits to push ---
COMMITS_AHEAD=$(git -C "$PROJECT_DIR" rev-list --count "origin/${DEFAULT_BRANCH}..HEAD" 2>/dev/null || echo 0)
if [[ "$COMMITS_AHEAD" -eq 0 ]]; then
  log_warn "No new commits on branch — nothing to push or PR"
  notify "Harness ($PROJECT): nenhum commit gerado. Verifique o log: $LOGS_DIR/run-${PROJECT}-${FEATURE_SLUG}.log"
  rm -f "$LOCK_FILE"
  trap - EXIT
  exit 0
fi

# --- Quality gate: lint + typecheck + tests ---
log_info "Running quality gate before push..."
GATE_LOG="$LOGS_DIR/gate-${PROJECT}-${FEATURE_SLUG}.log"
GATE_PASSED=true

(cd "$PROJECT_DIR" && $PKG_MANAGER run lint 2>&1) > "$GATE_LOG" || {
  log_error "Quality gate FAILED: lint"
  GATE_PASSED=false
}

if [[ "$GATE_PASSED" == true ]]; then
  (cd "$PROJECT_DIR" && $RUNNER tsc --noEmit${TSCONFIG:+ -p $TSCONFIG} 2>&1) >> "$GATE_LOG" || {
    log_error "Quality gate FAILED: typecheck"
    GATE_PASSED=false
  }
fi

if [[ "$GATE_PASSED" == true ]]; then
  (cd "$PROJECT_DIR" && $PKG_MANAGER run test 2>&1) >> "$GATE_LOG" || {
    log_error "Quality gate FAILED: tests"
    GATE_PASSED=false
  }
fi

if [[ "$GATE_PASSED" == true ]]; then
  log_ok "Quality gate passed (lint + typecheck + tests)"
else
  log_error "Quality gate failed — attempting auto-fix..."
  echo "[$(date -Iseconds)] Quality gate failed — running auto-fix" >> "$PROGRESS_FILE"

  # Auto-fix attempt via Claude
  GATE_LOG_TAIL=$(tail -100 "$GATE_LOG" 2>/dev/null || echo "(gate log not available)")
  FIX_PROMPT="Quality gate failed before push. Fix ALL issues shown below.

Gate log (last 100 lines):
$GATE_LOG_TAIL

Fix the issues, then re-run:
1. \`$PKG_MANAGER run lint\`
2. \`$RUNNER tsc --noEmit${TSCONFIG:+ -p $TSCONFIG}\`
3. \`$PKG_MANAGER run test\`

Commit fixes with: git add -A && git reset -- .harness/ progress.txt node_modules/ .env* && git commit -m 'fix: resolve quality gate issues'"

  GATE_FIX_EXIT=0
  (cd "$PROJECT_DIR" && echo "$FIX_PROMPT" | gtimeout 20m claude -p \
    --model "$CLAUDE_MODEL" \
    --permission-mode dontAsk) \
    >> "$GATE_LOG" 2>&1 || GATE_FIX_EXIT=$?

  # Re-run gate after fix
  GATE_PASSED=true
  (cd "$PROJECT_DIR" && $PKG_MANAGER run lint 2>&1) >> "$GATE_LOG" || GATE_PASSED=false
  if [[ "$GATE_PASSED" == true ]]; then
    (cd "$PROJECT_DIR" && $RUNNER tsc --noEmit${TSCONFIG:+ -p $TSCONFIG} 2>&1) >> "$GATE_LOG" || GATE_PASSED=false
  fi
  if [[ "$GATE_PASSED" == true ]]; then
    (cd "$PROJECT_DIR" && $PKG_MANAGER run test 2>&1) >> "$GATE_LOG" || GATE_PASSED=false
  fi

  if [[ "$GATE_PASSED" == true ]]; then
    log_ok "Quality gate passed after auto-fix"
  else
    log_error "Quality gate still failing after auto-fix — pushing anyway with warning"
    echo "[$(date -Iseconds)] Quality gate FAILED even after auto-fix" >> "$PROGRESS_FILE"
    notify "⚠️ Harness ($PROJECT): quality gate falhou. PR terá issues. Branch: $BRANCH_NAME"
  fi
fi

# --- Push ---
git -C "$PROJECT_DIR" push -u origin "$BRANCH_NAME" 2>/dev/null || {
  log_error "Git push failed"
  notify "Harness ($PROJECT): push falhou. Branch: $BRANCH_NAME"
  rm -f "$LOCK_FILE"
  trap - EXIT
  exit $EXIT_CLAUDE_FAIL
}

# --- Create PR ---
ISSUE_REF=$(grep -oE '#[0-9]+' "$SPEC_DIR/spec.md" 2>/dev/null | head -1 || true)
CLOSES_LINE=""
[[ -n "$ISSUE_REF" ]] && CLOSES_LINE="
Closes $ISSUE_REF"

FEATURE_TITLE=$(head -5 "$SPEC_DIR/spec.md" | grep -m1 '^#' | sed 's/^#* *//' || echo "$FEATURE_SLUG")

# Include task report in PR body
TASK_REPORT=$(grep -A 100 '## Task Report' "$PROGRESS_FILE" 2>/dev/null || echo "")

PR_BODY="## Summary
- Done: $DONE_COUNT/$TASK_COUNT
- Pending: $PENDING_COUNT
$CLOSES_LINE

## Spec
\`$SPEC_REL/\`

$TASK_REPORT

---
Generated by Harness v2"

# Check if PR already exists for this branch
EXISTING_PR=$(cd "$PROJECT_DIR" && gh pr list --head "$BRANCH_NAME" --json number -q '.[0].number' 2>/dev/null)

if [[ -n "$EXISTING_PR" ]]; then
  log_info "PR #$EXISTING_PR already exists — updating..."
  (cd "$PROJECT_DIR" && gh pr comment "$EXISTING_PR" --body "Harness v2 update: $DONE_COUNT/$TASK_COUNT tasks done. Branch pushed." 2>/dev/null) || true
  PR_URL=$(cd "$PROJECT_DIR" && gh pr view "$EXISTING_PR" --json url -q '.url' 2>/dev/null)
  PR_NUMBER="$EXISTING_PR"
else
  PR_URL=$(cd "$PROJECT_DIR" && gh pr create \
    --title "feat: $FEATURE_TITLE" \
    --body "$PR_BODY" \
    --head "$BRANCH_NAME" 2>/dev/null || echo "PR_FAILED")

  if [[ "$PR_URL" == "PR_FAILED" ]]; then
    log_error "PR creation failed"
    notify "Harness ($PROJECT): implementação concluída mas PR falhou. Branch: $BRANCH_NAME. Commits: $COMMITS_AHEAD"
    rm -f "$LOCK_FILE"
    trap - EXIT
    exit 0
  fi

  PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
fi

log_ok "PR: $PR_URL"

# --- Auto-review ---
if [[ -n "$PR_NUMBER" ]]; then
  log_info "Starting review for PR #$PR_NUMBER..."
  if "$SCRIPT_DIR/harness-review.sh" "$PROJECT" "$PR_NUMBER"; then
    notify "Harness concluído + review OK: $FEATURE_TITLE ($PROJECT). $DONE_COUNT/$TASK_COUNT. PR: $PR_URL"
  else
    notify "Harness concluído ($PROJECT). PR precisa review: $PR_URL"
  fi
else
  notify "Harness concluído: $FEATURE_TITLE ($PROJECT). $DONE_COUNT/$TASK_COUNT. PR: $PR_URL"
fi

rm -f "$LOCK_FILE"
trap - EXIT
log_ok "Harness v2 complete"

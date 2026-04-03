#!/usr/bin/env bash
# Generate specs for a feature with research + approval gate
# v2.1: Deep research → spec generation → Telegram approval gate
# Usage: harness-plan.sh <project> "<description>" [--auto-approve] [--skip-research]
# Exit codes: 0=success, 1=prereq, 2=claude fail, 3=validation fail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
load_secrets

if [[ $# -lt 2 ]]; then
  log_error "Usage: harness-plan.sh <project> \"<description>\" [--auto-approve] [--skip-research]"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
DESCRIPTION="$2"
shift 2

AUTO_APPROVE=false
EXTRA_FLAGS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-approve) AUTO_APPROVE=true; shift ;;
    --skip-research) EXTRA_FLAGS="$EXTRA_FLAGS --skip-research"; shift ;;
    *) shift ;;
  esac
done

PROJECT_DIR=$(validate_project "$PROJECT")
NOTIFY_CHANNEL="${HARNESS_NOTIFY_CHANNEL:-telegram}"
APPROVAL_TIMEOUT="${HARNESS_APPROVAL_TIMEOUT:-3600}"  # 1 hour default

notify() {
  "$SCRIPT_DIR/harness-notify.sh" --channel "$NOTIFY_CHANNEL" "$1" 2>/dev/null || true
}

# Detect issue
ISSUE_FLAG=""
if echo "$DESCRIPTION" | grep -qE '(issue\s*)?#[0-9]+'; then
  ISSUE_NUMBER=$(echo "$DESCRIPTION" | grep -oE '#[0-9]+' | head -1 | tr -d '#' || true)
  ISSUE_FLAG="--issue $ISSUE_NUMBER"
  log_info "Detected GitHub Issue #$ISSUE_NUMBER"
fi

# Health checks
command -v claude > /dev/null 2>&1 || { log_error "claude not found"; exit $EXIT_PREREQ; }
command -v gh > /dev/null 2>&1 || { log_error "gh not found"; exit $EXIT_PREREQ; }
gh auth status > /dev/null 2>&1 || { log_error "gh not authenticated"; exit $EXIT_PREREQ; }
mkdir -p "$LOGS_DIR"

# Check remote push access (non-fatal)
if ! git -C "$PROJECT_DIR" ls-remote --exit-code origin > /dev/null 2>&1; then
  log_warn "Cannot reach git remote — push may fail later"
fi

# Setup .harness/
mkdir -p "$PROJECT_DIR/.harness"
cp -n "$SCRIPT_DIR/templates/CLAUDE.md" "$PROJECT_DIR/.harness/CLAUDE.md" 2>/dev/null || true
cp -n "$SCRIPT_DIR/templates/AGENTS.md" "$PROJECT_DIR/.harness/AGENTS.md" 2>/dev/null || true

for entry in '.harness/' 'progress.txt'; do
  grep -qxF "$entry" "$PROJECT_DIR/.gitignore" 2>/dev/null || echo "$entry" >> "$PROJECT_DIR/.gitignore"
done

# ========================================================================
# Generate specs (research + spec in one pipeline)
# ========================================================================
log_info "Generating specs via Spec Kit pipeline..."
SPEC_DIR=$("$SCRIPT_DIR/harness-spec.sh" "$PROJECT" "$DESCRIPTION" $ISSUE_FLAG $EXTRA_FLAGS) || true
if [[ -z "$SPEC_DIR" || ! -f "$SPEC_DIR/tasks.md" ]]; then
  log_error "Spec generation failed"
  notify "Harness plan falhou ($PROJECT): spec generation failed"
  exit $EXIT_CLAUDE_FAIL
fi

# Validate
for file in spec.md plan.md tasks.md; do
  if [[ ! -f "$SPEC_DIR/$file" ]]; then
    log_error "Missing $file in $SPEC_DIR"
    exit 3
  fi
done

TASK_COUNT=$(grep -c '^- \[ \] T[0-9]' "$SPEC_DIR/tasks.md" 2>/dev/null) || TASK_COUNT=0
if [[ "$TASK_COUNT" -eq 0 ]]; then
  log_error "tasks.md has no parseable tasks"
  exit 3
fi

# Save spec path for show-plan and run
echo "$SPEC_DIR" > "$PROJECT_DIR/.harness/spec-dir"

# ========================================================================
# Spec Review Gate — send summary and wait for approval
# ========================================================================
APPROVAL_FILE="$PROJECT_DIR/.harness/approved"
rm -f "$APPROVAL_FILE"

if [[ "$AUTO_APPROVE" == true ]]; then
  log_info "Auto-approve enabled — skipping review gate"
  touch "$APPROVAL_FILE"
else
  # Build summary for Telegram
  SPEC_NAME=$(basename "$SPEC_DIR")

  # Extract key decisions from plan.md (first 'Decisions for Review' section or first 30 lines)
  DECISIONS=""
  if grep -q "Decisions for Review" "$SPEC_DIR/plan.md" 2>/dev/null; then
    DECISIONS=$(sed -n '/## Decisions for Review/,/^## /p' "$SPEC_DIR/plan.md" | head -20 | tail -n +2)
  fi

  # Extract risks from research.md
  RISKS=""
  if [[ -f "$SPEC_DIR/research.md" ]] && grep -q "Risks" "$SPEC_DIR/research.md" 2>/dev/null; then
    RISKS=$(sed -n '/## Risks/,/^## /p' "$SPEC_DIR/research.md" | head -15 | tail -n +2)
  fi

  # Build plan summary (first 25 lines of plan.md)
  PLAN_PREVIEW=$(head -25 "$SPEC_DIR/plan.md")

  SUMMARY="📋 *Harness Plan Ready* — $PROJECT

*Feature:* $DESCRIPTION
*Spec:* $SPEC_NAME/
*Tasks:* $TASK_COUNT"

  if [[ -n "$DECISIONS" ]]; then
    SUMMARY="$SUMMARY

⚠️ *Decisões que precisam da sua revisão:*
$DECISIONS"
  fi

  if [[ -n "$RISKS" ]]; then
    SUMMARY="$SUMMARY

🔍 *Riscos identificados:*
$RISKS"
  fi

  SUMMARY="$SUMMARY

📄 *Plan preview:*
$PLAN_PREVIEW

---
Para aprovar: \`harness approve $PROJECT\`
Para ver plan completo: \`harness show-plan $PROJECT\`
Para rejeitar: \`harness reject $PROJECT\`"

  notify "$SUMMARY"
  log_info "Plan sent for review. Waiting for approval..."
  log_info "  Approve: touch $APPROVAL_FILE"
  log_info "  Or run:  harness-run.sh $PROJECT"
  log_info "  Timeout: ${APPROVAL_TIMEOUT}s"

  # Wait for approval file
  ELAPSED=0
  POLL_INTERVAL=10
  while [[ ! -f "$APPROVAL_FILE" && $ELAPSED -lt $APPROVAL_TIMEOUT ]]; do
    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))

    # Check for rejection
    if [[ -f "$PROJECT_DIR/.harness/rejected" ]]; then
      log_warn "Plan rejected by user"
      notify "Plan rejeitado ($PROJECT). Specs em $SPEC_NAME/ para ajuste manual."
      rm -f "$PROJECT_DIR/.harness/rejected"
      exit 0
    fi
  done

  if [[ ! -f "$APPROVAL_FILE" ]]; then
    log_warn "Approval timeout (${APPROVAL_TIMEOUT}s). Plan saved but not executed."
    notify "⏰ Harness plan timeout ($PROJECT). Plan salvo em $SPEC_NAME/. Execute manualmente: harness-run.sh $PROJECT"
    exit 0
  fi

  log_ok "Plan approved!"
  notify "✅ Plan aprovado ($PROJECT). Iniciando implementação..."
fi

log_ok "Plan ready: $TASK_COUNT tasks in $(basename "$SPEC_DIR")/"

#!/usr/bin/env bash
# Generate Spec Kit artifacts for a feature
# Usage: harness-spec.sh <project> "<description>" [--issue <N>]
# Output: path to spec directory (stdout)
# Exit codes: 0=success, 1=prereq, 2=claude fail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 2 ]]; then
  log_error "Usage: harness-spec.sh <project> \"<description>\" [--issue <N>]"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
DESCRIPTION="$2"
shift 2

ISSUE_NUMBER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE_NUMBER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

PROJECT_DIR=$(validate_project "$PROJECT")
CLAUDE_MODEL="${HARNESS_CLAUDE_MODEL:-claude-sonnet-4-6}"

command -v claude > /dev/null 2>&1 || { log_error "claude not found"; exit $EXIT_PREREQ; }

# Init Spec Kit scaffold if needed
mkdir -p "$PROJECT_DIR/specs"
if command -v specify > /dev/null 2>&1 && [[ ! -d "$PROJECT_DIR/.specify" ]]; then
  log_info "Initializing Spec Kit scaffold..."
  (cd "$PROJECT_DIR" && specify init . --ai claude --force) 2>/dev/null || true
fi

# Fetch issue context
ISSUE_CONTEXT=""
if [[ -n "$ISSUE_NUMBER" ]]; then
  ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "dougss/$PROJECT" --json title,body -q '"\(.title)\n\n\(.body)"' 2>/dev/null)
  [[ -z "$ISSUE_BODY" ]] && ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "dougss/server-ops" --json title,body -q '"\(.title)\n\n\(.body)"' 2>/dev/null)
  [[ -n "$ISSUE_BODY" ]] && ISSUE_CONTEXT="

GitHub Issue #$ISSUE_NUMBER:
$ISSUE_BODY" && log_ok "Issue #$ISSUE_NUMBER loaded"
fi

# Project context
PKG_SUMMARY=$(jq '{name, scripts: (.scripts | keys), dependencies: (.dependencies | keys), devDependencies: (.devDependencies | keys)}' "$PROJECT_DIR/package.json" 2>/dev/null || echo '{}')

CONSTITUTION=""
[[ -f "$PROJECT_DIR/.specify/memory/constitution.md" ]] && CONSTITUTION="
Project Constitution:
$(cat "$PROJECT_DIR/.specify/memory/constitution.md")"

# Determine spec directory
NEXT_NUM=$(find "$PROJECT_DIR/specs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
NEXT_NUM=$((NEXT_NUM + 1))
FEATURE_SLUG=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | cut -c1-50)
SPEC_DIR_NAME=$(printf "%03d-%s" "$NEXT_NUM" "$FEATURE_SLUG")
SPEC_DIR="$PROJECT_DIR/specs/$SPEC_DIR_NAME"
mkdir -p "$SPEC_DIR"

mkdir -p "$LOGS_DIR"

# Generate all 3 artifacts in ONE claude -p call
log_info "Generating spec, plan, and tasks..."

PROMPT="You are generating Spec Kit artifacts for a feature. Create 3 files in $SPEC_DIR/:

## Feature
$DESCRIPTION
$ISSUE_CONTEXT
$CONSTITUTION

## Project
$PKG_SUMMARY

## Instructions

### 1. Write $SPEC_DIR/spec.md
Focus on WHAT and WHY, not HOW:
- User Stories prioritized (P1, P2, P3) with Given/When/Then scenarios
- Functional Requirements (FR-001, FR-002...)
- Success Criteria (measurable, technology-agnostic)
- Key Entities and Assumptions

### 2. Write $SPEC_DIR/plan.md
Technical plan based on the spec:
- Tech stack and architecture decisions
- Project structure (file tree)
- Data model and API contracts (if applicable)
- Testing strategy

### 3. Write $SPEC_DIR/tasks.md
Decompose the plan into tasks with this EXACT format:

\`\`\`
# Implementation Tasks

## Phase 1: Setup
- [ ] T001 Description with exact file path

## Phase 2: Foundational
- [ ] T002 [P] Parallelizable task with file path

## Phase 3: User Story 1 — Title
- [ ] T003 [US1] Story task with file path

## Phase N: Polish
- [ ] TXXX Final task
\`\`\`

Rules for tasks.md:
- IDs: T001, T002... (sequential, 3-digit)
- [P] = parallelizable (different files, no deps)
- [US1] = user story grouping
- Each task: 15-20 minutes, exact file paths
- Phases: Setup → Foundational → User Stories → Polish

Write all 3 files now."

# claude -p may return non-zero even on success (hooks, warnings)
# Validate by checking output files, not exit code
(cd "$PROJECT_DIR" && echo "$PROMPT" | claude -p \
  --model "$CLAUDE_MODEL" \
  --permission-mode dontAsk \
  --allowedTools "Read Glob Grep Write") > "$LOGS_DIR/spec-${PROJECT}.log" 2>&1 || true

# Validate
for file in spec.md plan.md tasks.md; do
  if [[ ! -f "$SPEC_DIR/$file" ]]; then
    log_error "Missing $file in $SPEC_DIR"
    exit $EXIT_CLAUDE_FAIL
  fi
done

TASK_COUNT=$(grep -c '^- \[ \] T[0-9]' "$SPEC_DIR/tasks.md" 2>/dev/null || echo 0)
log_ok "Spec complete: $TASK_COUNT tasks in $SPEC_DIR"
echo "$SPEC_DIR"

#!/usr/bin/env bash
# Generate Spec Kit artifacts for a feature with deep research phase
# Usage: harness-spec.sh <project> "<description>" [--issue <N>] [--skip-research]
# Output: path to spec directory (stdout)
# Exit codes: 0=success, 1=prereq, 2=claude fail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 2 ]]; then
  log_error "Usage: harness-spec.sh <project> \"<description>\" [--issue <N>] [--skip-research]"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
DESCRIPTION="$2"
shift 2

ISSUE_NUMBER=""
SKIP_RESEARCH=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE_NUMBER="$2"; shift 2 ;;
    --skip-research) SKIP_RESEARCH=true; shift ;;
    *) shift ;;
  esac
done

PROJECT_DIR=$(validate_project "$PROJECT")
CLAUDE_MODEL="${HARNESS_CLAUDE_MODEL:-claude-sonnet-4-6}"
RESEARCH_MODEL="${HARNESS_RESEARCH_MODEL:-claude-opus-4-6}"

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

# ========================================================================
# PHASE 1: Deep Research — exhaustive codebase analysis before spec
# ========================================================================
RESEARCH_FILE="$SPEC_DIR/research.md"

if [[ "$SKIP_RESEARCH" == true ]]; then
  log_info "Skipping research phase (--skip-research)"
  RESEARCH_CONTEXT=""
else
  log_info "Phase 1: Deep research (codebase analysis)..."

  RESEARCH_PROMPT="You are a senior architect doing exhaustive research BEFORE writing a spec.
Your goal is to deeply understand the codebase so the implementation plan is optimal.

## Feature to implement
$DESCRIPTION
$ISSUE_CONTEXT

## Your research mission

Investigate the codebase thoroughly. You MUST:

### 1. Read the project's CLAUDE.md and understand conventions
Read CLAUDE.md (project root) completely. Understand the stack, patterns, database schema.

### 2. Analyze existing similar features
Search for features with similar patterns (CRUD pages, hooks, components, DB tables).
For each similar feature found, document:
- Which files were created (page, hook, components, types, tests)
- How the hook talks to Supabase (direct .from() or RPC?)
- How tests are structured (what's mocked, what's tested)
- What UI components are used (shadcn, custom)

### 3. Map reusable code
Find utilities, functions, types, and components that MUST be reused:
- Existing helper functions (formatCurrency, date utils, etc.)
- Existing trigger functions (e.g. update_updated_at_column — don't create duplicates!)
- Shared types and interfaces
- Test utilities and mock patterns
- UI components already available

### 4. Analyze the database schema
Read the consolidated migration and recent migrations. Understand:
- Existing tables, their relationships, RLS policies
- Naming conventions (snake_case? column patterns?)
- How new tables typically relate to auth.users
- Which extensions are available (pgvector, uuid-ossp, etc.)
- Migration idempotency patterns used (IF NOT EXISTS, DO \$\$ blocks)

### 5. Challenge the approach — Grill-Me analysis
Before deciding on an approach, ask yourself:
- Is a new table really needed, or can we extend an existing one?
- Can we use an existing RPC or do we need a new one?
- What are the edge cases for this feature?
- What could go wrong with this approach? (timezone issues, null handling, RLS gaps)
- Are there existing tests that will break if we change shared code?
- What's the simplest implementation that satisfies the requirements?

### 6. Identify risks and decisions
Document decisions that need human input:
- Business logic thresholds (e.g., what counts as 'overdue'? same day? next day?)
- UI/UX decisions (where does this page go in the sidebar? what order?)
- Data model choices that are hard to change later

## Output

Write your findings to $RESEARCH_FILE with this structure:

\`\`\`markdown
# Research: [Feature Name]

## Existing Patterns Found
[List similar features and their file patterns]

## Reusable Code
[Functions, components, types to reuse — with file paths]

## Database Analysis
[Existing schema relevant to this feature, naming patterns, triggers to reuse]

## Approach Recommendation
[Recommended approach with justification]

## Grill-Me: Challenged Assumptions
[Questions asked and answers found during research]

## Risks & Decisions Needing Human Input
[Things the implementation agent cannot decide alone]

## Anti-patterns to Avoid
[Based on what was found in codebase — things NOT to do]
\`\`\`

Be thorough. Read actual files, don't guess. This research directly determines implementation quality."

  (cd "$PROJECT_DIR" && echo "$RESEARCH_PROMPT" | gtimeout 15m claude -p \
    --model "$RESEARCH_MODEL" \
    --permission-mode dontAsk \
    --allowedTools "Read Glob Grep Bash") > "$LOGS_DIR/research-${PROJECT}-${FEATURE_SLUG}.log" 2>&1 || true

  if [[ -f "$RESEARCH_FILE" ]]; then
    RESEARCH_LINES=$(wc -l < "$RESEARCH_FILE" | tr -d ' ')
    log_ok "Research complete: $RESEARCH_LINES lines in research.md"
    RESEARCH_CONTEXT="
## Deep Research Results
The following research was done by analyzing the actual codebase. Use these findings to make optimal decisions:

$(cat "$RESEARCH_FILE")"
  else
    log_warn "Research phase produced no output — proceeding without it"
    RESEARCH_CONTEXT=""
  fi
fi

# ========================================================================
# PHASE 2: Generate spec, plan, and tasks using research
# ========================================================================
log_info "Phase 2: Generating spec, plan, and tasks..."

PROMPT="You are generating Spec Kit artifacts for a feature. Create 3 files in $SPEC_DIR/:

## Feature
$DESCRIPTION
$ISSUE_CONTEXT
$CONSTITUTION

## Project
$PKG_SUMMARY
$RESEARCH_CONTEXT

## Instructions

### 1. Write $SPEC_DIR/spec.md
Focus on WHAT and WHY, not HOW:
- User Stories prioritized (P1, P2, P3) with Given/When/Then scenarios
- Functional Requirements (FR-001, FR-002...)
- Success Criteria (measurable, technology-agnostic)
- Key Entities and Assumptions
$(if [[ -n "$ISSUE_NUMBER" ]]; then echo "- Reference: GitHub Issue #$ISSUE_NUMBER"; fi)

### 2. Write $SPEC_DIR/plan.md
Technical plan based on the spec AND the research findings:
- Tech stack and architecture decisions (justify why, referencing research)
- Project structure (file tree with exact paths)
- Data model with migrations (use IF NOT EXISTS / DO \$\$ for idempotency)
- Reuse existing functions found in research (list which ones and why)
- API contracts (if applicable)
- Testing strategy (follow existing test patterns found in research)
- Edge cases and risk mitigations identified in research

CRITICAL: If the research identified reusable code, you MUST plan to use it.
CRITICAL: If the research identified risks or decisions needing human input,
flag them clearly in a '## Decisions for Review' section at the top of plan.md.

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

TASK_COUNT=$(grep -c '^- \[ \] T[0-9]' "$SPEC_DIR/tasks.md" 2>/dev/null) || TASK_COUNT=0
log_ok "Spec complete: $TASK_COUNT tasks in $SPEC_DIR"
echo "$SPEC_DIR"

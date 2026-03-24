#!/usr/bin/env bash
# Generate prd.json for a project using Claude Code
# Usage: harness-plan.sh <project> "<description>"
# Exit codes: 0=success, 1=prereq, 2=claude fail, 3=schema fail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 2 ]]; then
  log_error "Usage: harness-plan.sh <project> \"<description>\""
  exit $EXIT_PREREQ
fi

PROJECT="$1"
DESCRIPTION="$2"
PROJECT_DIR=$(validate_project "$PROJECT")
ISSUE_NUMBER=""
ISSUE_CONTEXT=""

# Detect GitHub Issue reference in description (e.g., "issue #14" or just "#14")
if echo "$DESCRIPTION" | grep -qE '(issue\s*)?#[0-9]+'; then
  ISSUE_NUMBER=$(echo "$DESCRIPTION" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
  log_info "Detected GitHub Issue #$ISSUE_NUMBER"

  # Try project repo first, then server-ops
  REPO_NAME=$(jq -r '.name // empty' "$PROJECT_DIR/package.json" 2>/dev/null)
  ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "dougss/$PROJECT" --json title,body -q '"\(.title)\n\n\(.body)"' 2>/dev/null)
  if [[ -z "$ISSUE_BODY" ]]; then
    ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "dougss/server-ops" --json title,body -q '"\(.title)\n\n\(.body)"' 2>/dev/null)
  fi

  if [[ -n "$ISSUE_BODY" ]]; then
    ISSUE_CONTEXT="

GitHub Issue #$ISSUE_NUMBER context:
$ISSUE_BODY"
    log_ok "Issue #$ISSUE_NUMBER loaded as context"
  else
    log_warn "Could not fetch issue #$ISSUE_NUMBER"
  fi
fi

# Health checks
command -v claude > /dev/null 2>&1 || { log_error "claude not found in PATH"; exit $EXIT_PREREQ; }
command -v gh > /dev/null 2>&1 || { log_error "gh not found in PATH"; exit $EXIT_PREREQ; }
command -v gtimeout > /dev/null 2>&1 || { log_error "gtimeout not found (brew install coreutils)"; exit $EXIT_PREREQ; }
gh auth status > /dev/null 2>&1 || { log_error "gh not authenticated (run: gh auth login)"; exit $EXIT_PREREQ; }

# Check remote push access
if ! git -C "$PROJECT_DIR" ls-remote --exit-code origin > /dev/null 2>&1; then
  log_warn "Cannot reach git remote — push may fail later"
fi

# Ensure logs dir
mkdir -p "$LOGS_DIR"
if [[ ! -w "$LOGS_DIR" ]]; then
  log_error "Logs directory not writable: $LOGS_DIR"
  exit $EXIT_PREREQ
fi

# Copy templates to .harness/ (don't overwrite project CLAUDE.md)
mkdir -p "$PROJECT_DIR/.harness"
cp -n "$SCRIPT_DIR/templates/CLAUDE.md" "$PROJECT_DIR/.harness/CLAUDE.md" 2>/dev/null || true
cp -n "$SCRIPT_DIR/templates/AGENTS.md" "$PROJECT_DIR/.harness/AGENTS.md" 2>/dev/null || true

# Add .harness/ to .gitignore
if ! grep -qxF '.harness/' "$PROJECT_DIR/.gitignore" 2>/dev/null; then
  echo '.harness/' >> "$PROJECT_DIR/.gitignore"
  log_info "Added .harness/ to .gitignore"
fi

# Collect project context (limited)
if command -v tree > /dev/null 2>&1; then
  TREE_OUTPUT=$(cd "$PROJECT_DIR" && tree -L 2 --dirsfirst -I node_modules 2>/dev/null | head -100)
else
  TREE_OUTPUT=$(cd "$PROJECT_DIR" && find . -maxdepth 2 -not -path './node_modules/*' -not -path './.git/*' | sort | head -100)
fi
if [[ $(echo "$TREE_OUTPUT" | wc -l) -ge 100 ]]; then
  TREE_OUTPUT="$TREE_OUTPUT
... (truncated at 100 lines)"
fi

PKG_SUMMARY=$(jq '{name, scripts, dependencies, devDependencies}' "$PROJECT_DIR/package.json" 2>/dev/null || echo '{}')

TSCONFIG_SUMMARY=""
if [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then
  TSCONFIG_SUMMARY=$(jq '.compilerOptions' "$PROJECT_DIR/tsconfig.json" 2>/dev/null || echo '{}')
else
  TSCONFIG_SUMMARY="(tsconfig.json not found)"
fi

# Build prompt
PROMPT="You are a software architect. Analyze this TypeScript/Node/React project
and decompose the following feature into implementable tasks.

Feature: $DESCRIPTION
$ISSUE_CONTEXT

Project context:
- Directory: $PROJECT_DIR
- package.json (summary):
$PKG_SUMMARY
- tsconfig.json (compilerOptions):
$TSCONFIG_SUMMARY
- Structure:
$TREE_OUTPUT

IMPORTANT — Before decomposing, search for existing spec files in the project:
- Check: specs/, .kiro/specs/, docs/specs/ directories
- If you find requirements.md, design.md, or similar spec files related to this feature,
  READ THEM and use them as the primary source for requirements and acceptance criteria.
- The specs are the source of truth — your job is to decompose them into harness-sized tasks,
  not to reinvent the requirements.
- If no specs exist, decompose from the feature description alone.

Decomposition rules:
1. Each task must be completable in a 15-20 minute session
2. Each task must have testable acceptance criteria (from specs if available)
3. Resolve dependencies topologically: dependent tasks come after their dependencies
4. Foundation first (types, config, utils), then features, then E2E tests
5. Include suggested_files (reference only — agent can create additional files)
6. Estimate total cost based on number of tasks (~\$0.50 per task)
7. Group related small changes into cohesive tasks — do NOT create one task per file change

Generate a file called prd.json in $PROJECT_DIR following EXACTLY this schema:

{
  \"project\": \"$PROJECT\",
  \"feature\": \"feature-name\",
  \"feature_slug\": \"feature-name-slug\",
  \"description\": \"full description\",
  \"created\": \"$(date -Iseconds)\",
  \"estimated_cost\": \"\$X-Y\",
  \"status\": \"pending_approval\",
  \"tasks\": [
    {
      \"id\": \"TASK-001\",
      \"priority\": 1,
      \"title\": \"short title\",
      \"description\": \"detailed description\",
      \"acceptance_criteria\": [\"testable criterion\"],
      \"suggested_files\": [\"src/path/to/file.ts\"],
      \"depends_on\": [],
      \"status\": \"pending\",
      \"retries\": 0,
      \"blocked_reason\": \"\",
      \"timeout_minutes\": 20
    }
  ]
}

Required fields - top-level: project, feature, feature_slug, status, tasks.
Required fields - each task: id, priority, title, description, acceptance_criteria, status.

IMPORTANT:
- Priority is a tiebreaker — depends_on takes precedence in ordering
- Don't create tasks for basic setup (project already has package.json)
- Focus on what is NEW for this feature
- timeout_minutes default: 20 (increase for tasks involving many files)
- Write the prd.json file to: $PROJECT_DIR/prd.json"

# Run Claude Code (read-only — no Bash) — cd to project dir
log_info "Generating plan with Claude Code..."
CLAUDE_MODEL="${HARNESS_CLAUDE_MODEL:-claude-sonnet-4-6}"

if ! (cd "$PROJECT_DIR" && echo "$PROMPT" | claude -p \
  --model "$CLAUDE_MODEL" \
  --allowedTools "Read Glob Grep Write") > "$LOGS_DIR/plan-${PROJECT}.log" 2>&1; then
  log_error "Claude Code failed during planning. See: $LOGS_DIR/plan-${PROJECT}.log"
  exit $EXIT_CLAUDE_FAIL
fi

# Validate generated prd.json
PRD_PATH="$PROJECT_DIR/prd.json"
if [[ ! -f "$PRD_PATH" ]]; then
  log_error "Claude Code did not generate prd.json"
  exit $EXIT_CLAUDE_FAIL
fi

validate_prd_schema "$PRD_PATH"

TASK_COUNT=$(jq '.tasks | length' "$PRD_PATH")
COST=$(jq -r '.estimated_cost // "unknown"' "$PRD_PATH")
log_ok "Plan generated: $TASK_COUNT tasks, estimated cost: $COST"

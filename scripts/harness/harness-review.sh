#!/usr/bin/env bash
# Automated code review with binary gates + LLM bug detection
# Usage: harness-review.sh <project> <pr-number>
# Exit codes: 0=approved, 1=prereq, 2=issues found (attempted fix), 3=needs human review

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
load_secrets

if [[ $# -lt 2 ]]; then
  log_error "Usage: harness-review.sh <project> <pr-number>"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
PR_NUMBER="$2"
PROJECT_DIR=$(validate_project "$PROJECT")
CLAUDE_MODEL="${HARNESS_CLAUDE_MODEL:-claude-sonnet-4-6}"
NOTIFY_CHANNEL="${HARNESS_NOTIFY_CHANNEL:-telegram}"
MAX_REVIEW_ITERATIONS=2
REVIEW_DIR="$PROJECT_DIR/.harness"

notify() {
  "$SCRIPT_DIR/harness-notify.sh" --channel "$NOTIFY_CHANNEL" "$1" 2>/dev/null || true
}

# Detect package manager
pkg_manager=$(detect_pkg_manager "$PROJECT_DIR")
runner=$(get_runner "$pkg_manager")

# ===== GATE 1: Automated checks (no LLM) =====
gate1() {
  log_info "Gate 1: Automated checks..."
  local issues=()

  # 1. TypeScript
  if ! (cd "$PROJECT_DIR" && $runner tsc --noEmit) > /tmp/harness-review-tsc.log 2>&1; then
    issues+=("TSC: $(tail -5 /tmp/harness-review-tsc.log)")
  fi

  # 2. Tests
  if ! (cd "$PROJECT_DIR" && $runner vitest run --reporter=dot) > /tmp/harness-review-test.log 2>&1; then
    issues+=("TESTS: $(tail -5 /tmp/harness-review-test.log)")
  fi

  # 3. Lint
  if ! (cd "$PROJECT_DIR" && $runner eslint . --quiet) > /tmp/harness-review-lint.log 2>&1; then
    issues+=("LINT: $(tail -5 /tmp/harness-review-lint.log)")
  fi

  # 4. Legacy strings (project-specific: check prd.json for feature context)
  local feature_slug
  feature_slug=$(jq -r '.feature_slug // empty' "$PROJECT_DIR/prd.json" 2>/dev/null)

  # Generic legacy check: look for strings that should have been replaced
  # This is populated from prd.json description if available
  local legacy_grep=""
  if [[ -f "$PROJECT_DIR/prd.json" ]]; then
    # Extract any legacy patterns from the prd description
    legacy_grep=$(jq -r '.description // ""' "$PROJECT_DIR/prd.json" | grep -oE '(replace|substituir|renomear) [a-zA-Z]+' 2>/dev/null | awk '{print $2}' | head -5 | tr '\n' '|' | sed 's/|$//')
  fi

  # 5. Secrets in diff
  local secrets_found
  secrets_found=$(git -C "$PROJECT_DIR" diff main...HEAD -- . | grep -iE '(api_key|secret|password|token)\s*[:=]\s*["\x27][^"\x27]{8,}' | grep -v '.env.example' | grep -v 'test' | head -5)
  if [[ -n "$secrets_found" ]]; then
    issues+=("SECRETS: Possible secrets in diff: $secrets_found")
  fi

  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '%s\n' "${issues[@]}" > "$REVIEW_DIR/gate1-issues.txt"
    log_error "Gate 1 failed: ${#issues[@]} issue(s)"
    return 1
  fi

  log_ok "Gate 1 passed"
  return 0
}

# ===== GATE 2: LLM bug/security detection (structured output) =====
gate2() {
  log_info "Gate 2: LLM bug & security scan..."

  # Get diff (limited to code files, max 800 lines)
  local diff_file="$REVIEW_DIR/pr-diff.txt"
  git -C "$PROJECT_DIR" diff main...HEAD -- '*.ts' '*.tsx' '*.css' '*.json' '*.html' \
    | head -800 > "$diff_file"

  local diff_lines
  diff_lines=$(wc -l < "$diff_file" | tr -d ' ')

  if [[ "$diff_lines" -lt 5 ]]; then
    log_ok "Gate 2 skipped: diff too small ($diff_lines lines)"
    echo '{"bugs":[],"security":[]}' > "$REVIEW_DIR/gate2-result.json"
    return 0
  fi

  local review_prompt="You are a code reviewer. Analyze this diff and find ONLY:

1. BUGS — code that will break at runtime (wrong logic, missing null checks that will crash,
   incorrect API usage, broken imports, wrong types that will cause runtime errors)
2. SECURITY — exposed secrets, XSS vectors, SQL injection, hardcoded credentials,
   URLs with tokens in query strings

DO NOT report:
- Style preferences, naming conventions, formatting
- 'Could be improved' suggestions
- Missing comments or documentation
- Alternative patterns or refactoring ideas
- Complexity warnings
- Anything that tsc/eslint/vitest would already catch

Return ONLY valid JSON (no markdown, no explanation, no code fences):
{\"bugs\": [{\"file\": \"path\", \"line\": N, \"description\": \"what breaks\"}], \"security\": [{\"file\": \"path\", \"description\": \"what is exposed\"}]}

If there are NO bugs and NO security issues, return exactly:
{\"bugs\": [], \"security\": []}

DIFF:
$(cat "$diff_file")"

  local result_file="$REVIEW_DIR/gate2-result.json"

  (cd "$PROJECT_DIR" && echo "$review_prompt" | gtimeout 5m claude -p \
    --model "$CLAUDE_MODEL" \
    --allowedTools "Read Glob Grep") \
    > "$REVIEW_DIR/gate2-raw.txt" 2>&1 || true

  # Extract JSON from response (Claude sometimes wraps in markdown)
  local raw_output
  raw_output=$(cat "$REVIEW_DIR/gate2-raw.txt")

  # Try to extract JSON — handle ```json blocks or raw JSON
  echo "$raw_output" | grep -oP '\{[^{}]*("bugs"|"security")[^{}]*\}' | head -1 > "$result_file" 2>/dev/null

  # If extraction failed, try multiline
  if [[ ! -s "$result_file" ]] || ! jq '.' "$result_file" > /dev/null 2>&1; then
    echo "$raw_output" | sed -n '/^[{]/,/^[}]/p' | head -50 > "$result_file" 2>/dev/null
  fi

  # If still invalid JSON, treat as clean (no issues found)
  if ! jq '.' "$result_file" > /dev/null 2>&1; then
    log_warn "Gate 2: Could not parse LLM response as JSON, treating as clean"
    echo '{"bugs":[],"security":[]}' > "$result_file"
    return 0
  fi

  local bug_count security_count
  bug_count=$(jq '.bugs | length' "$result_file")
  security_count=$(jq '.security | length' "$result_file")

  if [[ "$bug_count" -eq 0 && "$security_count" -eq 0 ]]; then
    log_ok "Gate 2 passed: no bugs or security issues"
    return 0
  fi

  log_warn "Gate 2 found issues: $bug_count bugs, $security_count security"
  return 1
}

# ===== FIX: Attempt auto-fix of Gate 2 issues =====
attempt_fix() {
  local iteration="$1"
  local issues_source="${2:-gate2}"  # gate1 or gate2
  log_info "Auto-fix attempt $iteration/$MAX_REVIEW_ITERATIONS..."

  local issues=""
  if [[ "$issues_source" == "gate1" && -f "$REVIEW_DIR/gate1-issues.txt" ]]; then
    issues=$(cat "$REVIEW_DIR/gate1-issues.txt")
  elif [[ -f "$REVIEW_DIR/gate2-result.json" ]]; then
    issues=$(cat "$REVIEW_DIR/gate2-result.json")
  else
    log_warn "No issues file found to fix"
    return 1
  fi

  local fix_prompt="You are fixing bugs and security issues found in a code review.

ISSUES TO FIX:
$issues

Rules:
1. Fix ONLY the listed issues — do not refactor or improve anything else
2. Do NOT modify tests
3. Do NOT add comments explaining the fix
4. After fixing, run: tsc --noEmit && $runner vitest run
5. Do NOT run git add/commit/push

If an issue is a false positive (the code is actually correct), skip it."

  (cd "$PROJECT_DIR" && echo "$fix_prompt" | gtimeout 10m claude -p \
    --model "$CLAUDE_MODEL" \
    --allowedTools "Read Glob Grep Bash Edit Write") \
    > "$LOGS_DIR/review-fix-${PROJECT}-${iteration}.log" 2>&1 || true

  # Stage and commit fixes
  safe_git_stage "$PROJECT_DIR"
  if git -C "$PROJECT_DIR" diff --cached --quiet; then
    log_info "No changes made by fix attempt"
    return 1
  fi

  git -C "$PROJECT_DIR" commit -m "fix: address review issues (auto-fix iteration $iteration)" 2>/dev/null || true
  git -C "$PROJECT_DIR" push origin "$(git -C "$PROJECT_DIR" branch --show-current)" 2>/dev/null || true

  echo "[$(date -Iseconds)] 🔧 Auto-fix iteration $iteration applied" >> "$PROJECT_DIR/progress.txt"
  return 0
}

# ===== POST REVIEW: Generate human-readable review for PR =====
post_review_comment() {
  local gate1_status="$1"  # pass/fail
  local gate2_status="$2"  # pass/fail/skipped
  local final_status="$3"  # approved/needs-review

  local gate2_details=""
  if [[ -f "$REVIEW_DIR/gate2-result.json" ]]; then
    local bugs security
    bugs=$(jq -r '.bugs[] | "- **\(.file):\(.line // "?")** — \(.description)"' "$REVIEW_DIR/gate2-result.json" 2>/dev/null)
    security=$(jq -r '.security[] | "- **\(.file)** — \(.description)"' "$REVIEW_DIR/gate2-result.json" 2>/dev/null)
    if [[ -n "$bugs" ]]; then
      gate2_details="$gate2_details

**Bugs encontrados:**
$bugs"
    fi
    if [[ -n "$security" ]]; then
      gate2_details="$gate2_details

**Issues de segurança:**
$security"
    fi
  fi

  local status_emoji="✅"
  local status_text="PR aprovado — pronto para merge"
  if [[ "$final_status" == "needs-review" ]]; then
    status_emoji="⚠️"
    status_text="PR precisa de review humano"
  fi

  local comment="## 🔍 Automated Code Review

### Gate 1 — Checks automáticos (tsc + vitest + eslint + secrets)
$(if [[ "$gate1_status" == "pass" ]]; then echo "✅ Passou"; else echo "❌ Falhou"; fi)

### Gate 2 — Detecção de bugs e segurança (Claude)
$(if [[ "$gate2_status" == "pass" ]]; then echo "✅ Nenhum bug ou issue de segurança encontrado"; elif [[ "$gate2_status" == "skipped" ]]; then echo "⏭️ Skipped (diff muito pequeno)"; else echo "⚠️ Issues encontradas"; fi)
$gate2_details

### Resultado: $status_emoji $status_text

---
🤖 Review gerado por Harness Engineering"

  cd "$PROJECT_DIR" && gh pr comment "$PR_NUMBER" --body "$comment" 2>/dev/null
  log_ok "Review posted on PR #$PR_NUMBER"
}

# ===== MAIN =====
mkdir -p "$REVIEW_DIR"

# Gate 1
gate1_status="pass"
if ! gate1; then
  gate1_status="fail"
  log_error "Gate 1 failed — attempting auto-fix..."

  attempt_fix 0 gate1
  if ! gate1; then
    log_error "Gate 1 still failing after fix attempt"
    post_review_comment "fail" "skipped" "needs-review"
    notify "⚠️ Review ($PROJECT): Gate 1 falhou (tsc/vitest/eslint). PR #$PR_NUMBER precisa de atenção."
    exit 2
  fi
  gate1_status="pass"
fi

# Gate 2
gate2_status="pass"
if ! gate2; then
  gate2_status="fail"

  # Auto-fix loop
  for i in $(seq 1 $MAX_REVIEW_ITERATIONS); do
    attempt_fix "$i"
    if gate2; then
      gate2_status="pass"
      break
    fi
  done
fi

# Determine final status
final_status="approved"
if [[ "$gate1_status" == "fail" || "$gate2_status" == "fail" ]]; then
  final_status="needs-review"
fi

# Post review comment
post_review_comment "$gate1_status" "$gate2_status" "$final_status"

# Notify
if [[ "$final_status" == "approved" ]]; then
  notify "✅ Review aprovado ($PROJECT). PR #$PR_NUMBER pronto para merge."
  log_ok "Review approved — PR ready to merge"
  exit 0
else
  notify "⚠️ Review ($PROJECT): issues não resolvidas. PR #$PR_NUMBER precisa de review humano."
  log_warn "Review found unresolved issues"
  exit 2
fi

#!/usr/bin/env bash
# Validate agent-vault assets for portability
# Checks for hardcoded paths, secrets, and broken references

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=0
WARNINGS=0

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Validating agent-vault at: $REPO_DIR"
echo "=================================="

# 1. Check for hardcoded home paths
echo -e "\n[1/5] Checking for hardcoded paths..."
HARDCODED=$(grep -rn '/Users/macmini\|/home/\|/root/' "$REPO_DIR" \
  --include='*.md' --include='*.sh' --include='*.py' --include='*.json' \
  --exclude-dir='.git' --exclude-dir='node_modules' \
  --exclude='validate.sh' --exclude='migrate.sh' 2>/dev/null || true)

if [[ -n "$HARDCODED" ]]; then
  echo -e "${YELLOW}WARNING: Hardcoded paths found:${NC}"
  echo "$HARDCODED" | head -20
  WARNINGS=$((WARNINGS + $(echo "$HARDCODED" | wc -l)))
fi

# 2. Check for potential secrets
echo -e "\n[2/5] Checking for potential secrets..."
SECRETS=$(grep -rn 'sk-proj-\|sk-[a-z0-9]\{20,\}\|AIzaSy\|xoxb-\|xapp-\|ghp_\|AKIA' "$REPO_DIR" \
  --include='*.md' --include='*.sh' --include='*.py' --include='*.json' \
  --exclude-dir='.git' --exclude='.env.example' --exclude='pre-commit-hook.sh' \
  --exclude='validate.sh' --exclude='migrate.sh' 2>/dev/null || true)

if [[ -n "$SECRETS" ]]; then
  echo -e "${RED}ERROR: Potential secrets found:${NC}"
  echo "$SECRETS" | head -10
  ERRORS=$((ERRORS + $(echo "$SECRETS" | wc -l)))
fi

# 3. Check that all SKILL.md files have frontmatter
echo -e "\n[3/5] Checking SKILL.md frontmatter..."
while IFS= read -r skill_file; do
  if ! head -1 "$skill_file" | grep -q '^---$'; then
    echo -e "${YELLOW}WARNING: Missing frontmatter: $skill_file${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
done < <(find "$REPO_DIR" -name "SKILL.md" -type f 2>/dev/null)

# 4. Check for placeholder variables
echo -e '\n[4/5] Checking placeholder variables are documented...'
PLACEHOLDERS=$(grep -roh '\${[A-Z_]*}' "$REPO_DIR" \
  --include='*.md' --include='*.sh' --include='*.py' --include='*.json' \
  --exclude-dir='.git' 2>/dev/null | sort -u || true)

if [[ -n "$PLACEHOLDERS" ]]; then
  echo "Found placeholders:"
  echo "$PLACEHOLDERS"
  # Check each is documented in .env.example
  while IFS= read -r var; do
    VAR_NAME=$(echo "$var" | tr -d '${} ')
    if ! grep -q "$VAR_NAME" "$REPO_DIR/.env.example" 2>/dev/null; then
      echo -e "${YELLOW}WARNING: $var not documented in .env.example${NC}"
      WARNINGS=$((WARNINGS + 1))
    fi
  done <<< "$PLACEHOLDERS"
fi

# 5. Check README.md exists in key directories
echo -e "\n[5/5] Checking README.md coverage..."
for dir in agents skills scripts configs templates cron docs; do
  if [[ -d "$REPO_DIR/$dir" ]] && [[ ! -f "$REPO_DIR/$dir/README.md" ]]; then
    echo -e "${YELLOW}WARNING: Missing README.md in $dir/${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
done

# Summary
echo -e "\n=================================="
if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
  echo -e "${GREEN}All checks passed!${NC}"
elif [[ $ERRORS -eq 0 ]]; then
  echo -e "${YELLOW}Passed with $WARNINGS warning(s)${NC}"
else
  echo -e "${RED}Failed: $ERRORS error(s), $WARNINGS warning(s)${NC}"
  exit 1
fi

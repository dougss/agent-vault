#!/usr/bin/env bash
# Pre-commit hook: blocks commits containing secrets
# Install: cp scripts/utilities/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

set -euo pipefail

RED='\033[0;31m'
NC='\033[0m'

# Patterns that indicate secrets
SECRET_PATTERNS=(
  'sk-proj-[A-Za-z0-9_-]{20,}'
  'sk-[A-Za-z0-9_-]{20,}'
  'AIzaSy[A-Za-z0-9_-]{30,}'
  'xoxb-[A-Za-z0-9-]+'
  'xapp-[A-Za-z0-9-]+'
  'ghp_[A-Za-z0-9]{36}'
  'gho_[A-Za-z0-9]{36}'
  'BSA[A-Za-z0-9]{20,}'
  'AKIA[A-Z0-9]{16}'
  'password\s*[:=]\s*["\x27][^"\x27]{8,}'
  'Bearer [A-Za-z0-9_-]{20,}'
)

BLOCKED=0

for pattern in "${SECRET_PATTERNS[@]}"; do
  # Check staged files only, filter out placeholders and examples
  MATCHES=$(git diff --cached --diff-filter=ACM -U0 | grep -E "$pattern" | grep -v 'your-.*-here\|placeholder\|\${\|example\|\.env\.example' 2>/dev/null || true)
  if [[ -n "$MATCHES" ]]; then
    echo -e "${RED}BLOCKED: Potential secret detected matching pattern: ${pattern}${NC}"
    echo "$MATCHES" | head -5
    echo ""
    BLOCKED=1
  fi
done

# Check for .env files being committed (exclude .env.example)
ENV_FILES=$(git diff --cached --name-only | grep -E '^\.(env|env\..*)$' | grep -v '\.env\.example$' 2>/dev/null || true)
if [[ -n "$ENV_FILES" ]]; then
  echo -e "${RED}BLOCKED: .env file(s) staged for commit:${NC}"
  echo "$ENV_FILES"
  BLOCKED=1
fi

if [[ $BLOCKED -eq 1 ]]; then
  echo ""
  echo "If this is a false positive, use: git commit --no-verify"
  echo "But DOUBLE CHECK first — secrets in git history are very hard to remove."
  exit 1
fi

exit 0

#!/usr/bin/env bash
# Approve a pending harness plan
# Usage: harness-approve.sh <project>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 1 ]]; then
  log_error "Usage: harness-approve.sh <project>"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
PROJECT_DIR=$(validate_project "$PROJECT")

APPROVAL_FILE="$PROJECT_DIR/.harness/approved"
REJECTED_FILE="$PROJECT_DIR/.harness/rejected"

rm -f "$REJECTED_FILE" 2>/dev/null
touch "$APPROVAL_FILE"
log_ok "Plan approved for $PROJECT"

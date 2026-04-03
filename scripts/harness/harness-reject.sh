#!/usr/bin/env bash
# Reject a pending harness plan
# Usage: harness-reject.sh <project>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 1 ]]; then
  log_error "Usage: harness-reject.sh <project>"
  exit $EXIT_PREREQ
fi

PROJECT="$1"
PROJECT_DIR=$(validate_project "$PROJECT")

REJECTED_FILE="$PROJECT_DIR/.harness/rejected"
APPROVAL_FILE="$PROJECT_DIR/.harness/approved"

rm -f "$APPROVAL_FILE" 2>/dev/null
touch "$REJECTED_FILE"
log_ok "Plan rejected for $PROJECT"

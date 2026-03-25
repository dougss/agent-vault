#!/usr/bin/env bash
# Send notifications via Telegram (or Slack in the future)
# Usage: harness-notify.sh [--channel telegram|slack] "message"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
load_secrets

CHANNEL="${HARNESS_NOTIFY_CHANNEL:-telegram}"
MESSAGE=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel) CHANNEL="$2"; shift 2 ;;
    *) MESSAGE="$1"; shift ;;
  esac
done

if [[ -z "$MESSAGE" ]]; then
  log_error "Usage: harness-notify.sh [--channel telegram|slack] \"message\""
  exit $EXIT_PREREQ
fi

case "$CHANNEL" in
  telegram)
    CHAT_ID="${HARNESS_TELEGRAM_CHAT_ID:-}"
    if [[ -z "$CHAT_ID" ]]; then
      log_error "HARNESS_TELEGRAM_CHAT_ID not set in $SECRETS_ENV"
      exit $EXIT_PREREQ
    fi

    # Try openclaw message send first
    if openclaw message send --channel telegram --target "$CHAT_ID" --message "$MESSAGE" > /dev/null 2>&1; then
      log_ok "Notification sent via openclaw"
    else
      # Fallback to direct Bot API
      BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
      if [[ -z "$BOT_TOKEN" ]]; then
        log_error "TELEGRAM_BOT_TOKEN not set (needed for fallback)"
        exit $EXIT_PREREQ
      fi
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=Markdown")
      if [[ "$HTTP_CODE" == "200" ]]; then
        log_ok "Notification sent via Bot API fallback"
      else
        log_error "Telegram notification failed (HTTP $HTTP_CODE)"
        exit $EXIT_PREREQ
      fi
    fi
    ;;
  slack)
    WEBHOOK_URL="${HARNESS_SLACK_WEBHOOK_URL:-}"
    if [[ -z "$WEBHOOK_URL" ]]; then
      log_error "HARNESS_SLACK_WEBHOOK_URL not set"
      exit $EXIT_PREREQ
    fi
    curl -s -X POST "$WEBHOOK_URL" \
      -H 'Content-type: application/json' \
      -d "{\"text\": \"$MESSAGE\"}" > /dev/null
    log_ok "Notification sent via Slack"
    ;;
  *)
    log_error "Unknown channel: $CHANNEL"
    exit $EXIT_PREREQ
    ;;
esac

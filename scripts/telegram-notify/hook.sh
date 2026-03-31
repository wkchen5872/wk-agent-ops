#!/usr/bin/env bash
# Telegram notification hook for AI CLI (Claude Code / Gemini CLI).
# Deployed to: ~/.config/ai-notify/hooks/telegram-notify.sh
# Called by AI CLI with: $1 = event type (stop | notification), JSON on stdin.
# Always exits 0 — never blocks the calling AI CLI.

# ── Load config ────────────────────────────────────────────────────────────────
# shellcheck source=/dev/null
source "${HOME}/.config/ai-notify/config" 2>/dev/null || true

# ── Guard: skip if disabled or credentials missing ─────────────────────────────
[[ "${TELEGRAM_ENABLED}" != "true" ]] && exit 0
[[ -z "${TELEGRAM_BOT_TOKEN}" ]] && exit 0
[[ -z "${TELEGRAM_CHAT_ID}" ]] && exit 0

# ── Detect event type ──────────────────────────────────────────────────────────
# Primary source: $1 argument (stop | notification)
# Fallback: parse stdin JSON hook_event_name with jq (or grep)
EVENT_TYPE="${1:-}"
STDIN_JSON=""

# Read stdin (non-blocking — AI CLI may or may not pipe JSON)
if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
  STDIN_JSON="$(cat)"
fi

# Normalise event type from stdin if $1 is missing
if [[ -z "${EVENT_TYPE}" ]]; then
  if command -v jq &>/dev/null && [[ -n "${STDIN_JSON}" ]]; then
    raw_event="$(echo "${STDIN_JSON}" | jq -r '.hook_event_name // empty' 2>/dev/null)"
    EVENT_TYPE="$(echo "${raw_event}" | tr '[:upper:]' '[:lower:]')"
  elif [[ -n "${STDIN_JSON}" ]]; then
    # jq not available — use grep fallback
    raw_event="$(echo "${STDIN_JSON}" | grep -o '"hook_event_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
    EVENT_TYPE="$(echo "${raw_event}" | tr '[:upper:]' '[:lower:]')"
  fi
fi

# ── NOTIFY_LEVEL gate ──────────────────────────────────────────────────────────
# notify_only: suppress Stop events; pass Notification events through
NOTIFY_LEVEL="${NOTIFY_LEVEL:-all}"
if [[ "${NOTIFY_LEVEL}" == "notify_only" && "${EVENT_TYPE}" == "stop" ]]; then
  exit 0
fi

# ── Detect AI CLI tool and project ────────────────────────────────────────────
TOOL_NAME="AI CLI"
PROJECT_DIR=""

if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  TOOL_NAME="Claude Code"
  PROJECT_DIR="${CLAUDE_PROJECT_DIR}"
elif [[ -n "${GEMINI_PROJECT_DIR:-}" ]]; then
  TOOL_NAME="Gemini CLI"
  PROJECT_DIR="${GEMINI_PROJECT_DIR}"
elif command -v jq &>/dev/null && [[ -n "${STDIN_JSON}" ]]; then
  cwd_val="$(echo "${STDIN_JSON}" | jq -r '.cwd // empty' 2>/dev/null)"
  [[ -n "${cwd_val}" ]] && PROJECT_DIR="${cwd_val}" && TOOL_NAME="Gemini CLI"
fi

PROJECT_NAME=""
[[ -n "${PROJECT_DIR}" ]] && PROJECT_NAME="$(basename "${PROJECT_DIR}")"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ── Build message ──────────────────────────────────────────────────────────────
MESSAGE=""

case "${EVENT_TYPE}" in
  stop|afteragent)
    MESSAGE="✅ *Task Complete*

🔧 Tool: ${TOOL_NAME}"
    [[ -n "${PROJECT_NAME}" ]] && MESSAGE="${MESSAGE}
📁 Project: ${PROJECT_NAME}"
    MESSAGE="${MESSAGE}
🕐 ${TIMESTAMP}"
    ;;

  notification)
    NOTIFICATION_MSG=""
    if command -v jq &>/dev/null && [[ -n "${STDIN_JSON}" ]]; then
      NOTIFICATION_MSG="$(echo "${STDIN_JSON}" | jq -r '.message // empty' 2>/dev/null)"
    elif [[ -n "${STDIN_JSON}" ]]; then
      NOTIFICATION_MSG="$(echo "${STDIN_JSON}" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
    fi

    MESSAGE="⚠️ *Action Required*

🔧 Tool: ${TOOL_NAME}"
    [[ -n "${PROJECT_NAME}" ]] && MESSAGE="${MESSAGE}
📁 Project: ${PROJECT_NAME}"
    [[ -n "${NOTIFICATION_MSG}" ]] && MESSAGE="${MESSAGE}
💬 ${NOTIFICATION_MSG}"
    MESSAGE="${MESSAGE}
🕐 ${TIMESTAMP}"
    ;;

  *)
    # Unknown event — send a generic notification
    MESSAGE="🤖 *AI CLI Event*

🔧 Tool: ${TOOL_NAME}
📋 Event: ${EVENT_TYPE:-unknown}
🕐 ${TIMESTAMP}"
    ;;
esac

# ── Send via Telegram Bot API ──────────────────────────────────────────────────
TELEGRAM_API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

curl \
  --silent \
  --max-time 10 \
  --output /dev/null \
  -X POST "${TELEGRAM_API}" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "parse_mode=Markdown" \
  --data-urlencode "text=${MESSAGE}" \
  || true

exit 0

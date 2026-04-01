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

# ── Read stdin ─────────────────────────────────────────────────────────────────
STDIN_JSON=""
if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
  STDIN_JSON="$(cat)"
fi

# ── Detect event type ──────────────────────────────────────────────────────────
# Primary source: $1 argument (stop | notification)
# Fallback: parse stdin JSON hook_event_name
EVENT_ARG="${1:-}"
HOOK_EVENT_NAME=""

if command -v jq &>/dev/null && [[ -n "${STDIN_JSON}" ]]; then
  HOOK_EVENT_NAME="$(echo "${STDIN_JSON}" | jq -r '.hook_event_name // empty' 2>/dev/null)"
elif [[ -n "${STDIN_JSON}" ]]; then
  HOOK_EVENT_NAME="$(echo "${STDIN_JSON}" | grep -o '"hook_event_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
fi

# Normalised lowercase for branching
EVENT_TYPE="${EVENT_ARG:-$(echo "${HOOK_EVENT_NAME}" | tr '[:upper:]' '[:lower:]')}"

# ── NOTIFY_LEVEL gate ──────────────────────────────────────────────────────────
NOTIFY_LEVEL="${NOTIFY_LEVEL:-all}"
if [[ "${NOTIFY_LEVEL}" == "notify_only" && "${EVENT_TYPE}" == "stop" ]]; then
  exit 0
fi
# Also suppress sessionEnd (Copilot's equivalent of stop) when notify_only
if [[ "${NOTIFY_LEVEL}" == "notify_only" && "${EVENT_TYPE}" == "sessionend" ]]; then
  exit 0
fi

# ── Detect AI CLI tool and project ────────────────────────────────────────────
# Detection order: GEMINI_PROJECT_DIR → GITHUB_COPILOT_SESSION_ID → CLAUDE_PROJECT_DIR → "AI CLI"
TOOL_NAME="AI CLI"
PROJECT_DIR=""

if [[ -n "${GEMINI_PROJECT_DIR:-}" ]]; then
  TOOL_NAME="Gemini CLI"
  PROJECT_DIR="${GEMINI_PROJECT_DIR}"
elif [[ -n "${GITHUB_COPILOT_SESSION_ID:-}" ]]; then
  TOOL_NAME="Copilot CLI"
  PROJECT_DIR="${PWD}"
elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  TOOL_NAME="Claude Code"
  PROJECT_DIR="${CLAUDE_PROJECT_DIR}"
fi

PROJECT_NAME=""
[[ -n "${PROJECT_DIR}" ]] && PROJECT_NAME="$(basename "${PROJECT_DIR}")"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ── Hook event tag (appended to message line) ─────────────────────────────────
EVENT_TAG="#${HOOK_EVENT_NAME:-${EVENT_TYPE:-unknown}}"

# ── Build message ──────────────────────────────────────────────────────────────
MESSAGE=""

case "${EVENT_TYPE}" in
  stop|afteragent|sessionend)
    MESSAGE="🟢 **Task Complete**

🤖 ${TOOL_NAME}
📂 ${PROJECT_NAME}
⏰ ${TIMESTAMP}

Process finished successfully ${EVENT_TAG}"
    ;;

  notification|userpromptsubmitted)
    NOTIFICATION_MSG=""
    if command -v jq &>/dev/null && [[ -n "${STDIN_JSON}" ]]; then
      NOTIFICATION_MSG="$(echo "${STDIN_JSON}" | jq -r '.message // empty' 2>/dev/null)"
    elif [[ -n "${STDIN_JSON}" ]]; then
      NOTIFICATION_MSG="$(echo "${STDIN_JSON}" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
    fi

    [[ -z "${NOTIFICATION_MSG}" ]] && NOTIFICATION_MSG="Waiting for user interaction..."

    MESSAGE="🟠 **Action Required**

🤖 ${TOOL_NAME}
📂 ${PROJECT_NAME}
⏰ ${TIMESTAMP}

${NOTIFICATION_MSG} ${EVENT_TAG}"
    ;;

  *)
    MESSAGE="🤖 **AI CLI Event**

🤖 ${TOOL_NAME}
📂 ${PROJECT_NAME}
⏰ ${TIMESTAMP}

${EVENT_TAG}"
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

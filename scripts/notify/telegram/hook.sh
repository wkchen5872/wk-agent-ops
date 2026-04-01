#!/usr/bin/env bash
# Telegram notification hook for AI CLI (Claude Code / Gemini CLI / Copilot CLI).
# Deployed to: ~/.config/ai-notify/hooks/telegram-notify.sh
# Called with: $1 = event type (stop | notification | sessionEnd | AfterAgent),
#              $2 = tool name (optional; "Claude Code" | "Gemini CLI" | "Copilot CLI"),
#              JSON on stdin.
# Always exits 0 — never blocks the calling AI CLI.

# ── Load config ────────────────────────────────────────────────────────────────
# Save env vars that should take priority over config file values (e.g., in tests).
_SAVED_NOTIFY_LEVEL="${NOTIFY_LEVEL:-}"
# shellcheck source=/dev/null
source "${HOME}/.config/ai-notify/config" 2>/dev/null || true
# Restore explicitly-set env vars (env var > config file, following Unix convention).
[[ -n "${_SAVED_NOTIFY_LEVEL}" ]] && NOTIFY_LEVEL="${_SAVED_NOTIFY_LEVEL}"

# ── Guard: skip if disabled or credentials missing ─────────────────────────────
# Bypass credential guard in dry-run mode — no HTTP request will be made.
if [[ "${TELEGRAM_DRY_RUN:-}" != "true" ]]; then
  [[ "${TELEGRAM_ENABLED}" != "true" ]] && exit 0
  [[ -z "${TELEGRAM_BOT_TOKEN}" ]] && exit 0
  [[ -z "${TELEGRAM_CHAT_ID}" ]] && exit 0
fi

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
EVENT_TYPE="$(echo "${EVENT_ARG:-${HOOK_EVENT_NAME}}" | tr '[:upper:]' '[:lower:]')"

# ── NOTIFY_LEVEL gate ──────────────────────────────────────────────────────────
NOTIFY_LEVEL="${NOTIFY_LEVEL:-all}"
# Suppress stop and sessionEnd (Copilot's equivalent of stop) when notify_only
if [[ "${NOTIFY_LEVEL}" == "notify_only" && ("${EVENT_TYPE}" == "stop" || "${EVENT_TYPE}" == "sessionend") ]]; then
  exit 0
fi

# ── Detect AI CLI tool and project ────────────────────────────────────────────
# TOOL_NAME is supplied by the caller via $2 (hardcoded in registry.sh per tool).
# PROJECT_DIR resolves from env vars set by each AI CLI, falling back to PWD.
TOOL_NAME="${2:-AI CLI}"
PROJECT_DIR="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-${PWD}}}"

PROJECT_NAME=""
[[ -n "${PROJECT_DIR}" ]] && PROJECT_NAME="$(basename "${PROJECT_DIR}")"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ── Session identification ─────────────────────────────────────────────────────
# Source priority: stdin JSON .session_id (Claude) → stdin JSON .sessionId (Copilot)
# → env var GITHUB_COPILOT_SESSION_ID (first 8 chars, always prefixed with #)
SESSION_LABEL=""
SESSION_ID=""

if command -v jq &>/dev/null && [[ -n "${STDIN_JSON}" ]]; then
  SESSION_ID="$(echo "${STDIN_JSON}" | jq -r '.session_id // .sessionId // empty' 2>/dev/null)"
elif [[ -n "${STDIN_JSON}" ]]; then
  SESSION_ID="$(echo "${STDIN_JSON}" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
  if [[ -z "${SESSION_ID}" ]]; then
    SESSION_ID="$(echo "${STDIN_JSON}" | grep -o '"sessionId"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"sessionId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
  fi
fi

# Format stdin-sourced session: UUID (standard 8-4-4-4-12 format) → #<first8>; else direct
if [[ -n "${SESSION_ID}" ]]; then
  if [[ "${SESSION_ID}" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    SESSION_LABEL="#${SESSION_ID:0:8}"
  else
    SESSION_LABEL="${SESSION_ID}"
  fi
fi

# Env var fallback: always prefix with # (it's a raw ID fragment, not a readable name)
if [[ -z "${SESSION_LABEL}" ]] && [[ -n "${GITHUB_COPILOT_SESSION_ID:-}" ]]; then
  SESSION_LABEL="#${GITHUB_COPILOT_SESSION_ID:0:8}"
fi

TITLE_SUFFIX=""
[[ -n "${SESSION_LABEL}" ]] && TITLE_SUFFIX=" (${SESSION_LABEL})"

# ── Hook event tag (appended to message line) ─────────────────────────────────
EVENT_TAG="#${HOOK_EVENT_NAME:-${EVENT_TYPE:-unknown}}"

# ── Build message ──────────────────────────────────────────────────────────────
MESSAGE=""

case "${EVENT_TYPE}" in
  stop|afteragent|sessionend)
    MESSAGE="🟢 **Task Complete**${TITLE_SUFFIX}

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

    MESSAGE="🟠 **Action Required**${TITLE_SUFFIX}

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

# ── Send via Telegram Bot API (or dry-run) ─────────────────────────────────────
if [[ "${TELEGRAM_DRY_RUN:-}" == "true" ]]; then
  echo "${MESSAGE}"
  exit 0
fi

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

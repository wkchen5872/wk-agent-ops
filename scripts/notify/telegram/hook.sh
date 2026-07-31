#!/usr/bin/env bash
# Telegram notification hook for AI CLI.
# Deployed to: ~/.config/ai-notify/hooks/telegram-notify.sh
# Called with: $1 = provider event type,
#              $2 = tool name (optional),
#              JSON on stdin.
# Always exits 0 — never blocks the calling AI CLI.

# ── Load config ────────────────────────────────────────────────────────────────
# Save env vars that should take priority over config file values (e.g., in tests).
_SAVED_NOTIFY_LEVEL="${NOTIFY_LEVEL:-}"
# shellcheck source=/dev/null
source "${HOME}/.config/ai-notify/config" 2>/dev/null || true
# Restore explicitly-set env vars (env var > config file, following Unix convention).
[[ -n "${_SAVED_NOTIFY_LEVEL}" ]] && NOTIFY_LEVEL="${_SAVED_NOTIFY_LEVEL}"

# ── Read stdin ─────────────────────────────────────────────────────────────────
STDIN_JSON=""
if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
  STDIN_JSON="$(cat)"
fi

# Extract a string field from JSON; tries fields left-to-right (jq or grep fallback).
_json_str() {
  local json="$1"; shift
  if command -v jq &>/dev/null; then
    local expr
    expr="$(printf '.%s // ' "$@")empty"
    echo "${json}" | jq -r "${expr}" 2>/dev/null
  else
    local field val
    for field in "$@"; do
      val="$(echo "${json}" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | \
             sed "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/")"
      [[ -n "${val}" ]] && { echo "${val}"; return; }
    done
  fi
}

# Extract a jq expression when jq is available; callers provide safe constants.
_json_query() {
  local json="$1"
  local expression="$2"
  command -v jq &>/dev/null || return 0
  echo "${json}" | jq -r "${expression} // empty" 2>/dev/null
}

# ── Detect event type ──────────────────────────────────────────────────────────
# Primary source: $1 argument (stop | notification)
# Fallback: parse stdin JSON hook_event_name
EVENT_ARG="${1:-}"
HOOK_EVENT_NAME=""
[[ -n "${STDIN_JSON}" ]] && HOOK_EVENT_NAME="$(_json_str "${STDIN_JSON}" "hook_event_name")"

# Normalised lowercase for branching
EVENT_TYPE="$(echo "${EVENT_ARG:-${HOOK_EVENT_NAME}}" | tr '[:upper:]' '[:lower:]')"

AGY_AGENT_STATE=""
if [[ "${EVENT_TYPE}" == "antigravity-statusline" ]]; then
  AGY_AGENT_STATE="$(_json_str "${STDIN_JSON}" "agent_state")"
  [[ -z "${AGY_AGENT_STATE}" ]] && AGY_AGENT_STATE="antigravity"
fi

# Return control output required by native providers without changing their
# approval or stop decisions. Dry-run reserves stdout for the Telegram message.
finish_hook() {
  if [[ "${EVENT_TYPE}" == "antigravity-statusline" ]]; then
    printf '%s\n' "${AGY_AGENT_STATE}"
    exit 0
  fi
  if [[ "${TELEGRAM_DRY_RUN:-}" != "true" ]]; then
    case "${EVENT_TYPE}" in
      codex-stop|codex-permission) printf '{}\n' ;;
      antigravity-stop) printf '{"decision":"stop"}\n' ;;
    esac
  fi
  exit 0
}

# ── Notification level ─────────────────────────────────────────────────────────
NOTIFY_LEVEL="${NOTIFY_LEVEL:-all}"
[[ "${NOTIFY_LEVEL}" == "notify_only" ]] && NOTIFY_LEVEL="attention_required"
[[ "${NOTIFY_LEVEL}" != "all" && "${NOTIFY_LEVEL}" != "attention_required" ]] && NOTIFY_LEVEL="all"

# ── Detect AI CLI tool and project ────────────────────────────────────────────
# TOOL_NAME is supplied by the caller via $2 (hardcoded in registry.sh per tool).
# PROJECT_DIR prefers a documented payload cwd, then provider env vars and PWD.
TOOL_NAME="${2:-AI CLI}"
PAYLOAD_CWD=""
[[ -n "${STDIN_JSON}" ]] && PAYLOAD_CWD="$(_json_str "${STDIN_JSON}" "cwd")"
PAYLOAD_WORKSPACE=""
[[ -n "${STDIN_JSON}" ]] && PAYLOAD_WORKSPACE="$(_json_query "${STDIN_JSON}" '.workspacePaths[0] // .workspace.project_dir // .workspace.current_dir')"
PROJECT_DIR="${PAYLOAD_CWD:-${PAYLOAD_WORKSPACE:-${CLAUDE_PROJECT_DIR:-${PWD}}}}"

PROJECT_NAME="${PROJECT_DIR:+$(basename "${PROJECT_DIR}")}"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ── Session identification ─────────────────────────────────────────────────────
# Source priority: provider payload session/conversation fields
# → env var GITHUB_COPILOT_SESSION_ID (first 8 chars, always prefixed with #)
SESSION_LABEL=""
SESSION_ID=""
[[ -n "${STDIN_JSON}" ]] && SESSION_ID="$(_json_str "${STDIN_JSON}" "session_id" "sessionId" "conversation_id" "conversationId")"

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

# ── Antigravity approval transition ───────────────────────────────────────────
if [[ "${EVENT_TYPE}" == "antigravity-statusline" ]]; then
  AGY_CONFIRMATION_PENDING="$(_json_query "${STDIN_JSON}" 'if .tool_confirmation_pending == true then "true" else "false" end')"
  AGY_STATE_KEY="$(printf '%s' "${SESSION_ID:-default}" | tr -cd '[:alnum:]_.-')"
  [[ -z "${AGY_STATE_KEY}" ]] && AGY_STATE_KEY="default"
  AGY_STATE_DIR="${HOME}/.config/ai-notify/state"
  AGY_STATE_FILE="${AGY_STATE_DIR}/antigravity-${AGY_STATE_KEY}.pending"

  if [[ "${AGY_CONFIRMATION_PENDING}" != "true" ]]; then
    rm -f -- "${AGY_STATE_FILE}"
    finish_hook
  fi

  [[ -f "${AGY_STATE_FILE}" ]] && finish_hook
  mkdir -p "${AGY_STATE_DIR}"
  chmod 700 "${AGY_STATE_DIR}" 2>/dev/null || true
  : > "${AGY_STATE_FILE}"
  chmod 600 "${AGY_STATE_FILE}" 2>/dev/null || true
fi

# Antigravity Stop is meaningful only after all background work is idle.
AGY_TERMINATION_REASON=""
if [[ "${EVENT_TYPE}" == "antigravity-stop" ]]; then
  AGY_FULLY_IDLE="$(_json_query "${STDIN_JSON}" 'if .fullyIdle == true then "true" else "false" end')"
  [[ "${AGY_FULLY_IDLE}" != "true" ]] && finish_hook
  AGY_TERMINATION_REASON="$(_json_str "${STDIN_JSON}" "terminationReason")"
fi

# Classify provider spellings once, then apply one semantic policy gate.
EVENT_CATEGORY="unknown"
case "${EVENT_TYPE}" in
  stop|sessionend|codex-stop) EVENT_CATEGORY="completion" ;;
  notification|userpromptsubmitted|codex-permission|antigravity-statusline) EVENT_CATEGORY="action_required" ;;
  antigravity-stop)
    if [[ "${AGY_TERMINATION_REASON}" == "model_stop" ]]; then
      EVENT_CATEGORY="completion"
    else
      EVENT_CATEGORY="failure"
    fi
    ;;
esac

if [[ "${NOTIFY_LEVEL}" == "attention_required" &&
      "${EVENT_CATEGORY}" != "action_required" &&
      "${EVENT_CATEGORY}" != "failure" ]]; then
  finish_hook
fi

# ── Guard: skip if disabled or credentials missing ─────────────────────────────
# State transitions and native event classification happen before this guard.
if [[ "${TELEGRAM_DRY_RUN:-}" != "true" ]]; then
  [[ "${TELEGRAM_ENABLED:-}" != "true" ]] && finish_hook
  [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] && finish_hook
  [[ -z "${TELEGRAM_CHAT_ID:-}" ]] && finish_hook
fi

# ── Hook event tag (appended to message line) ─────────────────────────────────
EVENT_TAG="#${HOOK_EVENT_NAME:-${EVENT_TYPE:-unknown}}"

# ── Build message ──────────────────────────────────────────────────────────────
MESSAGE=""

case "${EVENT_TYPE}" in
  stop|sessionend|codex-stop)
    MESSAGE="🟢 **Task Complete**${TITLE_SUFFIX}

🤖 ${TOOL_NAME}
📂 ${PROJECT_NAME}
⏰ ${TIMESTAMP}

Process finished successfully ${EVENT_TAG}"
    ;;

  antigravity-stop)
    if [[ "${AGY_TERMINATION_REASON}" == "model_stop" ]]; then
      MESSAGE="🟢 **Task Complete**${TITLE_SUFFIX}

🤖 ${TOOL_NAME}
📂 ${PROJECT_NAME}
⏰ ${TIMESTAMP}

Process finished successfully ${EVENT_TAG}"
    else
      case "${AGY_TERMINATION_REASON}" in
        error) STOP_REASON="error" ;;
        max_steps_exceeded) STOP_REASON="max steps exceeded" ;;
        *) STOP_REASON="execution stopped" ;;
      esac
      MESSAGE="🔴 **Task Stopped**${TITLE_SUFFIX}

🤖 ${TOOL_NAME}
📂 ${PROJECT_NAME}
⏰ ${TIMESTAMP}

Execution ended: ${STOP_REASON} ${EVENT_TAG}"
    fi
    ;;

  codex-permission)
    REQUEST_TOOL=""
    [[ -n "${STDIN_JSON}" ]] && REQUEST_TOOL="$(_json_str "${STDIN_JSON}" "tool_name")"
    [[ -z "${REQUEST_TOOL}" ]] && REQUEST_TOOL="a tool"

    MESSAGE="🟠 **Action Required**${TITLE_SUFFIX}

🤖 ${TOOL_NAME}
📂 ${PROJECT_NAME}
⏰ ${TIMESTAMP}

Approval requested for ${REQUEST_TOOL} ${EVENT_TAG}"
    ;;

  antigravity-statusline)
    MESSAGE="🟠 **Action Required**${TITLE_SUFFIX}

🤖 ${TOOL_NAME}
📂 ${PROJECT_NAME}
⏰ ${TIMESTAMP}

Tool confirmation is waiting ${EVENT_TAG}"
    ;;

  notification|userpromptsubmitted)
    NOTIFICATION_MSG=""
    [[ -n "${STDIN_JSON}" ]] && NOTIFICATION_MSG="$(_json_str "${STDIN_JSON}" "message")"

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
  finish_hook
fi

TELEGRAM_API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

curl \
  --silent \
  --max-time 4 \
  --output /dev/null \
  -X POST "${TELEGRAM_API}" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "parse_mode=Markdown" \
  --data-urlencode "text=${MESSAGE}" \
  || true

finish_hook

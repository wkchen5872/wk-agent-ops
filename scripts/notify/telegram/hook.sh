#!/usr/bin/env bash
# Telegram notification hook for AI CLI.
# Deployed to: ~/.config/ai-notify/hooks/telegram-notify.sh
# Called with: $1 = provider event type,
#              $2 = tool name (optional),
#              JSON on stdin.
# Always exits 0 — never blocks the calling AI CLI.
# The handoff hook reads the next line to decide whether this hook takes handoff events.
# ai-notify-capability: handoff-events

# ── Load config ────────────────────────────────────────────────────────────────
# Save env vars that should take priority over config file values (e.g., in tests).
# Category switches are resolved by config.sh, which keeps env and file apart.
_NOTIFY_ENV_KEYS=(NOTIFY_LEVEL NOTIFY_AUTHORIZATION_DELAY_SECONDS NOTIFY_AUTHORIZATION_REARM_SECONDS)
_NOTIFY_ENV_VALUES=()
for _notify_key in "${_NOTIFY_ENV_KEYS[@]}"; do
  _NOTIFY_ENV_VALUES+=("${!_notify_key:-}")
done
NOTIFY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/config.sh
source "${NOTIFY_SCRIPT_DIR}/../lib/config.sh" 2>/dev/null || true
# shellcheck source=../lib/template.sh
source "${NOTIFY_SCRIPT_DIR}/../lib/template.sh" 2>/dev/null || true
# shellcheck source=../lib/authorization.sh
source "${NOTIFY_SCRIPT_DIR}/../lib/authorization.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "${HOME}/.config/ai-notify/config" 2>/dev/null || true
# Restore explicitly-set env vars (env var > config file, following Unix convention).
for ((_notify_i=0; _notify_i<${#_NOTIFY_ENV_KEYS[@]}; _notify_i++)); do
  if [[ -n "${_NOTIFY_ENV_VALUES[_notify_i]}" ]]; then
    printf -v "${_NOTIFY_ENV_KEYS[_notify_i]}" '%s' "${_NOTIFY_ENV_VALUES[_notify_i]}"
  fi
done

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
      codex-stop|codex-permission|codex-question|codex-async-question|codex-human-approval|codex-user-input) printf '{}\n' ;;
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

# Permission hooks serve authorization; question hooks serve user input.
start_codex_inspection() {
  [[ "${TELEGRAM_ENABLED:-}" == true && "${TELEGRAM_DRY_RUN:-}" != true ]] || return 0
  notify_category_enabled "$1" || return 0
  local python="${HOME}/.config/ai-notify/runtime/codex-wait/bin/python3"
  local checker="${NOTIFY_SCRIPT_DIR}/codex-wait.py" trigger
  [[ -x "${python}" && -f "${checker}" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  trigger="$(printf '%s' "${STDIN_JSON}" | jq -c --arg kind "$2" \
    '{session_id,turn_id,cwd,tool_name,transcript_path,kind:$kind}' 2>/dev/null)" || return 0
  printf '%s' "${trigger}" | "${python}" "${checker}" start >/dev/null 2>&1 || true
}

case "${EVENT_TYPE}" in
  # The checker confirms Codex waits after the delay; nothing is sent when the request is raised.
  codex-permission) start_codex_inspection NOTIFY_AUTHORIZATION permission; finish_hook ;;
  codex-question)
    [[ "$(_json_str "${STDIN_JSON}" tool_name)" == request_user_input_async ]] || start_codex_inspection NOTIFY_USER_INPUT question
    finish_hook
    ;;
  codex-async-question)
    [[ "${HOOK_EVENT_NAME}" == PostToolUse && "$(_json_str "${STDIN_JSON}" tool_name)" == request_user_input_async ]] || finish_hook
    # Async questions are posted as messages and never raise a daemon wait flag.
    ASYNC_ACCEPTED="$(_json_query "${STDIN_JSON}" '.tool_response | (if type == "string" then fromjson? else . end) | select(.accepted == true) | "true"')"
    [[ "${ASYNC_ACCEPTED}" == true ]] || finish_hook
    EVENT_TYPE=codex-user-input
    HOOK_EVENT_NAME=AsyncUserInputRequested
    ;;
esac

# ── Authorization waits: resolution evidence and turn ends clear the marker ────
# These run before any switch or delivery guard, so a disabled Telegram still clears.
SESSION_KEY="$(printf '%s' "${SESSION_ID:-default}" | tr -cd '[:alnum:]_.-')"
[[ -z "${SESSION_KEY}" ]] && SESSION_KEY="default"
case "${EVENT_TYPE}" in
  stop) auth_clear "$(auth_marker claude "${SESSION_KEY}")" ;;
  antigravity-stop) auth_clear "$(auth_marker antigravity "${SESSION_KEY}")" ;;
  antigravity-statusline)
    if [[ "$(_json_query "${STDIN_JSON}" 'if .tool_confirmation_pending == true then "true" else "false" end')" != "true" ]]; then
      auth_clear "$(auth_marker antigravity "${SESSION_KEY}")"
      finish_hook
    fi
    ;;
esac

# Antigravity Stop is meaningful only after all background work is idle.
EVENT_KEY="${EVENT_TYPE}"
# Handoff loop events: the kind selects the table row.
[[ "${EVENT_TYPE}" == "handoff" ]] && EVENT_KEY="handoff:$(_json_str "${STDIN_JSON}" kind | tr -cd 'a-z')"
if [[ "${EVENT_TYPE}" == "antigravity-stop" ]]; then
  AGY_FULLY_IDLE="$(_json_query "${STDIN_JSON}" 'if .fullyIdle == true then "true" else "false" end')"
  [[ "${AGY_FULLY_IDLE}" != "true" ]] && finish_hook
  AGY_TERMINATION_REASON="$(_json_str "${STDIN_JSON}" "terminationReason" | tr '[:upper:]' '[:lower:]')"
  EVENT_KEY="antigravity-stop:${AGY_TERMINATION_REASON}"
fi
# Claude Code: the last tool call without a result in the session record.
# Prints "<id><TAB><tool name>"; fails when the record cannot be read.
claude_pending_call() {
  [[ -r "$1" ]] && command -v jq >/dev/null 2>&1 || return 1
  tail -n 400 "$1" | jq -Rrn '
    [inputs | fromjson? | .message.content? | arrays | .[] | objects] as $items
    | [$items[] | select(.type == "tool_result") | .tool_use_id] as $done
    | [$items[] | select(.type == "tool_use") | select(.id as $id | $done | any(. == $id) | not)]
    | last | select(. != null) | "\(.id)\t\(.name // "")"' 2>/dev/null
}

# claude_has_result <record> <tool_use id> — a tool_result for that id, matched structurally.
# grep only narrows the lines; jq decides, so JSON spacing does not matter.
claude_has_result() {
  command -v jq >/dev/null 2>&1 || return 1
  grep -F -- "$2" "$1" 2>/dev/null | jq -Rne --arg id "$2" '
    [inputs | fromjson? | .message.content? | arrays | .[] | objects
     | select(.type == "tool_result" and .tool_use_id == $id)] | length > 0' >/dev/null 2>&1
}

# Claude Code tells notification kinds apart by notification_type. A permission prompt
# for AskUserQuestion is a question, not an authorization wait (D-002).
if [[ "${EVENT_TYPE}" == "notification" ]]; then
  NOTIFICATION_TYPE="$(_json_str "${STDIN_JSON}" "notification_type" | tr '[:upper:]' '[:lower:]')"
  [[ -n "${NOTIFICATION_TYPE}" ]] && EVENT_KEY="notification:${NOTIFICATION_TYPE}"
  if [[ "${NOTIFICATION_TYPE}" == "permission_prompt" ]]; then
    CLAUDE_TRANSCRIPT="$(_json_str "${STDIN_JSON}" "transcript_path")"
    CLAUDE_CALL="$(claude_pending_call "${CLAUDE_TRANSCRIPT}")" || CLAUDE_CALL=""
    CLAUDE_CALL_ID="$(printf '%s' "${CLAUDE_CALL%%$'\t'*}" | tr -cd '[:alnum:]_-' | cut -c1-128)"
    CLAUDE_CALL_TOOL="$(printf '%s' "${CLAUDE_CALL#*$'\t'}" | tr -cd '[:alnum:]_.:-' | cut -c1-64)"
    [[ -z "${CLAUDE_CALL}" ]] && CLAUDE_CALL_TOOL=""
    [[ "${CLAUDE_CALL_TOOL}" == "AskUserQuestion" ]] && EVENT_KEY="notification:question"
  fi
fi

# ── Resolve the event through the data table ──────────────────────────────────
# Row: key, category, template, reason label. "<prefix>:*" catches unlisted details.
EVENT_CATEGORY="unknown"
EVENT_TEMPLATE="generic"
EVENT_REASON=""
lookup_event() {
  local table="${NOTIFY_SCRIPT_DIR}/events.tsv" key category template reason
  [[ -r "${table}" ]] || return 1
  while IFS=$'\t' read -r key category template reason; do
    [[ "${key}" == "$1" ]] || continue
    EVENT_CATEGORY="${category}"; EVENT_TEMPLATE="${template:-generic}"; EVENT_REASON="${reason}"
    return 0
  done < "${table}"
  return 1
}
lookup_event "${EVENT_KEY}" || { [[ "${EVENT_KEY}" == *:* ]] && lookup_event "${EVENT_KEY%%:*}:*"; } || true
# The handoff loop is stopped until the user acts, so attention survives a missing row.
if [[ "${EVENT_KEY}" == "handoff:attention" ]]; then
  EVENT_CATEGORY="attention"
  [[ "${EVENT_TEMPLATE}" == "-" || "${EVENT_TEMPLATE}" == "generic" ]] && EVENT_TEMPLATE="handoff-attention"
fi

case "${EVENT_CATEGORY}" in
  completion) notify_category_enabled NOTIFY_COMPLETION || finish_hook ;;
  authorization) notify_category_enabled NOTIFY_AUTHORIZATION || finish_hook ;;
  user_input) notify_category_enabled NOTIFY_USER_INPUT || finish_hook ;;
  failure) notify_category_enabled NOTIFY_FAILURE || finish_hook ;;
  handoff_implement) notify_category_enabled NOTIFY_HANDOFF_IMPLEMENT || finish_hook ;;
  handoff_review) notify_category_enabled NOTIFY_HANDOFF_REVIEW || finish_hook ;;
  handoff_finish) notify_category_enabled NOTIFY_HANDOFF_FINISH || finish_hook ;;
  attention) ;;
  none) finish_hook ;;
  *) [[ "${NOTIFY_LEVEL}" == attention_required ]] && finish_hook ;;
esac

# ── Guard: skip if disabled or credentials missing ─────────────────────────────
# State transitions and native event classification happen before this guard.
if [[ "${TELEGRAM_DRY_RUN:-}" != "true" ]]; then
  [[ "${TELEGRAM_ENABLED:-}" != "true" ]] && finish_hook
  [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] && finish_hook
  [[ -z "${TELEGRAM_CHAT_ID:-}" ]] && finish_hook
fi

# ── Template values ───────────────────────────────────────────────────────────
AUTH_DELAY="$(auth_seconds "${NOTIFY_AUTHORIZATION_DELAY_SECONDS:-}" 30)"
AUTH_REARM="$(auth_seconds "${NOTIFY_AUTHORIZATION_REARM_SECONDS:-}" 600)"
tpl_title_suffix="${TITLE_SUFFIX}"
tpl_tool="${TOOL_NAME}"
tpl_project="${PROJECT_NAME}"
tpl_time="${TIMESTAMP}"
tpl_tag="#${HOOK_EVENT_NAME:-${EVENT_TYPE:-unknown}}"
tpl_reason="${EVENT_REASON}"
tpl_delay="${AUTH_DELAY}"
tpl_message=""
[[ -n "${STDIN_JSON}" ]] && tpl_message="$(_json_str "${STDIN_JSON}" "message")"
[[ -z "${tpl_message}" ]] && tpl_message="Waiting for user interaction..."
# Only a generic tool label ever reaches a message, never its input.
tpl_request_tool=""
[[ -n "${STDIN_JSON}" ]] && tpl_request_tool="$(_json_str "${STDIN_JSON}" "tool_name" | tr -cd '[:alnum:]_.:-' | cut -c1-64)"
[[ -z "${tpl_request_tool}" ]] && tpl_request_tool="a tool"

if [[ "${EVENT_TYPE}" == "handoff" ]]; then
  tpl_agent="Agent Handoff"
  _handoff_agent="$(_json_str "${STDIN_JSON}" agent)"
  [[ -n "${_handoff_agent}" ]] && tpl_agent+=" (${_handoff_agent})"
  tpl_change="$(_json_str "${STDIN_JSON}" change)"
  tpl_round="$(_json_str "${STDIN_JSON}" round)"
  tpl_commit="$(_json_str "${STDIN_JSON}" commit)"
  tpl_next="$(_json_str "${STDIN_JSON}" next)"
  tpl_detail="$(_json_str "${STDIN_JSON}" detail)"
  tpl_verdict="$(_json_str "${STDIN_JSON}" verdict)"
  case "${tpl_verdict}" in
    changes-required) tpl_verdict="🔁 審查退回" ;;
    pass) tpl_verdict="🟢 審查通過" ;;
  esac
fi
# Built-in attention text for a deployment without the handoff-attention template.
HANDOFF_ATTENTION_TEXT='🔴 **需要你處理** · {agent}{title_suffix}

📋 {change} · 第 {round} 輪 · commit {commit}
📂 {project}

{detail}
➡️ {next}'

# deliver <template> — render and send; dry-run prints instead.
# Authorization notices carry metadata only, whatever a user template asks for.
deliver() {
  local text
  case "$1" in
    authorization*) local tpl_message="" tpl_reason="" ;;
  esac
  if ! text="$(notify_render "$1" "${NOTIFY_SCRIPT_DIR}/templates")"; then
    if [[ "$1" == "handoff-attention" ]]; then
      text="$(notify_render_text "${HANDOFF_ATTENTION_TEXT}")"
    else
      text="$(notify_render generic "${NOTIFY_SCRIPT_DIR}/templates")" || return 0
    fi
  fi
  if [[ "${TELEGRAM_DRY_RUN:-}" == "true" ]]; then
    printf '%s\n' "${text}"
    return 0
  fi
  curl \
    --silent \
    --max-time 4 \
    --output /dev/null \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=Markdown" \
    --data-urlencode "text=${text}" \
    || true
}

# ── Delayed authorization confirmation (notify-authorization-wait) ─────────────

# auth_verdict <provider> — pending, resolved, or unknown for the wait in AUTH_*.
auth_verdict() {
  case "$1" in
    claude)
      [[ -r "${CLAUDE_TRANSCRIPT}" ]] || { echo unknown; return; }
      if [[ "${AUTH_IDED}" == 1 ]]; then
        claude_has_result "${CLAUDE_TRANSCRIPT}" "${AUTH_ID}" && echo resolved || echo pending
      else
        local call
        call="$(claude_pending_call "${CLAUDE_TRANSCRIPT}")" || { echo unknown; return; }
        [[ -n "${call}" ]] && echo pending || echo resolved
      fi
      ;;
    *) echo pending ;;  # Antigravity: the marker survives only while no false status arrived.
  esac
}

# The background check acts only on the wait it was started for (design decision 3).
authorization_check() {
  local provider="$1" marker="$2" id="$3" verdict now
  sleep "${AUTH_DELAY}"
  auth_lock "${marker}" 100 || return 0
  if ! auth_read "${marker}" || [[ "${AUTH_ID}" != "${id}" || "${AUTH_NOTIFIED}" -gt 0 ]]; then
    auth_unlock "${marker}"
    return 0
  fi
  verdict="$(auth_verdict "${provider}")"
  now="$(date +%s)"
  if [[ "${verdict}" == resolved ]]; then
    rm -f -- "${marker}"
    auth_unlock "${marker}"
    return 0
  fi
  auth_write "${marker}" "${AUTH_ID}" "${AUTH_IDED}" "${AUTH_STARTED}" "${now}" "${AUTH_TOOL}"
  auth_unlock "${marker}"
  # The network call happens outside the lock.
  tpl_time="$(date '+%Y-%m-%d %H:%M:%S')"
  tpl_request_tool="${AUTH_TOOL:-a tool}"
  if [[ "${verdict}" == pending ]]; then deliver authorization; else deliver authorization-unconfirmed; fi
}

# authorization_start <provider> <identity or empty> <tool label>
authorization_start() {
  local provider="$1" identity="$2" label="${3:-a tool}" marker now id ided=0 verdict
  marker="$(auth_marker "${provider}" "${SESSION_KEY}")"
  auth_lock "${marker}" 30 || return 0
  now="$(date +%s)"
  if [[ "$(auth_decide "${marker}" "${identity}" "${AUTH_REARM}" "${now}")" != new ]]; then
    auth_unlock "${marker}"
    return 0
  fi
  id="${identity}"
  [[ -n "${id}" ]] && ided=1 || id="$(auth_new_id)"
  if [[ "${AUTH_DELAY}" -eq 0 ]]; then
    # Delay 0 changes the timing only; the evidence and wording rules still apply.
    AUTH_ID="${id}" AUTH_IDED="${ided}"
    verdict="$(auth_verdict "${provider}")"
    if [[ "${verdict}" == resolved ]]; then
      rm -f -- "${marker}"
      auth_unlock "${marker}"
      return 0
    fi
    auth_write "${marker}" "${id}" "${ided}" "${now}" "${now}" "${label}"
    auth_unlock "${marker}"
    tpl_request_tool="${label}"
    if [[ "${verdict}" == pending ]]; then deliver authorization; else deliver authorization-unconfirmed; fi
    return 0
  fi
  auth_write "${marker}" "${id}" "${ided}" "${now}" 0 "${label}"
  auth_unlock "${marker}"
  [[ "${TELEGRAM_DRY_RUN:-}" == "true" ]] && return 0
  ( authorization_check "${provider}" "${marker}" "${id}" ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

case "${EVENT_KEY}" in
  notification:permission_prompt)
    authorization_start claude "${CLAUDE_CALL_ID}" "${CLAUDE_CALL_TOOL}"
    finish_hook
    ;;
  antigravity-statusline)
    authorization_start antigravity "" ""
    finish_hook
    ;;
esac

deliver "${EVENT_TEMPLATE}"
finish_hook

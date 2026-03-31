#!/usr/bin/env bash
# Shared hook registry library for ~/.claude/settings.json and ~/.gemini/settings.json
# This file only defines functions — it does NOT write anything on source.
# Requires: jq

CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
GEMINI_SETTINGS="${HOME}/.gemini/settings.json"

# Ensure a settings.json file exists with a valid JSON object.
_ensure_settings_file() {
  local file="$1"
  local dir
  dir="$(dirname "${file}")"
  mkdir -p "${dir}"
  if [[ ! -f "${file}" ]] || ! jq empty "${file}" 2>/dev/null; then
    echo '{}' > "${file}"
  fi
}

# Register the telegram-notify hook into a settings.json file (idempotent).
# Writes the correct Claude Code nested format:
#   "Stop": [{ "hooks": [{ "type": "command", "command": "...", "async": true, "timeout": 15 }] }]
# Arguments: $1 = settings file path, $2 = deployed hook path
_register_hooks_in_file() {
  local settings_file="$1"
  local hook_path="$2"

  _ensure_settings_file "${settings_file}"

  local stop_cmd="bash \"${hook_path}\" stop"
  local notify_cmd="bash \"${hook_path}\" notification"

  local tmp
  tmp="$(mktemp)"

  # Build the correctly nested hook group objects
  local stop_group notify_group
  stop_group=$(jq -n --arg cmd "${stop_cmd}" \
    '{"hooks":[{"type":"command","command":$cmd,"async":true,"timeout":15}]}')
  notify_group=$(jq -n --arg cmd "${notify_cmd}" \
    '{"hooks":[{"type":"command","command":$cmd,"async":true,"timeout":15}]}')

  # Idempotent merge: only add group if no existing group already contains this command.
  # Also handles migration from old flat format (direct {"type","command"} objects).
  if jq \
    --argjson stop_group "${stop_group}" \
    --argjson notify_group "${notify_group}" \
    --arg stop_cmd "${stop_cmd}" \
    --arg notify_cmd "${notify_cmd}" \
    '
    # Returns true if the array already has a nested-format group containing cmd,
    # OR an old flat-format entry with that command (to prevent double-registration
    # when the old format is still present).
    def has_command(arr; cmd):
      if arr == null then false
      else (arr | map(
        select(
          (.command? == cmd) or
          (.hooks? != null and (.hooks | map(select(.command == cmd)) | length) > 0)
        )
      ) | length) > 0
      end;

    .hooks.Stop = (
      if has_command(.hooks.Stop; $stop_cmd) then .hooks.Stop
      else ((.hooks.Stop // []) + [$stop_group])
      end
    ) |
    .hooks.Notification = (
      if has_command(.hooks.Notification; $notify_cmd) then .hooks.Notification
      else ((.hooks.Notification // []) + [$notify_group])
      end
    )
    ' "${settings_file}" > "${tmp}"; then
    mv "${tmp}" "${settings_file}"
  else
    rm -f "${tmp}"
    return 1
  fi
}

# Unregister the telegram-notify hook from a settings.json file.
# Handles both old flat format and new nested format for smooth migration.
# Arguments: $1 = settings file path, $2 = deployed hook path
_unregister_hooks_in_file() {
  local settings_file="$1"
  local hook_path="$2"

  if [[ ! -f "${settings_file}" ]]; then
    return
  fi

  local stop_cmd="bash \"${hook_path}\" stop"
  local notify_cmd="bash \"${hook_path}\" notification"

  local tmp
  tmp="$(mktemp)"

  if jq \
    --arg stop_cmd "${stop_cmd}" \
    --arg notify_cmd "${notify_cmd}" \
    '
    # Remove Stop entries — handles both flat format and nested format groups
    if .hooks.Stop then
      .hooks.Stop = (.hooks.Stop | map(select(
        (.command? // "") != $stop_cmd and
        (.hooks? == null or (.hooks | map(select(.command == $stop_cmd)) | length) == 0)
      )))
    else . end |

    # Remove Notification entries — same dual-format handling
    if .hooks.Notification then
      .hooks.Notification = (.hooks.Notification | map(select(
        (.command? // "") != $notify_cmd and
        (.hooks? == null or (.hooks | map(select(.command == $notify_cmd)) | length) == 0)
      )))
    else . end
    ' "${settings_file}" > "${tmp}"; then
    mv "${tmp}" "${settings_file}"
  else
    rm -f "${tmp}"
    return 1
  fi
}

# Public: register the telegram-notify hook in all supported AI CLI settings files.
# Usage: register_hook <deployed_hook_path>
register_hook() {
  local hook_path="$1"

  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed. Please install jq and re-run." >&2
    return 1
  fi

  _register_hooks_in_file "${CLAUDE_SETTINGS}" "${hook_path}"
  echo "  ✓ Registered hooks in ${CLAUDE_SETTINGS}"

  # Register in Gemini settings if the directory exists
  if [[ -d "${HOME}/.gemini" ]] || [[ -f "${GEMINI_SETTINGS}" ]]; then
    _register_hooks_in_file "${GEMINI_SETTINGS}" "${hook_path}"
    echo "  ✓ Registered hooks in ${GEMINI_SETTINGS}"
  fi
}

# Public: unregister the telegram-notify hook from all supported AI CLI settings files.
# Usage: unregister_hook <deployed_hook_path>
unregister_hook() {
  local hook_path="$1"

  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed. Please install jq and re-run." >&2
    return 1
  fi

  _unregister_hooks_in_file "${CLAUDE_SETTINGS}" "${hook_path}"
  echo "  ✓ Unregistered hooks from ${CLAUDE_SETTINGS}"

  if [[ -f "${GEMINI_SETTINGS}" ]]; then
    _unregister_hooks_in_file "${GEMINI_SETTINGS}" "${hook_path}"
    echo "  ✓ Unregistered hooks from ${GEMINI_SETTINGS}"
  fi
}

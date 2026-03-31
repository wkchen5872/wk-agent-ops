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
# Arguments: $1 = settings file path, $2 = deployed hook path
_register_hooks_in_file() {
  local settings_file="$1"
  local hook_path="$2"

  _ensure_settings_file "${settings_file}"

  local tmp
  tmp="$(mktemp)"

  # Build the hook entries we want to ensure exist
  # Stop hook
  local stop_hook
  stop_hook=$(jq -n --arg cmd "bash \"${hook_path}\" stop" \
    '{"type":"command","command":$cmd}')

  # Notification hook
  local notify_hook
  notify_hook=$(jq -n --arg cmd "bash \"${hook_path}\" notification" \
    '{"type":"command","command":$cmd}')

  # Idempotent merge: add Stop hook if not already present
  if jq \
    --argjson stop_hook "${stop_hook}" \
    --argjson notify_hook "${notify_hook}" \
    '
    # Helper: check if hooks array contains a command entry for the hook path
    def has_hook(arr; entry):
      if arr == null then false
      else (arr | map(select(.command == entry.command)) | length) > 0
      end;

    # Ensure .hooks.Stop array exists and contains the stop hook
    .hooks.Stop = (
      if has_hook(.hooks.Stop; $stop_hook) then .hooks.Stop
      else ((.hooks.Stop // []) + [$stop_hook])
      end
    ) |

    # Ensure .hooks.Notification array exists and contains the notification hook
    .hooks.Notification = (
      if has_hook(.hooks.Notification; $notify_hook) then .hooks.Notification
      else ((.hooks.Notification // []) + [$notify_hook])
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
# Arguments: $1 = settings file path, $2 = deployed hook path
_unregister_hooks_in_file() {
  local settings_file="$1"
  local hook_path="$2"

  if [[ ! -f "${settings_file}" ]]; then
    return
  fi

  local tmp
  tmp="$(mktemp)"

  local stop_cmd="bash \"${hook_path}\" stop"
  local notify_cmd="bash \"${hook_path}\" notification"

  if jq \
    --arg stop_cmd "${stop_cmd}" \
    --arg notify_cmd "${notify_cmd}" \
    '
    # Remove matching entries from Stop
    if .hooks.Stop then
      .hooks.Stop = (.hooks.Stop | map(select(.command != $stop_cmd)))
    else . end |

    # Remove matching entries from Notification
    if .hooks.Notification then
      .hooks.Notification = (.hooks.Notification | map(select(.command != $notify_cmd)))
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
  echo "✓ Registered hooks in ${CLAUDE_SETTINGS}"

  # Register in Gemini settings if the directory exists or we can create it
  if [[ -d "${HOME}/.gemini" ]] || [[ -f "${GEMINI_SETTINGS}" ]]; then
    _register_hooks_in_file "${GEMINI_SETTINGS}" "${hook_path}"
    echo "✓ Registered hooks in ${GEMINI_SETTINGS}"
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
  echo "✓ Unregistered hooks from ${CLAUDE_SETTINGS}"

  if [[ -f "${GEMINI_SETTINGS}" ]]; then
    _unregister_hooks_in_file "${GEMINI_SETTINGS}" "${hook_path}"
    echo "✓ Unregistered hooks from ${GEMINI_SETTINGS}"
  fi
}

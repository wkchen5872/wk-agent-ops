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
# Supports two modes via $3:
#   "claude" (default) — registers Stop + Notification (Claude Code event names)
#   "gemini"           — registers AfterAgent + Notification (Gemini CLI event names)
# Arguments: $1 = settings file path, $2 = deployed hook path, $3 = mode (claude|gemini)
_register_hooks_in_file() {
  local settings_file="$1"
  local hook_path="$2"
  local mode="${3:-claude}"

  _ensure_settings_file "${settings_file}"

  local stop_cmd="bash \"${hook_path}\" stop"
  local notify_cmd="bash \"${hook_path}\" notification"

  # Claude Code uses "Stop"; Gemini CLI uses "AfterAgent"
  local stop_event="Stop"
  [[ "${mode}" == "gemini" ]] && stop_event="AfterAgent"

  local tmp
  tmp="$(mktemp)"

  # Build the correctly nested hook group objects.
  # Claude: async=true, timeout in seconds (15s)
  # Gemini: no async field (unsupported), timeout in milliseconds (15000ms)
  local stop_group notify_group
  if [[ "${mode}" == "gemini" ]]; then
    stop_group=$(jq -n --arg cmd "${stop_cmd}" \
      '{"hooks":[{"type":"command","command":$cmd,"timeout":15000}]}')
    notify_group=$(jq -n --arg cmd "${notify_cmd}" \
      '{"hooks":[{"type":"command","command":$cmd,"timeout":15000}]}')
  else
    stop_group=$(jq -n --arg cmd "${stop_cmd}" \
      '{"hooks":[{"type":"command","command":$cmd,"async":true,"timeout":15}]}')
    notify_group=$(jq -n --arg cmd "${notify_cmd}" \
      '{"hooks":[{"type":"command","command":$cmd,"async":true,"timeout":15}]}')
  fi

  # Idempotent merge: only add group if no existing group already contains this command.
  # Also handles migration from old flat format (direct {"type","command"} objects).
  if jq \
    --argjson stop_group "${stop_group}" \
    --argjson notify_group "${notify_group}" \
    --arg stop_cmd "${stop_cmd}" \
    --arg notify_cmd "${notify_cmd}" \
    --arg stop_event "${stop_event}" \
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

    .hooks[$stop_event] = (
      if has_command(.hooks[$stop_event]; $stop_cmd) then .hooks[$stop_event]
      else ((.hooks[$stop_event] // []) + [$stop_group])
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
# Clears entries from Stop, AfterAgent, and Notification (handles both formats).
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
    def remove_cmd(arr; cmd):
      if arr == null then []
      else arr | map(select(
        (.command? // "") != cmd and
        (.hooks? == null or (.hooks | map(select(.command == cmd)) | length) == 0)
      ))
      end;

    # Remove from Stop (Claude Code), AfterAgent (Gemini CLI), and Notification,
    # then delete keys that are empty to keep settings.json clean.
    .hooks.Stop         = remove_cmd(.hooks.Stop;         $stop_cmd)   |
    .hooks.AfterAgent   = remove_cmd(.hooks.AfterAgent;   $stop_cmd)   |
    .hooks.Notification = remove_cmd(.hooks.Notification; $notify_cmd) |
    if (.hooks.Stop         | length) == 0 then del(.hooks.Stop)         else . end |
    if (.hooks.AfterAgent   | length) == 0 then del(.hooks.AfterAgent)   else . end |
    if (.hooks.Notification | length) == 0 then del(.hooks.Notification) else . end
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

  _register_hooks_in_file "${CLAUDE_SETTINGS}" "${hook_path}" "claude"
  echo "  ✓ Registered hooks in ${CLAUDE_SETTINGS}"

  # Register in Gemini settings using AfterAgent (Gemini's equivalent of Stop)
  if [[ -d "${HOME}/.gemini" ]] || [[ -f "${GEMINI_SETTINGS}" ]]; then
    _register_hooks_in_file "${GEMINI_SETTINGS}" "${hook_path}" "gemini"
    echo "  ✓ Registered hooks in ${GEMINI_SETTINGS}"
  fi
}

# Public: register the telegram-notify hook in Copilot CLI (.github/hooks/hooks.json).
# Writes sessionEnd (task complete) and userPromptSubmitted (action required) entries.
# Usage: register_hook_copilot <deployed_hook_path>
register_hook_copilot() {
  local hook_path="$1"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "${PWD}")"
  local hooks_dir="${repo_root}/.github/hooks"
  local hooks_file="${hooks_dir}/hooks.json"

  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed. Please install jq and re-run." >&2
    return 1
  fi

  mkdir -p "${hooks_dir}"

  # Initialise file if missing or invalid
  if [[ ! -f "${hooks_file}" ]] || ! jq empty "${hooks_file}" 2>/dev/null; then
    echo '{"version":1,"hooks":{}}' > "${hooks_file}"
  fi

  local session_end_cmd="bash \"${hook_path}\" sessionEnd"
  local prompt_cmd="bash \"${hook_path}\" userPromptSubmitted"

  local tmp
  tmp="$(mktemp)"

  if jq \
    --arg session_end_cmd "${session_end_cmd}" \
    --arg prompt_cmd "${prompt_cmd}" \
    '
    def has_bash_cmd(arr; cmd):
      if arr == null then false
      else (arr | map(select(.type == "bash" and .command == cmd)) | length) > 0
      end;

    .hooks.sessionEnd = (
      if has_bash_cmd(.hooks.sessionEnd; $session_end_cmd) then .hooks.sessionEnd
      else ((.hooks.sessionEnd // []) + [{"type":"bash","command":$session_end_cmd}])
      end
    ) |
    .hooks.userPromptSubmitted = (
      if has_bash_cmd(.hooks.userPromptSubmitted; $prompt_cmd) then .hooks.userPromptSubmitted
      else ((.hooks.userPromptSubmitted // []) + [{"type":"bash","command":$prompt_cmd}])
      end
    )
    ' "${hooks_file}" > "${tmp}"; then
    mv "${tmp}" "${hooks_file}"
    echo "  ✓ Registered Copilot hooks in ${hooks_file}"
  else
    rm -f "${tmp}"
    echo "ERROR: Failed to write ${hooks_file}" >&2
    return 1
  fi
}

# Public: unregister the telegram-notify hook from Copilot CLI hooks.json.
# Usage: unregister_hook_copilot <deployed_hook_path>
unregister_hook_copilot() {
  local hook_path="$1"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "${PWD}")"
  local hooks_file="${repo_root}/.github/hooks/hooks.json"

  if [[ ! -f "${hooks_file}" ]]; then
    return
  fi

  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed. Please install jq and re-run." >&2
    return 1
  fi

  local session_end_cmd="bash \"${hook_path}\" sessionEnd"
  local prompt_cmd="bash \"${hook_path}\" userPromptSubmitted"

  local tmp
  tmp="$(mktemp)"

  if jq \
    --arg session_end_cmd "${session_end_cmd}" \
    --arg prompt_cmd "${prompt_cmd}" \
    '
    def remove_bash_cmd(arr; cmd):
      if arr == null then []
      else arr | map(select((.type == "bash" and .command == cmd) | not))
      end;

    .hooks.sessionEnd         = remove_bash_cmd(.hooks.sessionEnd;         $session_end_cmd) |
    .hooks.userPromptSubmitted = remove_bash_cmd(.hooks.userPromptSubmitted; $prompt_cmd) |
    if (.hooks.sessionEnd         | length) == 0 then del(.hooks.sessionEnd)         else . end |
    if (.hooks.userPromptSubmitted | length) == 0 then del(.hooks.userPromptSubmitted) else . end
    ' "${hooks_file}" > "${tmp}"; then
    mv "${tmp}" "${hooks_file}"
    echo "  ✓ Unregistered Copilot hooks from ${hooks_file}"
  else
    rm -f "${tmp}"
    return 1
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

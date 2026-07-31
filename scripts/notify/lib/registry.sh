#!/usr/bin/env bash
# Shared hook registry library for supported AI CLI configuration files.
# This file only defines functions — it does NOT write anything on source.
# Requires: jq

CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
GEMINI_SETTINGS="${HOME}/.gemini/settings.json"
CODEX_HOOKS="${HOME}/.codex/hooks.json"
ANTIGRAVITY_HOOKS="${HOME}/.gemini/config/hooks.json"
ANTIGRAVITY_SETTINGS="${HOME}/.gemini/antigravity-cli/settings.json"

# Write jq output back to a file atomically; cleans up on failure.
_jq_write() {
  local file="$1"; shift
  local tmp
  tmp="$(mktemp)"
  if jq "$@" "${file}" > "${tmp}"; then
    mv "${tmp}" "${file}"
  else
    rm -f "${tmp}"
    return 1
  fi
}

# Abort with an error if jq is not installed.
_require_jq() {
  command -v jq &>/dev/null && return 0
  echo "ERROR: jq is required but not installed. Please install jq and re-run." >&2
  return 1
}

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

# Create a missing JSON object but never replace an invalid existing file.
_ensure_json_object_file() {
  local file="$1"
  local dir
  dir="$(dirname "${file}")"
  mkdir -p "${dir}"
  if [[ ! -f "${file}" ]]; then
    echo '{}' > "${file}"
  elif ! jq -e 'type == "object"' "${file}" >/dev/null 2>&1; then
    echo "ERROR: ${file} must contain a valid JSON object; left unchanged." >&2
    return 1
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

  local stop_event="Stop"
  [[ "${mode}" == "gemini" ]] && stop_event="AfterAgent"

  # Commands include the tool name so hook.sh can identify the caller reliably.
  local stop_cmd notify_cmd base_stop_cmd base_notify_cmd
  if [[ "${mode}" == "gemini" ]]; then
    stop_cmd="bash \"${hook_path}\" AfterAgent \"Gemini CLI\""
    notify_cmd="bash \"${hook_path}\" notification \"Gemini CLI\""
    base_stop_cmd="bash \"${hook_path}\" AfterAgent"
  else
    stop_cmd="bash \"${hook_path}\" stop \"Claude Code\""
    notify_cmd="bash \"${hook_path}\" notification \"Claude Code\""
    base_stop_cmd="bash \"${hook_path}\" stop"
  fi
  base_notify_cmd="bash \"${hook_path}\" notification"

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
  # Checks both new format (with tool name) and old format (base cmd only) for migration.
  _jq_write "${settings_file}" \
    --argjson stop_group "${stop_group}" \
    --argjson notify_group "${notify_group}" \
    --arg stop_cmd "${stop_cmd}" \
    --arg notify_cmd "${notify_cmd}" \
    --arg base_stop_cmd "${base_stop_cmd}" \
    --arg base_notify_cmd "${base_notify_cmd}" \
    --arg stop_event "${stop_event}" \
    '
    # Returns true if the array already has an entry matching cmd or base_cmd
    # (base_cmd matches old format without tool name, preventing double-registration).
    def has_command(arr; cmd; base_cmd):
      if arr == null then false
      else (arr | map(
        select(
          (.command? == cmd) or (.command? == base_cmd) or
          (.hooks? != null and (.hooks | map(select(.command == cmd or .command == base_cmd)) | length) > 0)
        )
      ) | length) > 0
      end;

    .hooks[$stop_event] = (
      if has_command(.hooks[$stop_event]; $stop_cmd; $base_stop_cmd) then .hooks[$stop_event]
      else ((.hooks[$stop_event] // []) + [$stop_group])
      end
    ) |
    .hooks.Notification = (
      if has_command(.hooks.Notification; $notify_cmd; $base_notify_cmd) then .hooks.Notification
      else ((.hooks.Notification // []) + [$notify_group])
      end
    )
    '
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

  local base_stop_cmd="bash \"${hook_path}\" stop"
  local base_afteragent_cmd="bash \"${hook_path}\" AfterAgent"
  local base_notify_cmd="bash \"${hook_path}\" notification"

  _jq_write "${settings_file}" \
    --arg base_stop_cmd "${base_stop_cmd}" \
    --arg base_afteragent_cmd "${base_afteragent_cmd}" \
    --arg base_notify_cmd "${base_notify_cmd}" \
    '
    # Remove entries where the command starts with any of the given base_cmds —
    # matches both old format (no tool name) and new format (with tool name appended).
    def remove_cmd(arr; base_cmd):
      if arr == null then []
      else arr | map(select(
        ((.command? // "") | startswith(base_cmd) | not) and
        (.hooks? == null or (.hooks | map(select((.command // "") | startswith(base_cmd))) | length) == 0)
      ))
      end;

    # Remove entries matching either of two base commands (handles format migration).
    def remove_cmd2(arr; base_cmd1; base_cmd2):
      remove_cmd(remove_cmd(arr; base_cmd1); base_cmd2);

    # Remove from Stop (Claude Code), AfterAgent (Gemini CLI), and Notification.
    # AfterAgent uses remove_cmd2 because old Gemini entries used "stop" as the command.
    .hooks.Stop         = remove_cmd(.hooks.Stop;         $base_stop_cmd)                              |
    .hooks.AfterAgent   = remove_cmd2(.hooks.AfterAgent;  $base_afteragent_cmd; $base_stop_cmd)        |
    .hooks.Notification = remove_cmd(.hooks.Notification; $base_notify_cmd)                            |
    if (.hooks.Stop         | length) == 0 then del(.hooks.Stop)         else . end |
    if (.hooks.AfterAgent   | length) == 0 then del(.hooks.AfterAgent)   else . end |
    if (.hooks.Notification | length) == 0 then del(.hooks.Notification) else . end
    '
}

# Public: register Codex Stop and PermissionRequest hooks in ~/.codex/hooks.json.
register_hook_codex() {
  local hook_path="$1"
  _require_jq || return 1
  _ensure_json_object_file "${CODEX_HOOKS}" || return 1

  local stop_cmd="bash \"${hook_path}\" codex-stop \"Codex\""
  local permission_cmd="bash \"${hook_path}\" codex-permission \"Codex\""

  _jq_write "${CODEX_HOOKS}" \
    --arg stop_cmd "${stop_cmd}" \
    --arg permission_cmd "${permission_cmd}" \
    '
    def has_command(arr; cmd):
      any((arr // [])[]?;
        (.command? == cmd) or
        any((.hooks? // [])[]?; .command? == cmd)
      );

    .hooks = (.hooks // {}) |
    .hooks.Stop = (
      if has_command(.hooks.Stop; $stop_cmd) then .hooks.Stop
      else ((.hooks.Stop // []) + [{"hooks":[{"type":"command","command":$stop_cmd,"timeout":5}]}])
      end
    ) |
    .hooks.PermissionRequest = (
      if has_command(.hooks.PermissionRequest; $permission_cmd) then .hooks.PermissionRequest
      else ((.hooks.PermissionRequest // []) + [{"hooks":[{"type":"command","command":$permission_cmd,"timeout":5}]}])
      end
    )
    '
  echo "  ✓ Registered Codex hooks in ${CODEX_HOOKS}"
}

# Public: remove only notification-owned Codex handlers.
unregister_hook_codex() {
  local hook_path="$1"
  [[ -f "${CODEX_HOOKS}" ]] || return 0
  _require_jq || return 1

  local stop_prefix="bash \"${hook_path}\" codex-stop"
  local permission_prefix="bash \"${hook_path}\" codex-permission"

  _jq_write "${CODEX_HOOKS}" \
    --arg stop_prefix "${stop_prefix}" \
    --arg permission_prefix "${permission_prefix}" \
    '
    def remove_owned(arr; prefix):
      (arr // [])
      | map(
          if .hooks? != null then
            .hooks |= map(select(((.command? // "") | startswith(prefix)) | not))
          else .
          end
        )
      | map(select(
          (((.command? // "") | startswith(prefix)) | not) and
          (.hooks? == null or (.hooks | length) > 0)
        ));

    .hooks.Stop = remove_owned(.hooks.Stop; $stop_prefix) |
    .hooks.PermissionRequest = remove_owned(.hooks.PermissionRequest; $permission_prefix) |
    if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end |
    if (.hooks.PermissionRequest | length) == 0 then del(.hooks.PermissionRequest) else . end
    '
  echo "  ✓ Unregistered Codex hooks from ${CODEX_HOOKS}"
}

# Public: register Antigravity's named global Stop hook.
register_hook_antigravity() {
  local hook_path="$1"
  _require_jq || return 1
  _ensure_json_object_file "${ANTIGRAVITY_HOOKS}" || return 1

  local stop_cmd="bash \"${hook_path}\" antigravity-stop \"Antigravity CLI\""
  local stop_prefix="bash \"${hook_path}\" antigravity-stop"

  _jq_write "${ANTIGRAVITY_HOOKS}" \
    --arg stop_cmd "${stop_cmd}" \
    --arg stop_prefix "${stop_prefix}" \
    '
    .["telegram-notify"] = (.["telegram-notify"] // {}) |
    .["telegram-notify"].Stop = (
      if any((.["telegram-notify"].Stop // [])[]?;
             (.command? // "") | startswith($stop_prefix))
      then .["telegram-notify"].Stop
      else ((.["telegram-notify"].Stop // []) + [{"type":"command","command":$stop_cmd,"timeout":5}])
      end
    )
    '
  echo "  ✓ Registered Antigravity hooks in ${ANTIGRAVITY_HOOKS}"
}

# Public: remove only the owned Antigravity Stop handler and empty definition.
unregister_hook_antigravity() {
  local hook_path="$1"
  [[ -f "${ANTIGRAVITY_HOOKS}" ]] || return 0
  _require_jq || return 1

  local stop_prefix="bash \"${hook_path}\" antigravity-stop"
  _jq_write "${ANTIGRAVITY_HOOKS}" \
    --arg stop_prefix "${stop_prefix}" \
    '
    if .["telegram-notify"]? == null then .
    else
      .["telegram-notify"].Stop = (
        (.["telegram-notify"].Stop // [])
        | map(select(((.command? // "") | startswith($stop_prefix)) | not))
      ) |
      if (.["telegram-notify"].Stop | length) == 0
      then del(.["telegram-notify"].Stop)
      else .
      end |
      if (.["telegram-notify"] | length) == 0
      then del(.["telegram-notify"])
      else .
      end
    end
    '
  echo "  ✓ Unregistered Antigravity hooks from ${ANTIGRAVITY_HOOKS}"
}

# Public: opt in to Antigravity approval observation through statusLine.
register_hook_antigravity_statusline() {
  local hook_path="$1"
  _require_jq || return 1
  _ensure_json_object_file "${ANTIGRAVITY_SETTINGS}" || return 1

  local status_cmd="bash \"${hook_path}\" antigravity-statusline \"Antigravity CLI\""
  local existing_cmd
  existing_cmd="$(jq -r '.statusLine.command // empty' "${ANTIGRAVITY_SETTINGS}")"
  if [[ -n "${existing_cmd}" && "${existing_cmd}" != "${status_cmd}" ]]; then
    echo "ERROR: existing statusLine.command is preserved: ${existing_cmd}" >&2
    return 1
  fi

  if [[ "${existing_cmd}" != "${status_cmd}" ]]; then
    _jq_write "${ANTIGRAVITY_SETTINGS}" \
      --arg status_cmd "${status_cmd}" \
      '.statusLine = ((.statusLine // {}) + {"type":"command","command":$status_cmd})'
  fi
  echo "  ✓ Registered Antigravity approval observer in ${ANTIGRAVITY_SETTINGS}"
}

# Public: remove the Antigravity status line only when it is notification-owned.
unregister_hook_antigravity_statusline() {
  local hook_path="$1"
  [[ -f "${ANTIGRAVITY_SETTINGS}" ]] || return 0
  _require_jq || return 1

  local status_cmd="bash \"${hook_path}\" antigravity-statusline \"Antigravity CLI\""
  _jq_write "${ANTIGRAVITY_SETTINGS}" \
    --arg status_cmd "${status_cmd}" \
    '
    if .statusLine.command? == $status_cmd then
      del(.statusLine.command, .statusLine.type) |
      if (.statusLine | length) == 0 then del(.statusLine) else . end
    else .
    end
    '
  echo "  ✓ Unregistered Antigravity approval observer from ${ANTIGRAVITY_SETTINGS}"
}

# Public: remove only Antigravity approval marker files owned by this hook.
clear_antigravity_notify_state() {
  local state_dir="${HOME}/.config/ai-notify/state"
  local state_file
  [[ -d "${state_dir}" ]] || return 0
  for state_file in "${state_dir}"/antigravity-*.pending; do
    [[ -f "${state_file}" ]] || continue
    rm -f -- "${state_file}"
  done
}

# Return success when a JSON file contains an owned command prefix.
_has_command_prefix() {
  local file="$1"
  local prefix="$2"
  [[ -f "${file}" ]] || return 1
  jq -e --arg prefix "${prefix}" \
    '[.. | objects | (.command? // .bash? // empty) | select(startswith($prefix))] | length > 0' \
    "${file}" >/dev/null 2>&1
}

# Public: print credential-free registration coverage for the deployed hook.
show_hook_status() {
  local hook_path="$1"
  _require_jq || return 1

  local codex_stop="bash \"${hook_path}\" codex-stop"
  local codex_permission="bash \"${hook_path}\" codex-permission"
  local agy_stop="bash \"${hook_path}\" antigravity-stop"
  local agy_status="bash \"${hook_path}\" antigravity-statusline \"Antigravity CLI\""
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "${PWD}")"

  _has_command_prefix "${CLAUDE_SETTINGS}" "bash \"${hook_path}\" stop" &&
    echo "Claude Code: registered" || echo "Claude Code: not registered"
  _has_command_prefix "${GEMINI_SETTINGS}" "bash \"${hook_path}\" AfterAgent" &&
    echo "Gemini CLI: registered" || echo "Gemini CLI: not registered"

  if _has_command_prefix "${CODEX_HOOKS}" "${codex_stop}" &&
     _has_command_prefix "${CODEX_HOOKS}" "${codex_permission}"; then
    echo "Codex: registered"
  elif _has_command_prefix "${CODEX_HOOKS}" "${codex_stop}" ||
       _has_command_prefix "${CODEX_HOOKS}" "${codex_permission}"; then
    echo "Codex: partial"
  else
    echo "Codex: not registered"
  fi

  _has_command_prefix "${ANTIGRAVITY_HOOKS}" "${agy_stop}" &&
    echo "Antigravity completion: registered" || echo "Antigravity completion: not registered"

  if [[ -f "${ANTIGRAVITY_SETTINGS}" ]] &&
     [[ "$(jq -r '.statusLine.command // empty' "${ANTIGRAVITY_SETTINGS}" 2>/dev/null)" == "${agy_status}" ]]; then
    echo "Antigravity approval: registered"
  else
    echo "Antigravity approval: not registered"
  fi

  if _has_command_prefix "${repo_root}/.github/hooks/hooks.json" "bash \"${hook_path}\" sessionEnd" &&
     _has_command_prefix "${repo_root}/.github/hooks/hooks.json" "bash \"${hook_path}\" userPromptSubmitted"; then
    echo "Copilot CLI: registered"
  else
    echo "Copilot CLI: not registered"
  fi
}

# Public: register the telegram-notify hook in all supported AI CLI settings files.
# Usage: register_hook <deployed_hook_path>
register_hook() {
  local hook_path="$1"
  _require_jq || return 1

  _register_hooks_in_file "${CLAUDE_SETTINGS}" "${hook_path}" "claude"
  echo "  ✓ Registered hooks in ${CLAUDE_SETTINGS}"

  # Register in Gemini settings using AfterAgent (Gemini's equivalent of Stop)
  if [[ -f "${GEMINI_SETTINGS}" ]] || command -v gemini &>/dev/null; then
    _register_hooks_in_file "${GEMINI_SETTINGS}" "${hook_path}" "gemini"
    echo "  ✓ Registered hooks in ${GEMINI_SETTINGS}"
  fi

  if [[ -d "${HOME}/.codex" ]] || command -v codex &>/dev/null; then
    register_hook_codex "${hook_path}"
  fi

  if [[ -d "${HOME}/.gemini/antigravity-cli" ]] || command -v agy &>/dev/null; then
    register_hook_antigravity "${hook_path}"
  fi
}

# Public: register the telegram-notify hook in Copilot CLI (.github/hooks/hooks.json).
# Writes sessionEnd (task complete) and userPromptSubmitted (action required).
# Usage: register_hook_copilot <deployed_hook_path>
register_hook_copilot() {
  local hook_path="$1"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "${PWD}")"
  local hooks_dir="${repo_root}/.github/hooks"
  local hooks_file="${hooks_dir}/hooks.json"

  _require_jq || return 1

  mkdir -p "${hooks_dir}"

  # Initialise file if missing or invalid
  if [[ ! -f "${hooks_file}" ]] || ! jq empty "${hooks_file}" 2>/dev/null; then
    echo '{"version":1,"hooks":{}}' > "${hooks_file}"
  fi

  local session_end_cmd="bash \"${hook_path}\" sessionEnd \"Copilot CLI\""
  local user_prompt_cmd="bash \"${hook_path}\" userPromptSubmitted \"Copilot CLI\""
  local base_session_end_cmd="bash \"${hook_path}\" sessionEnd"
  local base_user_prompt_cmd="bash \"${hook_path}\" userPromptSubmitted"

  if _jq_write "${hooks_file}" \
    --arg session_end_cmd "${session_end_cmd}" \
    --arg user_prompt_cmd "${user_prompt_cmd}" \
    --arg base_session_end_cmd "${base_session_end_cmd}" \
    --arg base_user_prompt_cmd "${base_user_prompt_cmd}" \
    '
    # Match any entry whose bash command starts with base_cmd (handles old and new format).
    def has_bash_cmd(arr; base_cmd):
      if arr == null then false
      else (arr | map(select(.type == "command" and ((.bash // "") | startswith(base_cmd)))) | length) > 0
      end;

    .hooks.sessionEnd = (
      if has_bash_cmd(.hooks.sessionEnd; $base_session_end_cmd) then .hooks.sessionEnd
      else ((.hooks.sessionEnd // []) + [{"type":"command","bash":$session_end_cmd}])
      end
    ) |
    .hooks.userPromptSubmitted = (
      if has_bash_cmd(.hooks.userPromptSubmitted; $base_user_prompt_cmd) then .hooks.userPromptSubmitted
      else ((.hooks.userPromptSubmitted // []) + [{"type":"command","bash":$user_prompt_cmd}])
      end
    )
    '; then
    echo "  ✓ Registered Copilot hooks in ${hooks_file}"
  else
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

  _require_jq || return 1

  # Base command prefix matches both old (without tool name) and new (with tool name) format.
  local base_session_end_cmd="bash \"${hook_path}\" sessionEnd"
  local base_user_prompt_cmd="bash \"${hook_path}\" userPromptSubmitted"

  if _jq_write "${hooks_file}" \
    --arg base_session_end_cmd "${base_session_end_cmd}" \
    --arg base_user_prompt_cmd "${base_user_prompt_cmd}" \
    '
    def remove_bash_cmd(arr; base_cmd):
      if arr == null then []
      else arr | map(select(
        (.type != "command") or (((.bash // "") | startswith(base_cmd)) | not)
      ))
      end;

    .hooks.sessionEnd = remove_bash_cmd(.hooks.sessionEnd; $base_session_end_cmd) |
    .hooks.userPromptSubmitted = remove_bash_cmd(.hooks.userPromptSubmitted; $base_user_prompt_cmd) |
    if (.hooks.sessionEnd | length) == 0 then del(.hooks.sessionEnd) else . end |
    if (.hooks.userPromptSubmitted | length) == 0 then del(.hooks.userPromptSubmitted) else . end
    '; then
    echo "  ✓ Unregistered Copilot hooks from ${hooks_file}"
  fi
}

# Public: unregister the telegram-notify hook from all supported AI CLI settings files.
# Usage: unregister_hook <deployed_hook_path>
unregister_hook() {
  local hook_path="$1"
  _require_jq || return 1

  _unregister_hooks_in_file "${CLAUDE_SETTINGS}" "${hook_path}"
  echo "  ✓ Unregistered hooks from ${CLAUDE_SETTINGS}"

  if [[ -f "${GEMINI_SETTINGS}" ]]; then
    _unregister_hooks_in_file "${GEMINI_SETTINGS}" "${hook_path}"
    echo "  ✓ Unregistered hooks from ${GEMINI_SETTINGS}"
  fi

  unregister_hook_codex "${hook_path}"
  unregister_hook_antigravity "${hook_path}"
  unregister_hook_antigravity_statusline "${hook_path}"
}

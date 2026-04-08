#!/usr/bin/env bash
# lib.sh — Shared helpers for hook install/uninstall scripts.
# Source this file; do not execute it directly.

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

# Register a hook entry in a JSON settings file (Claude or Gemini format).
# Creates the file with '{}' if it does not exist or is invalid JSON.
# Usage: _register_settings_hook <file> <event_name> <matcher> <hook_cmd>
_register_settings_hook() {
  local settings_file="$1"
  local event_name="$2"
  local matcher="$3"
  local hook_cmd="$4"

  mkdir -p "$(dirname "$settings_file")"
  if [[ ! -f "$settings_file" ]] || ! jq empty "$settings_file" 2>/dev/null; then
    echo '{}' > "$settings_file"
  fi

  if _jq_write "$settings_file" \
    --arg event "$event_name" \
    --arg matcher "$matcher" \
    --arg hook_cmd "$hook_cmd" \
    '
    def already_registered:
      (.hooks[$event] // [])
      | map(.hooks // [] | map(select(.type == "command" and .command == $hook_cmd)) | length)
      | add // 0
      | . > 0;

    if already_registered then .
    else
      .hooks[$event] = ((.hooks[$event] // []) + [
        {
          "matcher": $matcher,
          "hooks": [
            {
              "type": "command",
              "command": $hook_cmd,
              "timeout": 10
            }
          ]
        }
      ])
    end
    '; then
    echo "  ✓ Registered $event_name hook in $settings_file"
  fi
}

# Remove a hook entry from a JSON settings file.
# Usage: _remove_settings_hook <file> <event_name> <hook_cmd>
_remove_settings_hook() {
  local settings_file="$1"
  local event_name="$2"
  local hook_cmd="$3"

  if _jq_write "$settings_file" \
    --arg event "$event_name" \
    --arg hook_cmd "$hook_cmd" \
    '
    .hooks[$event] = (
      (.hooks[$event] // [])
      | map(select(
          (.hooks // [])
          | map(select(.type == "command" and .command == $hook_cmd))
          | length == 0
        ))
    )
    | if (.hooks[$event] | length) == 0 then delpaths([["hooks", $event]]) else . end
    '; then
    echo "  ✓ Removed $event_name hook entry from $settings_file"
  fi
}

# Write a GitHub Copilot CLI hook JSON file.
# Usage: _write_copilot_hook <hooks_file> <hook_dst>
_write_copilot_hook() {
  local hooks_file="$1"
  local hook_dst="$2"
  mkdir -p "$(dirname "$hooks_file")"
  cat > "$hooks_file" <<EOF
{
  "version": 1,
  "hooks": {
    "postToolUse": [
      {
        "type": "command",
        "bash": "$hook_dst",
        "timeoutSec": 10
      }
    ]
  }
}
EOF
  echo "  ✓ Registered postToolUse hook in $hooks_file"
}

#!/usr/bin/env bash
# uninstall.sh — Remove entropy-counter hook from all supported AI CLI tools
#                and delete the deployed script.
#                Idempotent: safe to run multiple times.
#
# Usage:
#   bash scripts/workflow/entropy-counter/uninstall.sh

set -euo pipefail

HOOK_DST="$HOME/.config/wk-workflow/hooks/entropy-counter.sh"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
GEMINI_SETTINGS="$HOME/.gemini/settings.json"
COPILOT_HOOKS_DIR=".github/hooks"
COPILOT_HOOKS_FILE="$COPILOT_HOOKS_DIR/entropy-counter.json"

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

_remove_claude_hook() {
  local settings_file="$1"
  HOOK_CMD="bash \"$HOOK_DST\""
  if _jq_write "$settings_file" \
    --arg hook_cmd "$HOOK_CMD" \
    '
    .hooks.PostToolUse = (
      (.hooks.PostToolUse // [])
      | map(select(
          (.hooks // [])
          | map(select(.type == "command" and .command == $hook_cmd))
          | length == 0
        ))
    )
    | if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end
    '; then
    echo "  ✓ Removed PostToolUse hook entry from $settings_file"
  fi
}

_remove_gemini_hook() {
  local settings_file="$1"
  HOOK_CMD="bash \"$HOOK_DST\""
  if _jq_write "$settings_file" \
    --arg hook_cmd "$HOOK_CMD" \
    '
    .hooks.AfterTool = (
      (.hooks.AfterTool // [])
      | map(select(
          (.hooks // [])
          | map(select(.type == "command" and .command == $hook_cmd))
          | length == 0
        ))
    )
    | if (.hooks.AfterTool | length) == 0 then del(.hooks.AfterTool) else . end
    '; then
    echo "  ✓ Removed AfterTool hook entry from $settings_file"
  fi
}

# 1. Remove hook entry from ~/.claude/settings.json.
if [[ -f "$CLAUDE_SETTINGS" ]] && jq empty "$CLAUDE_SETTINGS" 2>/dev/null; then
  _remove_claude_hook "$CLAUDE_SETTINGS"
fi

# 2. Remove hook entry from ~/.gemini/settings.json if present.
if [[ -f "$GEMINI_SETTINGS" ]] && jq empty "$GEMINI_SETTINGS" 2>/dev/null; then
  _remove_gemini_hook "$GEMINI_SETTINGS"
fi

# 3. Remove GitHub Copilot CLI hook file.
if [[ -f "$COPILOT_HOOKS_FILE" ]]; then
  rm -f "$COPILOT_HOOKS_FILE"
  echo "  ✓ Deleted $COPILOT_HOOKS_FILE"
fi

# 4. Delete the deployed hook script.
if [[ -f "$HOOK_DST" ]]; then
  rm -f "$HOOK_DST"
  echo "  ✓ Deleted $HOOK_DST"
fi

echo "✅ entropy-counter uninstalled"

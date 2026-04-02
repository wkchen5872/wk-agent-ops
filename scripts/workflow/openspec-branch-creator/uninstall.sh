#!/usr/bin/env bash
# uninstall.sh — Remove openspec-branch-creator hook from
#                ~/.claude/settings.json and delete the deployed script.
#
# Usage:
#   bash scripts/workflow/openspec-branch-creator/uninstall.sh

set -euo pipefail

HOOK_DST="$HOME/.config/wk-workflow/hooks/openspec-branch-creator.sh"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

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

# 1. Remove hook entry from ~/.claude/settings.json.
if [[ -f "$CLAUDE_SETTINGS" ]] && jq empty "$CLAUDE_SETTINGS" 2>/dev/null; then
  HOOK_CMD="bash \"$HOOK_DST\""
  _jq_write "$CLAUDE_SETTINGS" \
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
    '
  echo "  ✓ Removed PostToolUse hook entry from $CLAUDE_SETTINGS"
fi

# 2. Delete the deployed hook script.
if [[ -f "$HOOK_DST" ]]; then
  rm -f "$HOOK_DST"
  echo "  ✓ Deleted $HOOK_DST"
fi

echo "✅ openspec-branch-creator uninstalled"

#!/usr/bin/env bash
# install.sh — Deploy openspec-branch-creator hook and register PostToolUse
#              entry in ~/.claude/settings.json (idempotent).
#
# Usage:
#   bash scripts/workflow/openspec-branch-creator/install.sh

set -euo pipefail

REPO=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -z "$REPO" ]]; then
  echo "❌ Error: run this script from inside the repository"
  exit 1
fi

# 1. Deploy hook script to user config dir.
HOOK_DIR="$HOME/.config/wk-workflow/hooks"
mkdir -p "$HOOK_DIR"

HOOK_SRC="$REPO/scripts/workflow/openspec-branch-creator/hook.sh"
HOOK_DST="$HOOK_DIR/openspec-branch-creator.sh"

cp -f "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"
echo "  ✓ Deployed hook to $HOOK_DST"

# 2. Register PostToolUse entry in ~/.claude/settings.json (idempotent).
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

if [[ ! -f "$CLAUDE_SETTINGS" ]] || ! jq empty "$CLAUDE_SETTINGS" 2>/dev/null; then
  echo '{}' > "$CLAUDE_SETTINGS"
fi

HOOK_CMD="bash \"$HOOK_DST\""

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

if _jq_write "$CLAUDE_SETTINGS" \
  --arg hook_cmd "$HOOK_CMD" \
  '
  # True when $hook_cmd already exists in any PostToolUse hook entry.
  def already_registered:
    (.hooks.PostToolUse // [])
    | map(.hooks // [] | map(select(.type == "command" and .command == $hook_cmd)) | length)
    | add // 0
    | . > 0;

  if already_registered then .
  else
    .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [
      {
        "matcher": "Bash",
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
  echo "  ✓ Registered PostToolUse hook in $CLAUDE_SETTINGS"
fi

echo "✅ openspec-branch-creator installed"

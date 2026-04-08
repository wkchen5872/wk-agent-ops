#!/usr/bin/env bash
# install.sh — Deploy entropy-counter hook and register PostToolUse entry
#              in ~/.claude/settings.json (and ~/.gemini/settings.json if present).
#              Idempotent: safe to run multiple times.
#
# Usage:
#   bash scripts/workflow/entropy-counter/install.sh

set -euo pipefail

REPO=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -z "$REPO" ]]; then
  echo "❌ Error: run this script from inside the repository"
  exit 1
fi

# 1. Deploy hook script to user config dir.
HOOK_DIR="$HOME/.config/wk-workflow/hooks"
mkdir -p "$HOOK_DIR"

HOOK_SRC="$REPO/scripts/workflow/entropy-counter/hook.sh"
HOOK_DST="$HOOK_DIR/entropy-counter.sh"

cp -f "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"
echo "  ✓ Deployed hook to $HOOK_DST"

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

_register_claude_hook() {
  local settings_file="$1"
  mkdir -p "$(dirname "$settings_file")"

  if [[ ! -f "$settings_file" ]] || ! jq empty "$settings_file" 2>/dev/null; then
    echo '{}' > "$settings_file"
  fi

  if _jq_write "$settings_file" \
    --arg hook_cmd "$HOOK_CMD" \
    '
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
    echo "  ✓ Registered PostToolUse hook in $settings_file"
  fi
}

_register_gemini_hook() {
  local settings_file="$1"
  mkdir -p "$(dirname "$settings_file")"

  if [[ ! -f "$settings_file" ]] || ! jq empty "$settings_file" 2>/dev/null; then
    echo '{}' > "$settings_file"
  fi

  if _jq_write "$settings_file" \
    --arg hook_cmd "$HOOK_CMD" \
    '
    def already_registered:
      (.hooks.AfterTool // [])
      | map(.hooks // [] | map(select(.type == "command" and .command == $hook_cmd)) | length)
      | add // 0
      | . > 0;

    if already_registered then .
    else
      .hooks.AfterTool = ((.hooks.AfterTool // []) + [
        {
          "matcher": "bash",
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
    echo "  ✓ Registered AfterTool hook in $settings_file"
  fi
}

_register_copilot_hook() {
  local hooks_dir="$1"
  local hooks_file="$hooks_dir/entropy-counter.json"
  mkdir -p "$hooks_dir"

  cat > "$hooks_file" <<EOF
{
  "version": 1,
  "hooks": {
    "postToolUse": [
      {
        "type": "command",
        "bash": "$HOOK_DST",
        "timeoutSec": 10
      }
    ]
  }
}
EOF
  echo "  ✓ Registered postToolUse hook in $hooks_file"
}

# 2. Register in Claude Code settings.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
_register_claude_hook "$CLAUDE_SETTINGS"

# 3. Register in Gemini CLI settings if present.
GEMINI_SETTINGS="$HOME/.gemini/settings.json"
if [[ -f "$GEMINI_SETTINGS" ]]; then
  _register_gemini_hook "$GEMINI_SETTINGS"
fi

# 4. Register in GitHub Copilot CLI settings (create hooks directory).
COPILOT_HOOKS_DIR=".github/hooks"
_register_copilot_hook "$COPILOT_HOOKS_DIR"

echo "✅ entropy-counter installed"

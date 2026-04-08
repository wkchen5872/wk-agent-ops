#!/usr/bin/env bash
# install.sh — Deploy entropy-counter hook and register in all supported
#              AI CLI tools: Claude Code (PostToolUse), Gemini CLI (AfterTool),
#              GitHub Copilot CLI (.github/hooks/). Idempotent.
#
# Usage:
#   bash scripts/workflow/entropy-counter/install.sh

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

REPO=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$REPO" ]]; then
  echo "❌ Error: run this script from inside the repository"
  exit 1
fi

HOOK_DIR="$HOME/.config/wk-workflow/hooks"
mkdir -p "$HOOK_DIR"

HOOK_SRC="$REPO/scripts/workflow/entropy-counter/hook.sh"
HOOK_DST="$HOOK_DIR/entropy-counter.sh"

cp -f "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"
echo "  ✓ Deployed hook to $HOOK_DST"

HOOK_CMD="bash \"$HOOK_DST\""

# Claude Code: create settings if missing, then register.
_register_settings_hook "$HOME/.claude/settings.json" "PostToolUse" "Bash" "$HOOK_CMD"

# Gemini CLI: only register if already installed.
GEMINI_SETTINGS="$HOME/.gemini/settings.json"
if [[ -f "$GEMINI_SETTINGS" ]] && jq empty "$GEMINI_SETTINGS" 2>/dev/null; then
  _register_settings_hook "$GEMINI_SETTINGS" "AfterTool" "bash" "$HOOK_CMD"
fi

# GitHub Copilot CLI.
_write_copilot_hook ".github/hooks/entropy-counter.json" "$HOOK_DST"

echo "✅ entropy-counter installed"

#!/usr/bin/env bash
# uninstall.sh — Remove entropy-counter hook from all supported AI CLI tools
#                and delete the deployed script. Idempotent.
#
# Usage:
#   bash scripts/workflow/entropy-counter/uninstall.sh

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

HOOK_DST="$HOME/.config/wk-workflow/hooks/entropy-counter.sh"
HOOK_CMD="bash \"$HOOK_DST\""
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
GEMINI_SETTINGS="$HOME/.gemini/settings.json"
COPILOT_HOOKS_FILE=".github/hooks/entropy-counter.json"

if [[ -f "$CLAUDE_SETTINGS" ]] && jq empty "$CLAUDE_SETTINGS" 2>/dev/null; then
  _remove_settings_hook "$CLAUDE_SETTINGS" "PostToolUse" "$HOOK_CMD"
fi

if [[ -f "$GEMINI_SETTINGS" ]] && jq empty "$GEMINI_SETTINGS" 2>/dev/null; then
  _remove_settings_hook "$GEMINI_SETTINGS" "AfterTool" "$HOOK_CMD"
fi

if [[ -f "$COPILOT_HOOKS_FILE" ]]; then
  rm -f "$COPILOT_HOOKS_FILE"
  echo "  ✓ Deleted $COPILOT_HOOKS_FILE"
fi

if [[ -f "$HOOK_DST" ]]; then
  rm -f "$HOOK_DST"
  echo "  ✓ Deleted $HOOK_DST"
fi

echo "✅ entropy-counter uninstalled"

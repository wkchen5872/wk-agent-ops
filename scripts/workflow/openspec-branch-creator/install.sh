#!/usr/bin/env bash
# install.sh — Deploy the compatibility hook for Claude Code and Copilot CLI.
#
# Usage:
#   bash scripts/workflow/openspec-branch-creator/install.sh

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

HOOK_SRC="$REPO/scripts/workflow/openspec-branch-creator/hook.sh"
HOOK_DST="$HOOK_DIR/openspec-branch-creator.sh"

cp -f "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"
echo "  ✓ Deployed hook to $HOOK_DST"

HOOK_CMD="bash \"$HOOK_DST\""

# Claude Code: create settings if missing, then register.
_register_settings_hook "$HOME/.claude/settings.json" "PostToolUse" "Bash" "$HOOK_CMD"

# GitHub Copilot CLI.
_write_copilot_hook ".github/hooks/openspec-branch-creator.json" "$HOOK_DST"

echo "✅ openspec-branch-creator installed"

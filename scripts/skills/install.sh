#!/usr/bin/env bash
# install.sh — Copy custom skills/rules/workflows into a target project
#
# Usage (from inside the target project):
#   bash /path/to/wk-agent-ops/scripts/skills/install.sh
#
# Or with explicit target:
#   bash /path/to/wk-agent-ops/scripts/skills/install.sh /path/to/target-project
#
# Source of truth: wk-agent-ops/template/
#   .claude/rules/          — always-on rules for Claude Code
#   .claude/skills/         — Skill tool invocation
#   .claude/commands/opsx/  — /opsx:* slash commands
#   .agent/workflows/       — agent workflow definitions
#   .github/instructions/   — GitHub Copilot instructions

set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$SOURCE_REPO/template"
TARGET="${1:-$(pwd)}"
TARGET="$(cd "$TARGET" && pwd)"

if [[ ! -d "$TARGET/.git" ]]; then
  echo "❌ Error: $TARGET is not a git repository root"
  exit 1
fi

echo "🔧 Installing custom agent extensions"
echo "   source : $TEMPLATE"
echo "   target : $TARGET"
echo ""

rsync -av --itemize-changes "$TEMPLATE/" "$TARGET/"

echo ""
echo "✅ Done."

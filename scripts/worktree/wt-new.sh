#!/usr/bin/env bash
# wt-new — Create a Git worktree and start development
#
# Usage:
#   wt-new <feature-name> [--agent claude|copilot|codex]
#
# Example:
#   wt-new etf-nav-fetcher
#   wt-new etf-nav-fetcher --agent copilot
#   wt-new etf-nav-fetcher -a codex
#
# Description:
#   Creates a feature/<name> branch and worktree from develop,
#   inheriting openspec/changes/ planning files committed to develop.
#
# Prerequisites:
#   - Must be run inside a git repo
#   - develop branch must exist
#   - openspec planning (opsx:new + opsx:continue x4) must be committed to develop

set -euo pipefail

NAME=""
AGENT="claude"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent|-a)
      AGENT="${2:-}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: wt-new <feature-name> [--agent claude|copilot|codex]"
      exit 1
      ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$1"
      else
        echo "Unexpected argument: $1"
        echo "Usage: wt-new <feature-name> [--agent claude|copilot|codex]"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: wt-new <feature-name> [--agent claude|copilot|codex]"
  echo "Example: wt-new etf-nav-fetcher"
  exit 1
fi

if [[ "$AGENT" != "claude" && "$AGENT" != "copilot" && "$AGENT" != "codex" ]]; then
  echo "Error: --agent must be one of: claude, copilot, codex (got: $AGENT)"
  exit 1
fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null)

if [[ -z "$REPO" ]]; then
  echo "Error: not inside a git repo"
  exit 1
fi

WORKTREE_DIR="$REPO/.worktrees/$NAME"
BRANCH="feature/$NAME"

if [[ -d "$WORKTREE_DIR" ]]; then
  echo "⚠️  Worktree already exists, launching Claude directly..."
else
  if git -C "$REPO" show-ref --quiet "refs/heads/$BRANCH"; then
    echo "Error: branch already exists but directory is missing: $BRANCH"
    echo "Check worktree status: git worktree list"
    exit 1
  fi

  echo "Switching to develop..."
  git -C "$REPO" checkout develop

  echo "Creating worktree: $WORKTREE_DIR (branch: $BRANCH)"
  git -C "$REPO" worktree add "$WORKTREE_DIR" -b "$BRANCH"
  echo "✅ Worktree created"

  # 複製 .claude/settings.local.json 到 worktree
  LOCAL_SETTINGS="$REPO/.claude/settings.local.json"
  if [[ -f "$LOCAL_SETTINGS" ]]; then
    mkdir -p "$WORKTREE_DIR/.claude"
    cp "$LOCAL_SETTINGS" "$WORKTREE_DIR/.claude/settings.local.json"
    echo "✅ Copied .claude/settings.local.json to worktree"
  fi
fi

# iTerm2 Badge（執行期間持續可見，Claude 無法覆蓋）
if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
  printf "\033]1337;SetBadgeFormat=%s\a" "$(echo -n "RD: $NAME" | base64)"
fi

# Startup banner (identifiable in scrollback)
echo ""
echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
echo -e "\033[1;32m  🚀 RD Agent: feature/${NAME}\033[0m"
echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
echo -e "\033[1;33m  Session : RD: ${NAME}\033[0m"
echo -e "\033[1;36m  Dir     : ${WORKTREE_DIR}\033[0m"
echo -e "\033[1;36m  Branch  : feature/${NAME}\033[0m"
echo -e "\033[1;35m  Agent   : ${AGENT}\033[0m"
echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
echo ""

cd "$WORKTREE_DIR"

# title 會被 agent CLI 覆蓋，title 是 conversation 的名稱
case "$AGENT" in
  claude)
    claude --name "RD: $NAME" "/opsx:apply $NAME" --enable-auto-mode
    ;;
  copilot)
    copilot --allow-all -i "/openspec-apply-change $NAME"
    ;;
  codex)
    codex "/opsx:apply $NAME"
    ;;
esac

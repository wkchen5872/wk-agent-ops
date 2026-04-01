#!/usr/bin/env bash
# wt-new — Create a Git worktree and start development (auto-detects resume)
#
# Usage:
#   wt-new <feature-name> [--base <branch>] [--agent claude|copilot|codex]
#
# Example:
#   wt-new feature123
#   wt-new feature123 --base develop
#   wt-new feature123 --agent copilot
#   wt-new feature123 -a codex
#
# Description:
#   If the worktree already exists → resumes the existing agent session.
#   Otherwise → creates a feature/<name> branch and worktree from BASE_BRANCH,
#   inheriting openspec/changes/ planning files committed to that branch.
#
# Prerequisites:
#   - Must be run inside a git repo
#   - BASE_BRANCH (default: main) must exist
#   - openspec planning (opsx:new + opsx:continue x4) must be committed to BASE_BRANCH

set -euo pipefail

NAME=""
AGENT="claude"
BASE_BRANCH="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent|-a)
      AGENT="${2:-}"
      shift 2
      ;;
    --base|-b)
      BASE_BRANCH="${2:-}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: wt-new <feature-name> [--base <branch>] [--agent claude|copilot|codex]"
      exit 1
      ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$1"
      else
        echo "Unexpected argument: $1"
        echo "Usage: wt-new <feature-name> [--base <branch>] [--agent claude|copilot|codex]"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: wt-new <feature-name> [--base <branch>] [--agent claude|copilot|codex]"
  echo "Example: wt-new feature123"
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
  # ── RESUME PATH ──────────────────────────────────────────────────────────
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    printf "\033]1337;SetBadgeFormat=%s\a" "$(echo -n "RD: $NAME" | base64)"
  fi

  echo ""
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo -e "\033[1;33m  🔄 RESUMING: feature/${NAME}\033[0m"
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo -e "\033[1;33m  Mode     : resume\033[0m"
  echo -e "\033[1;33m  Session  : RD: ${NAME}\033[0m"
  echo -e "\033[1;36m  Dir      : ${WORKTREE_DIR}\033[0m"
  echo -e "\033[1;36m  Branch   : feature/${NAME}\033[0m"
  echo -e "\033[1;35m  Agent    : ${AGENT}\033[0m"
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo ""

  cd "$WORKTREE_DIR"
  case "$AGENT" in
    claude)
      claude --resume "RD: $NAME"
      ;;
    copilot)
      copilot --allow-all
      ;;
    codex)
      codex
      ;;
  esac
else
  # ── NEW SESSION PATH ──────────────────────────────────────────────────────
  if git -C "$REPO" show-ref --quiet "refs/heads/$BRANCH"; then
    echo "Error: branch already exists but directory is missing: $BRANCH"
    echo "Check worktree status: git worktree list"
    exit 1
  fi

  echo "Switching to $BASE_BRANCH..."
  git -C "$REPO" checkout "$BASE_BRANCH"

  echo "Creating worktree: $WORKTREE_DIR (branch: $BRANCH)"
  git -C "$REPO" worktree add "$WORKTREE_DIR" -b "$BRANCH"
  echo "✅ Worktree created"

  LOCAL_SETTINGS="$REPO/.claude/settings.local.json"
  if [[ -f "$LOCAL_SETTINGS" ]]; then
    mkdir -p "$WORKTREE_DIR/.claude"
    cp "$LOCAL_SETTINGS" "$WORKTREE_DIR/.claude/settings.local.json"
    echo "✅ Copied .claude/settings.local.json to worktree"
  fi

  ENV_FILE="$REPO/.env"
  if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "$WORKTREE_DIR/.env"
    echo "✅ Copied .env to worktree"
  fi

  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    printf "\033]1337;SetBadgeFormat=%s\a" "$(echo -n "RD: $NAME" | base64)"
  fi

  echo ""
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo -e "\033[1;32m  🚀 NEW SESSION: feature/${NAME}\033[0m"
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo -e "\033[1;32m  Mode     : new\033[0m"
  echo -e "\033[1;33m  Session  : RD: ${NAME}\033[0m"
  echo -e "\033[1;36m  Dir      : ${WORKTREE_DIR}\033[0m"
  echo -e "\033[1;36m  Branch   : feature/${NAME}\033[0m"
  echo -e "\033[1;35m  Agent    : ${AGENT}\033[0m"
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
fi

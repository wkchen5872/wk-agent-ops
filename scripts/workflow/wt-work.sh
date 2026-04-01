#!/usr/bin/env bash
# wt-work — Work on a Git worktree: creates if new, resumes if existing
#
# Usage:
#   wt-work <feature-name> [--base <branch>] [--agent claude|copilot|gemini|codex] [--session <id|name>]
#
# Example:
#   wt-work feature123
#   wt-work feature123 --base main
#   wt-work feature123 --agent copilot
#   wt-work feature123 --agent gemini
#   wt-work feature123 -a codex
#   wt-work feature123 --session a469f20a-a791-4c6f-af7a-5a0e599527f4
#   wt-work feature123 -s my-session-name
#
# Description:
#   If the worktree already exists → resumes the agent session and passes /opsx:apply.
#   Otherwise → creates a feature/<name> branch and worktree from BASE_BRANCH,
#   inheriting openspec/changes/ planning files committed to that branch,
#   then starts a new agent session and passes /opsx:apply.
#
#   Use --session to specify a particular AI CLI session ID or name to resume.
#
# Prerequisites:
#   - Must be run inside a git repo
#   - BASE_BRANCH (default: main) must exist
#   - openspec planning (opsx:new + opsx:continue x4) must be committed to BASE_BRANCH

set -euo pipefail

NAME=""
AGENT="claude"
BASE_BRANCH="main"
SESSION=""

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
    --session|-s)
      SESSION="${2:-}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: wt-work <feature-name> [--base <branch>] [--agent claude|copilot|gemini|codex] [--session <id|name>]"
      exit 1
      ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$1"
      else
        echo "Unexpected argument: $1"
        echo "Usage: wt-work <feature-name> [--base <branch>] [--agent claude|copilot|gemini|codex] [--session <id|name>]"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: wt-work <feature-name> [--base <branch>] [--agent claude|copilot|gemini|codex] [--session <id|name>]"
  echo "Example: wt-work feature123"
  exit 1
fi

if [[ "$AGENT" != "claude" && "$AGENT" != "copilot" && "$AGENT" != "gemini" && "$AGENT" != "codex" ]]; then
  echo "Error: --agent must be one of: claude, copilot, gemini, codex (got: $AGENT)"
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
  if [[ -n "$SESSION" ]]; then
  echo -e "\033[1;33m  Session  : ${SESSION}\033[0m"
  else
  echo -e "\033[1;33m  Session  : RD: ${NAME}\033[0m"
  fi
  echo -e "\033[1;36m  Dir      : ${WORKTREE_DIR}\033[0m"
  echo -e "\033[1;36m  Branch   : feature/${NAME}\033[0m"
  echo -e "\033[1;35m  Agent    : ${AGENT}\033[0m"
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo ""

  cd "$WORKTREE_DIR"
  case "$AGENT" in
    claude)
      if [[ -n "$SESSION" ]]; then
        claude --resume "$SESSION" "/opsx:apply $NAME" --enable-auto-mode
      else
        claude --resume "RD: $NAME" "/opsx:apply $NAME" --enable-auto-mode
      fi
      ;;
    copilot)
      if [[ -n "$SESSION" ]]; then
        copilot --resume="$SESSION" --allow-all -i "/openspec-apply-change $NAME"
      else
        copilot --resume --allow-all -i "/openspec-apply-change $NAME"
      fi
      ;;
    gemini)
      if [[ -n "$SESSION" ]]; then
        gemini --resume "$SESSION" -i "/opsx:apply $NAME"
      else
        gemini --resume latest -i "/opsx:apply $NAME"
      fi
      ;;
    codex)
      codex "/opsx:apply $NAME"
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
  if [[ -n "$SESSION" ]]; then
  echo -e "\033[1;33m  Session  : ${SESSION}\033[0m"
  else
  echo -e "\033[1;33m  Session  : RD: ${NAME}\033[0m"
  fi
  echo -e "\033[1;36m  Dir      : ${WORKTREE_DIR}\033[0m"
  echo -e "\033[1;36m  Branch   : feature/${NAME}\033[0m"
  echo -e "\033[1;35m  Agent    : ${AGENT}\033[0m"
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo ""

  cd "$WORKTREE_DIR"

  # title 會被 agent CLI 覆蓋，title 是 conversation 的名稱
  case "$AGENT" in
    claude)
      if [[ -n "$SESSION" ]]; then
        claude --resume "$SESSION" "/opsx:apply $NAME" --enable-auto-mode
      else
        claude --name "RD: $NAME" "/opsx:apply $NAME" --enable-auto-mode
      fi
      ;;
    copilot)
      if [[ -n "$SESSION" ]]; then
        copilot --resume="$SESSION" --allow-all -i "/openspec-apply-change $NAME"
      else
        copilot --allow-all -i "/openspec-apply-change $NAME"
      fi
      ;;
    gemini)
      if [[ -n "$SESSION" ]]; then
        gemini --resume "$SESSION" -i "/opsx:apply $NAME"
      else
        gemini -i "/opsx:apply $NAME"
      fi
      ;;
    codex)
      codex "/opsx:apply $NAME"
      ;;
  esac
fi

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

usage() {
  echo "Usage: wt-work <feature-name> [--base <branch>] [--agent claude|copilot|gemini|codex] [--session <id|name>]"
}

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
      usage
      exit 1
      ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$1"
      else
        echo "Unexpected argument: $1"
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  usage
  echo "Example: wt-work feature123"
  exit 1
fi

case "$AGENT" in
  claude|copilot|gemini|codex) ;;
  *)
    echo "Error: --agent must be one of: claude, copilot, gemini, codex (got: $AGENT)"
    exit 1
    ;;
esac

REPO=$(git rev-parse --show-toplevel 2>/dev/null)

if [[ -z "$REPO" ]]; then
  echo "Error: not inside a git repo"
  exit 1
fi

WORKTREE_DIR="$REPO/.worktrees/$NAME"
BRANCH="feature/$NAME"

print_banner() {
  local title="$1" mode_label="$2" color="$3"
  local session_label="${SESSION:-RD: ${NAME}}"
  echo ""
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo -e "${color}  ${title}: feature/${NAME}\033[0m"
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo -e "${color}  Mode     : ${mode_label}\033[0m"
  echo -e "\033[1;33m  Session  : ${session_label}\033[0m"
  echo -e "\033[1;36m  Dir      : ${WORKTREE_DIR}\033[0m"
  echo -e "\033[1;36m  Branch   : feature/${NAME}\033[0m"
  echo -e "\033[1;35m  Agent    : ${AGENT}\033[0m"
  echo -e "\033[1;34m══════════════════════════════════════════════════════\033[0m"
  echo ""
}

# $1 = "true" for new session, "false" for resume
launch_agent() {
  local is_new="$1"
  case "$AGENT" in
    claude)
      if [[ -n "$SESSION" ]]; then
        claude --resume "$SESSION" "/opsx:apply $NAME" --enable-auto-mode
      elif [[ "$is_new" == "true" ]]; then
        claude --name "RD: $NAME" "/opsx:apply $NAME" --enable-auto-mode
      else
        claude --resume "RD: $NAME" "/opsx:apply $NAME" --enable-auto-mode
      fi
      ;;
    copilot)
      if [[ -n "$SESSION" ]]; then
        copilot --resume="$SESSION" --allow-all -i "/openspec-apply-change $NAME"
      elif [[ "$is_new" == "true" ]]; then
        copilot --allow-all -i "/openspec-apply-change $NAME"
      else
        copilot --resume --allow-all -i "/openspec-apply-change $NAME"
      fi
      ;;
    gemini)
      if [[ -n "$SESSION" ]]; then
        gemini --resume "$SESSION" -i "/opsx:apply $NAME"
      elif [[ "$is_new" == "true" ]]; then
        gemini -i "/opsx:apply $NAME"
      else
        gemini --resume latest -i "/opsx:apply $NAME"
      fi
      ;;
    codex)
      codex "/opsx:apply $NAME"
      ;;
  esac
}

if [[ -d "$WORKTREE_DIR" ]]; then
  # ── RESUME PATH ──────────────────────────────────────────────────────────
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    printf "\033]1337;SetBadgeFormat=%s\a" "$(echo -n "RD: $NAME" | base64)"
  fi
  print_banner "🔄 RESUMING" "resume" "\033[1;33m"
  cd "$WORKTREE_DIR"
  launch_agent "false"
else
  # ── NEW SESSION PATH ──────────────────────────────────────────────────────
  if git -C "$REPO" show-ref --quiet "refs/heads/$BRANCH"; then
    # Path 1: local branch already exists (e.g., created by PM's hook on same machine).
    echo "Creating worktree from existing local branch: $BRANCH"
    git -C "$REPO" worktree add "$WORKTREE_DIR" "$BRANCH"
  elif git -C "$REPO" ls-remote --exit-code origin "$BRANCH" &>/dev/null 2>&1; then
    # Path 2: branch exists on remote only (cross-machine: PM on another computer).
    echo "Fetching remote branch: $BRANCH"
    git -C "$REPO" fetch origin "$BRANCH"
    echo "Creating worktree from remote branch: $BRANCH"
    git -C "$REPO" worktree add "$WORKTREE_DIR" -b "$BRANCH" "origin/$BRANCH"
  else
    # Path 3: no local or remote branch — create a new one from BASE_BRANCH.
    echo "Switching to $BASE_BRANCH..."
    git -C "$REPO" checkout "$BASE_BRANCH"
    echo "Creating worktree: $WORKTREE_DIR (branch: $BRANCH)"
    git -C "$REPO" worktree add "$WORKTREE_DIR" -b "$BRANCH"
  fi
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

  print_banner "🚀 NEW SESSION" "new" "\033[1;32m"
  cd "$WORKTREE_DIR"
  launch_agent "true"
fi

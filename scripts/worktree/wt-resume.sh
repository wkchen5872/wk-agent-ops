#!/usr/bin/env bash
# wt-resume — Resume an agent session by feature name
#
# Usage:
#   wt-resume <feature-name> [--agent claude|copilot|codex]
#
# Example:
#   wt-resume feature123
#   wt-resume feature123 --agent copilot
#
# Description:
#   Resumes an agent session regardless of whether the local worktree
#   directory still exists. If the worktree is present, cd into it first.
#   For claude: uses --resume "RD: <name>". For copilot/codex: launches
#   normally in the worktree directory (no --resume equivalent).

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
      echo "Usage: wt-resume <feature-name> [--agent claude|copilot|codex]"
      exit 1
      ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$1"
      else
        echo "Unexpected argument: $1"
        echo "Usage: wt-resume <feature-name> [--agent claude|copilot|codex]"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: wt-resume <feature-name> [--agent claude|copilot|codex]"
  echo "Example: wt-resume feature123"
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

if [[ -d "$WORKTREE_DIR" ]]; then
  echo "Resuming in worktree: $WORKTREE_DIR"
  cd "$WORKTREE_DIR"
else
  echo "Worktree not found, resuming by session name: RD: $NAME"
fi

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

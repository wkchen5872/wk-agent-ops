#!/usr/bin/env bash
# wt-resume — Resume an agent session by feature name
#
# Usage:
#   wt-resume <feature-name> [--agent claude|copilot|gemini|codex] [--session <id|name>]
#
# Example:
#   wt-resume feature123
#   wt-resume feature123 --agent copilot
#   wt-resume feature123 --agent gemini
#   wt-resume feature123 --session a469f20a-a791-4c6f-af7a-5a0e599527f4
#   wt-resume feature123 -s my-session-name
#
# Description:
#   Resumes an agent session regardless of whether the local worktree
#   directory still exists. If the worktree is present, cd into it first.
#
#   Without --session:
#     Claude/Copilot: displays an interactive session selection list.
#     Gemini: auto-resumes the latest session.
#
#   With --session: forwards the value directly to the tool's --resume flag.

set -euo pipefail

NAME=""
AGENT="claude"
SESSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent|-a)
      AGENT="${2:-}"
      shift 2
      ;;
    --session|-s)
      SESSION="${2:-}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: wt-resume <feature-name> [--agent claude|copilot|gemini|codex] [--session <id|name>]"
      exit 1
      ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$1"
      else
        echo "Unexpected argument: $1"
        echo "Usage: wt-resume <feature-name> [--agent claude|copilot|gemini|codex] [--session <id|name>]"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: wt-resume <feature-name> [--agent claude|copilot|gemini|codex] [--session <id|name>]"
  echo "Example: wt-resume feature123"
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

if [[ -d "$WORKTREE_DIR" ]]; then
  echo "Resuming in worktree: $WORKTREE_DIR"
  cd "$WORKTREE_DIR"
else
  echo "Worktree not found, resuming by session"
fi

case "$AGENT" in
  claude)
    if [[ -n "$SESSION" ]]; then
      claude --resume "$SESSION"
    else
      claude --resume
    fi
    ;;
  copilot)
    if [[ -n "$SESSION" ]]; then
      copilot --resume="$SESSION" --allow-all
    else
      copilot --resume --allow-all
    fi
    ;;
  gemini)
    if [[ -n "$SESSION" ]]; then
      gemini --resume "$SESSION"
    else
      gemini --resume latest
    fi
    ;;
  codex)
    codex
    ;;
esac

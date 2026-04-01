#!/usr/bin/env bash
# wt-done — Merge worktree branch back to base branch and clean up
#
# Usage:
#   wt-done <feature-name> [--base <branch>]
#
# Example:
#   wt-done feature_name
#   wt-done feature_name --base develop
#
# Description:
#   Switches to BASE_BRANCH, merges the feature branch, removes the worktree
#   directory, prunes stale worktree entries, and deletes the branch.
#
# Prerequisites:
#   - worktree and feature branch must exist
#   - /opsx:apply and /opsx:archive must be completed inside the worktree

set -euo pipefail

NAME=""
BASE_BRANCH="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base|-b)
      BASE_BRANCH="${2:-}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: wt-done <feature-name> [--base <branch>]"
      exit 1
      ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$1"
      else
        echo "Unexpected argument: $1"
        echo "Usage: wt-done <feature-name> [--base <branch>]"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: wt-done <feature-name> [--base <branch>]"
  echo "Example: wt-done feature_name"
  exit 1
fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null)

if [[ -z "$REPO" ]]; then
  echo "Error: not inside a git repo"
  exit 1
fi

WORKTREE_DIR="$REPO/.worktrees/$NAME"
BRANCH="feature/$NAME"

if ! git -C "$REPO" show-ref --quiet "refs/heads/$BRANCH"; then
  echo "Error: branch does not exist: $BRANCH"
  exit 1
fi

echo "Switching to $BASE_BRANCH..."
git -C "$REPO" checkout "$BASE_BRANCH"

echo "Merging $BRANCH → $BASE_BRANCH..."
if git -C "$REPO" merge "$BRANCH"; then
  echo "✅ Merge successful, cleaning up..."

  if [[ -d "$WORKTREE_DIR" ]]; then
    git -C "$REPO" worktree remove "$WORKTREE_DIR"
  fi
  git -C "$REPO" worktree prune
  git -C "$REPO" branch -d "$BRANCH"

  # Reset iTerm2 badge
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    printf "\033]1337;SetBadgeFormat=\a"
  fi

  # 重置終端機視窗標題為預設狀態
  printf "\033]0;\007"

  echo ""
  echo "✅ Done: feature/$NAME merged and cleaned up"
else
  echo ""
  echo "❌ Merge conflict detected."
  echo ""
  echo "To resolve with agent assistance, run:"
  echo ""
  echo "  wt-resume $NAME"
  echo ""
  echo "Or resolve manually, then run:"
  echo ""
  echo "  git add <conflicted-files>"
  echo "  git commit"
  echo "  git worktree remove $WORKTREE_DIR"
  echo "  git worktree prune"
  echo "  git branch -d $BRANCH"
  exit 1
fi

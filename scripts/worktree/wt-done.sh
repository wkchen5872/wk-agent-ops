#!/usr/bin/env bash
# wt-done — Merge worktree branch back to develop and clean up
#
# Usage:
#   wt-done <feature-name>
#
# Example:
#   wt-done etf-nav-fetcher
#
# Description:
#   Switches to develop, merges the feature branch, removes the worktree
#   directory, and deletes the branch.
#
# Prerequisites:
#   - worktree and feature branch must exist
#   - /opsx:apply and /opsx:archive must be completed inside the worktree

set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: wt-done <feature-name>"
  echo "Example: wt-done etf-nav-fetcher"
  exit 1
fi

NAME="$1"
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

echo "Switching to develop..."
git -C "$REPO" checkout develop

echo "Merging $BRANCH → develop..."
if git -C "$REPO" merge "$BRANCH"; then
  echo "✅ Merge successful, cleaning up..."

  if [[ -d "$WORKTREE_DIR" ]]; then
    git -C "$REPO" worktree remove "$WORKTREE_DIR"
  fi
  git -C "$REPO" worktree prune
  git -C "$REPO" branch -d "$BRANCH"

  # 重置終端機視窗標題為預設狀態
  printf "\033]0;\007"

  echo ""
  echo "✅ Done: feature/$NAME merged and cleaned up"
else
  echo ""
  echo "❌ Merge conflict. Resolve manually, then run:"
  echo ""
  echo "  git add <conflicted-files>"
  echo "  git commit"
  echo "  git worktree remove $WORKTREE_DIR"
  echo "  git branch -d $BRANCH"
  exit 1
fi

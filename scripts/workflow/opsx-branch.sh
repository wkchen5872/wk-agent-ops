#!/usr/bin/env bash
# opsx-branch — Create or switch to feature/<change-id> before OpenSpec planning.
set -euo pipefail

usage() {
  echo "Usage: opsx-branch <change-id>"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

CHANGE_ID="$1"
if [[ ! "$CHANGE_ID" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Error: change-id must be kebab-case: $CHANGE_ID" >&2
  exit 1
fi

REPO="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO" ]]; then
  echo "Error: not inside a git repo" >&2
  exit 1
fi

BRANCH="feature/$CHANGE_ID"
CURRENT="$(git -C "$REPO" branch --show-current)"
if [[ "$CURRENT" == "$BRANCH" ]]; then
  echo "Already on branch: $BRANCH"
  exit 0
fi

if git -C "$REPO" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  HELD_PATH="$(git -C "$REPO" worktree list --porcelain | awk -v ref="refs/heads/$BRANCH" '
    /^worktree / { path=substr($0, 10) }
    $0 == "branch " ref { print path; exit }
  ')"
  if [[ -n "$HELD_PATH" ]]; then
    echo "Error: $BRANCH is already checked out at: $HELD_PATH" >&2
    exit 1
  fi
  git -C "$REPO" switch "$BRANCH"
else
  git -C "$REPO" switch -c "$BRANCH"
fi

echo "Planning branch ready: $BRANCH"

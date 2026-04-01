#!/usr/bin/env bash
# pm-start — Launch (or resume) a persistent PM Master Claude session
#
# Usage:
#   pm-start
#
# Description:
#   Resolves the git repo root, derives a deterministic session name
#   ("PM: <repo-basename>"), and launches Claude in the repo root.
#   A second call resumes the existing named session.

set -euo pipefail

REPO=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

if [[ -z "$REPO" ]]; then
  echo "Error: not inside a git repo"
  exit 1
fi

PM_NAME="PM: $(basename "$REPO")"

echo "Starting PM session: $PM_NAME"
cd "$REPO"
claude --name "$PM_NAME" --permission-mode plan

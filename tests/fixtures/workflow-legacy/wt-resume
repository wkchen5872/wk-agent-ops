#!/usr/bin/env bash
# wt-resume — Resume an agent session by feature name
#
# Usage:
#   wt-resume <feature-name> [--agent <provider>] [--session <id|name>] [--path <worktree>]
#
# Example:
#   wt-resume feature123
#   wt-resume feature123 --agent copilot
#   wt-resume feature123 --agent antigravity
#   wt-resume feature123 --session a469f20a-a791-4c6f-af7a-5a0e599527f4
#   wt-resume feature123 -s my-session-name
#
# Description:
#   Resolves a registered worktree and resumes only the selected Provider.
#
#   Without --session:
#     Opens the selected Provider's native resume picker or continue behavior.
#
#   With --session: forwards the value directly to the tool's --resume flag.

set -euo pipefail

usage() {
  echo "Usage: wt-resume <feature-name> [--agent claude|codex|antigravity|agy|copilot] [--session <id|name>] [--path <worktree>]"
}

NAME=""
AGENT="claude"
SESSION=""
EXPLICIT_PATH=""

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
    --path|-p)
      EXPLICIT_PATH="${2:-}"
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
  echo "Example: wt-resume feature123"
  exit 1
fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null)

if [[ -z "$REPO" ]]; then
  echo "Error: not inside a git repo"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/runtime.sh" ]]; then
  # shellcheck source=runtime.sh
  source "$SCRIPT_DIR/runtime.sh"
elif [[ -f "$SCRIPT_DIR/wk-workflow-runtime" ]]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/wk-workflow-runtime"
else
  echo "Error: workflow runtime is not installed" >&2
  exit 1
fi

workflow_validate_provider || exit 1

resolve_status=0
WORKTREE_DIR="$(workflow_resolve_worktree "$EXPLICIT_PATH")" || resolve_status=$?
[[ $resolve_status -eq 0 ]] || exit "$resolve_status"
echo "Resuming in worktree: $WORKTREE_DIR"
cd "$WORKTREE_DIR"
workflow_print_context "$WORKTREE_DIR"
workflow_resume_session "$SESSION"

#!/usr/bin/env bash
# wt-work — Work on a Git worktree: creates if new, resumes if existing
#
# Usage:
#   wt-work <feature-name> [--base <branch>] [--agent <provider>] [--session <id|name>] [--path <worktree>]
#
# Example:
#   wt-work feature123
#   wt-work feature123 --base main
#   wt-work feature123 --agent copilot
#   wt-work feature123 --agent antigravity
#   wt-work feature123 -a codex
#   wt-work feature123 --session a469f20a-a791-4c6f-af7a-5a0e599527f4
#   wt-work feature123 -s my-session-name
#
# Description:
#   Reuses one verified registered worktree or creates .worktrees/<name> from
#   an existing reviewed feature branch, then starts the selected Provider.
#
#   Use --session to specify a particular AI CLI session ID or name to resume.
#
# Prerequisites:
#   - Must be run inside a git repo
#   - BASE_BRANCH (default: main) must exist
#   - openspec planning (opsx:new + opsx:continue x4) must be committed to BASE_BRANCH

set -euo pipefail

usage() {
  echo "Usage: wt-work <feature-name> [--base <branch>] [--agent claude|codex|antigravity|agy|copilot] [--session <id|name>] [--path <worktree>]"
}

NAME=""
AGENT="claude"
BASE_BRANCH="main"
SESSION=""
EXPLICIT_PATH=""

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
  echo "Example: wt-work feature123"
  exit 1
fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null)

if [[ -z "$REPO" ]]; then
  echo "Error: not inside a git repo"
  exit 1
fi

WORKTREE_DIR=""
BRANCH="feature/$NAME"

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
PROJECT_WORKTREE="$REPO/.worktrees/$NAME"

set_iterm_badge() {
  if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    printf "\033]1337;SetBadgeFormat=%s\a" "$(echo -n "RD: $NAME" | base64)"
  fi
}

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

launch_agent() {
  workflow_print_context "$WORKTREE_DIR"
  workflow_launch_apply "$SESSION"
}

resolve_status=0
WORKTREE_DIR="$(workflow_resolve_worktree "$EXPLICIT_PATH")" || resolve_status=$?
if [[ $resolve_status -eq 0 ]]; then
  # ── RESUME PATH ──────────────────────────────────────────────────────────
  set_iterm_badge
  print_banner "🔄 RESUMING" "resume" "\033[1;33m"
  cd "$WORKTREE_DIR"
  launch_agent
else
  if [[ $resolve_status -ne 2 || -n "$EXPLICIT_PATH" ]]; then
    exit "$resolve_status"
  fi
  WORKTREE_DIR="$PROJECT_WORKTREE"
  # ── NEW SESSION PATH ──────────────────────────────────────────────────────
  if git -C "$REPO" show-ref --quiet "refs/heads/$BRANCH"; then
    if ! git -C "$REPO" cat-file -e "$BRANCH:openspec/changes/$NAME" 2>/dev/null; then
      echo "Error: reviewed OpenSpec planning artifacts not found on $BRANCH" >&2
      exit 1
    fi
    CURRENT_BRANCH=$(git -C "$REPO" rev-parse --abbrev-ref HEAD)
    if [[ "$CURRENT_BRANCH" == "$BRANCH" ]]; then
      if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
        echo "Error: primary checkout is dirty; commit or preserve it before relocating $BRANCH" >&2
        exit 1
      fi
      echo "Switching main worktree to $BASE_BRANCH (branch is currently active here)..."
      git -C "$REPO" switch "$BASE_BRANCH"
    fi
    echo "Creating worktree from existing local branch: $BRANCH"
    git -C "$REPO" worktree add "$WORKTREE_DIR" "$BRANCH"
  else
    if ! git -C "$REPO" remote get-url origin >/dev/null 2>&1; then
      echo "Error: reviewed planning branch not found locally and origin is not configured: $BRANCH" >&2
      exit 1
    fi
    remote_status=0
    remote_result="$(git -C "$REPO" ls-remote --exit-code origin "refs/heads/$BRANCH" 2>&1)" \
      || remote_status=$?
    if [[ $remote_status -eq 0 ]]; then
      echo "Fetching remote branch: $BRANCH"
      git -C "$REPO" fetch origin "$BRANCH:refs/remotes/origin/$BRANCH"
      if ! git -C "$REPO" cat-file -e "origin/$BRANCH:openspec/changes/$NAME" 2>/dev/null; then
      echo "Error: reviewed planning artifacts are not on origin/$BRANCH; commit/push them or provide an explicit patch hand-off" >&2
        exit 1
      fi
      echo "Creating worktree from remote branch: $BRANCH"
      git -C "$REPO" worktree add "$WORKTREE_DIR" -b "$BRANCH" "origin/$BRANCH"
    elif [[ $remote_status -eq 2 ]]; then
      echo "Error: reviewed planning branch does not exist locally or on origin: $BRANCH" >&2
      echo "Run opsx-branch $NAME, create and commit the OpenSpec artifacts, then retry." >&2
      exit 1
    else
      echo "Error: could not query origin for $BRANCH" >&2
      printf '%s\n' "$remote_result" >&2
      exit 1
    fi
  fi
  echo "✅ Worktree created"
  workflow_check_candidate "$WORKTREE_DIR"

  copy_local_file() {
    local relative="$1" source="$REPO/$1" target="$WORKTREE_DIR/$1"
    if [[ -f "$source" && ! -e "$target" ]]; then
      mkdir -p "$(dirname "$target")"
      cp "$source" "$target"
      echo "✅ Copied $relative to worktree"
    fi
  }

  copy_local_file .env
  case "$AGENT" in
    claude) copy_local_file .claude/settings.local.json ;;
    codex) copy_local_file .codex/config.toml ;;
    antigravity|copilot) ;;
  esac

  set_iterm_badge

  print_banner "🚀 NEW SESSION" "new" "\033[1;32m"
  cd "$WORKTREE_DIR"
  launch_agent
fi

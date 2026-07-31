#!/usr/bin/env bash
# pm-start — Launch a Provider planning session from the repository root.
set -euo pipefail

usage() {
  echo "Usage: pm-start [--agent claude|codex|antigravity|agy|copilot]"
}

AGENT="claude"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent|-a) AGENT="${2:-}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

REPO="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO" ]]; then
  echo "Error: not inside a git repo" >&2
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
workflow_require_provider || exit 1
PM_NAME="PM: $(basename "$REPO")"
cd "$REPO"

case "$AGENT" in
  claude) claude --name "$PM_NAME" --permission-mode plan ;;
  antigravity) agy --mode plan ;;
  codex)
    echo "Codex: select plan mode inside the Provider after launch."
    codex
    ;;
  copilot)
    echo "Copilot: select plan mode inside the Provider after launch."
    copilot
    ;;
esac

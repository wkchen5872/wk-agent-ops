#!/usr/bin/env bash
# PostToolUse compatibility hook for "openspec new change <name>".
# Normalizes supported Provider payloads and delegates Git state to opsx-branch.
# Always exits 0 — branch-first correctness belongs to the Agent guard.

set -uo pipefail

STDIN_JSON=$(cat)

# Fast exit on empty input.
[[ -z "$STDIN_JSON" ]] && exit 0

# Extract a string field from JSON. Uses jq when available, falls back to grep.
json_field() {
  local json="$1" jq_path="$2" grep_key="$3"
  if command -v jq &>/dev/null; then
    printf '%s' "$json" | jq -r "${jq_path} // empty" 2>/dev/null || true
  else
    printf '%s' "$json" \
      | grep -o "\"${grep_key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -1 \
      | sed 's/.*: *"//; s/"$//' || true
  fi
}

COMMAND=""
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
FAILED=false

if command -v jq &>/dev/null; then
  COMMAND=$(printf '%s' "$STDIN_JSON" | jq -r '
    def args_object:
      if type == "object" then .
      elif type == "string" then (fromjson? // {})
      else {} end;
    ((.tool_input // {}) | args_object | .command?) //
    ((.toolArgs // {}) | args_object | .command?) // empty
  ' 2>/dev/null || true)
  if printf '%s' "$STDIN_JSON" | jq -e '
    (.hook_event_name? == "PostToolUseFailure") or
    (.tool_response.exit_code? != null and .tool_response.exit_code != 0) or
    (.tool_response.exitCode? != null and .tool_response.exitCode != 0) or
    (.tool_result.result_type? == "failure") or
    (.toolResult.resultType? == "failure")
  ' >/dev/null 2>&1; then
    FAILED=true
  fi
  if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR=$(printf '%s' "$STDIN_JSON" \
      | jq -r '.project_dir // .cwd // .workingDirectory // empty' 2>/dev/null || true)
  fi
else
  COMMAND=$(json_field "$STDIN_JSON" '.tool_input.command' 'command')
  if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR=$(json_field "$STDIN_JSON" '.project_dir' 'project_dir')
  fi
fi

[[ "$FAILED" == true || -z "$COMMAND" ]] && exit 0

# Must contain "openspec new change" to proceed.
if ! printf '%s' "$COMMAND" | grep -qE 'openspec[[:space:]]+new[[:space:]]+change[[:space:]]+'; then
  exit 0
fi

# Extract the change name (handles double-quoted, single-quoted, and unquoted forms).
CHANGE_NAME=$(printf '%s' "$COMMAND" \
  | sed -E "s/.*openspec[[:space:]]+new[[:space:]]+change[[:space:]]+['\"]?([^'\"[:space:]]+)['\"]?.*/\1/")

[[ -z "$CHANGE_NAME" ]] && exit 0

PROJECT_DIR="${PROJECT_DIR:-$PWD}"

OPSX_BRANCH="${OPSX_BRANCH_BIN:-}"
if [[ -z "$OPSX_BRANCH" ]]; then
  OPSX_BRANCH="$(command -v opsx-branch 2>/dev/null || true)"
fi
if [[ -z "$OPSX_BRANCH" && -x "$HOME/.local/bin/opsx-branch" ]]; then
  OPSX_BRANCH="$HOME/.local/bin/opsx-branch"
fi
if [[ -z "$OPSX_BRANCH" || ! -x "$OPSX_BRANCH" ]]; then
  printf 'openspec-branch-creator: warning: opsx-branch is not installed\n' >&2
  exit 0
fi

if ! output="$(cd "$PROJECT_DIR" 2>/dev/null && "$OPSX_BRANCH" "$CHANGE_NAME" 2>&1)"; then
  printf 'openspec-branch-creator: warning: %s\n' "$output" >&2
fi

exit 0

#!/usr/bin/env bash
# PostToolUse hook: auto-creates feature/<name> branch when
# "openspec new change <name>" is detected in a Bash tool call.
# Reads stdin JSON from Claude Code's PostToolUse event.
# Always exits 0 — never blocks Claude Code.

set -uo pipefail

STDIN_JSON=$(cat)

# Fast exit on empty input.
[[ -z "$STDIN_JSON" ]] && exit 0

# Extract a string field from JSON. Uses jq when available, falls back to grep.
# Usage: json_field <json> <jq_path> <grep_key>
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

COMMAND=$(json_field "$STDIN_JSON" '.tool_input.command' 'command')

[[ -z "$COMMAND" ]] && exit 0

# Must contain "openspec new change" to proceed.
if ! printf '%s' "$COMMAND" | grep -qE 'openspec[[:space:]]+new[[:space:]]+change[[:space:]]+'; then
  exit 0
fi

# Extract the change name (handles double-quoted, single-quoted, and unquoted forms).
CHANGE_NAME=$(printf '%s' "$COMMAND" \
  | sed -E "s/.*openspec[[:space:]]+new[[:space:]]+change[[:space:]]+['\"]?([^'\"[:space:]]+)['\"]?.*/\1/")

[[ -z "$CHANGE_NAME" ]] && exit 0

# Resolve project directory: env var → JSON field → PWD.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR=$(json_field "$STDIN_JSON" '.project_dir' 'project_dir')
fi
PROJECT_DIR="${PROJECT_DIR:-$PWD}"

BRANCH="feature/$CHANGE_NAME"

# ── Trigger notice ───────────────────────────────────────────────────────────
printf '\n┌─────────────────────────────────────────────┐\n'
printf   '│  openspec-branch-creator                    │\n'
printf   '│  Triggered by: openspec new change          │\n'
printf   "│  Change : %-33s│\n" "$CHANGE_NAME"
printf   '└─────────────────────────────────────────────┘\n'

# ── Create or switch to the branch; log errors to stderr but always exit 0. ──
if git -C "$PROJECT_DIR" show-ref --quiet "refs/heads/$BRANCH" 2>/dev/null; then
  printf '🔀 Switching to existing branch: %s\n' "$BRANCH"
  git -C "$PROJECT_DIR" checkout "$BRANCH" 2>/dev/null \
    || { printf 'openspec-branch-creator: warning: could not checkout %s\n' "$BRANCH" >&2; exit 0; }
  BRANCH_STATUS="Already existed, switched"
else
  printf '🌿 Creating new branch: %s\n' "$BRANCH"
  git -C "$PROJECT_DIR" checkout -b "$BRANCH" 2>/dev/null \
    || { printf 'openspec-branch-creator: warning: could not create %s\n' "$BRANCH" >&2; exit 0; }
  BRANCH_STATUS="Created"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
printf '\n════════════════════════════════════════════════\n'
printf '✅ openspec-branch-creator complete\n'
printf '   Change : %s\n' "$CHANGE_NAME"
printf '   Branch : %s\n' "$BRANCH"
printf '   Status : %s\n' "$BRANCH_STATUS"
printf '════════════════════════════════════════════════\n\n'

exit 0

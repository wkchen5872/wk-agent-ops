#!/usr/bin/env bash
# PostToolUse hook: counts archived OpenSpec changes and displays a banner
# when the delta since the last entropy-check reaches ENTROPY_THRESHOLD.
# Reads stdin JSON from Claude Code's PostToolUse event.
# Always exits 0 — never blocks Claude Code or Gemini CLI.

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

COMMAND=$(json_field "$STDIN_JSON" '.tool_input.command' 'command')

[[ -z "$COMMAND" ]] && exit 0

# Must contain "openspec archive" to proceed.
if ! printf '%s' "$COMMAND" | grep -qE 'openspec[[:space:]]+archive'; then
  exit 0
fi

# Resolve project directory: env var → JSON field → PWD.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR=$(json_field "$STDIN_JSON" '.project_dir' 'project_dir')
fi
PROJECT_DIR="${PROJECT_DIR:-$PWD}"

ARCHIVE_DIR="$PROJECT_DIR/openspec/changes/archive"
STATE_FILE="$PROJECT_DIR/openspec/.entropy-state"

# Count current archive directories.
ARCHIVE_COUNT=0
if [[ -d "$ARCHIVE_DIR" ]]; then
  ARCHIVE_COUNT=$(find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d '[:space:]')
fi

# Read watermark (treat missing file as 0).
WATERMARK=0
if [[ -f "$STATE_FILE" ]]; then
  WATERMARK=$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]' || echo "0")
  [[ "$WATERMARK" =~ ^[0-9]+$ ]] || WATERMARK=0
fi

THRESHOLD="${ENTROPY_THRESHOLD:-5}"

DELTA=$(( ARCHIVE_COUNT - WATERMARK ))

if (( DELTA >= THRESHOLD )); then
  printf '\n'
  printf '╔══════════════════════════════════════════════════╗\n'
  printf '║          🌀  ENTROPY CHECK DUE  🌀               ║\n'
  printf '╠══════════════════════════════════════════════════╣\n'
  printf "║  Archived changes since last check : %-11s║\n" "${DELTA}"
  printf "║  Total archives : %-31s║\n" "${ARCHIVE_COUNT}"
  printf "║  Watermark      : %-31s║\n" "${WATERMARK}"
  printf "║  Threshold      : %-31s║\n" "${THRESHOLD}"
  printf '╠══════════════════════════════════════════════════╣\n'
  printf '║  Run  /entropy-check  to audit your project.    ║\n'
  printf '╚══════════════════════════════════════════════════╝\n'
  printf '\n'

  # Optional Telegram notification.
  TELEGRAM_HOOK="$HOME/.config/ai-notify/hooks/telegram-notify.sh"
  if [[ -f "$TELEGRAM_HOOK" ]]; then
    NOTIFY_JSON=$(printf '{"event":"entropy_check_due","message":"Entropy check due: %s changes since last review"}' "$DELTA")
    printf '%s' "$NOTIFY_JSON" | bash "$TELEGRAM_HOOK" 2>/dev/null || true
  fi
fi

exit 0

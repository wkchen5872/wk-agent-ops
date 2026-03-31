#!/usr/bin/env bash
# Update individual Telegram Notify config settings.
# Usage: bash scripts/telegram-notify/update.sh [token|chat_id|notify_level|fix-hooks]
# fix-hooks: re-registers hooks with the correct format (use to fix format issues).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../notify/lib"

# shellcheck source=../notify/lib/config.sh
source "${LIB_DIR}/config.sh"

# Load existing config for current-value hints
read_config 2>/dev/null || true

KEY="${1:-}"
DEPLOYED_HOOK="${HOME}/.config/ai-notify/hooks/telegram-notify.sh"

show_menu() {
  echo ""
  echo "── Telegram Notify — Update Settings ──"
  echo ""
  echo "  1) Bot Token"
  echo "  2) Chat ID"
  echo "  3) Notification Level (current: ${NOTIFY_LEVEL:-all})"
  echo "  4) Fix hook registration (re-register with correct format)"
  echo "  q) Quit"
  echo ""
}

update_token() {
  echo ""
  echo "Current token ends in: ...${TELEGRAM_BOT_TOKEN: -4}"
  read -rp "New Bot Token: " new_token
  if [[ -z "${new_token}" ]]; then
    echo "Aborted — no change made."
    return
  fi
  update_config_key "TELEGRAM_BOT_TOKEN" "${new_token}"
  echo "✓ TELEGRAM_BOT_TOKEN updated."
}

update_chat_id() {
  echo ""
  echo "Current Chat ID: ${TELEGRAM_CHAT_ID:-<not set>}"
  read -rp "New Chat ID: " new_id
  if [[ -z "${new_id}" ]]; then
    echo "Aborted — no change made."
    return
  fi
  update_config_key "TELEGRAM_CHAT_ID" "${new_id}"
  echo "✓ TELEGRAM_CHAT_ID updated."
}

update_notify_level() {
  echo ""
  echo "  all         — Stop + Notification events"
  echo "  notify_only — Notification events only (suppress Stop)"
  echo ""
  echo "Current level: ${NOTIFY_LEVEL:-all}"
  local new_level=""
  while true; do
    read -rp "New level (all / notify_only): " new_level
    if [[ "${new_level}" == "all" || "${new_level}" == "notify_only" ]]; then
      break
    fi
    echo "Invalid. Please enter 'all' or 'notify_only'."
  done
  update_config_key "NOTIFY_LEVEL" "${new_level}"
  echo "✓ NOTIFY_LEVEL updated to ${new_level}."
}

fix_hooks() {
  # shellcheck source=../notify/lib/registry.sh
  source "${LIB_DIR}/registry.sh"

  echo ""
  echo "── Re-registering hooks with correct format ──"
  echo ""

  if [[ ! -f "${DEPLOYED_HOOK}" ]]; then
    echo "ERROR: Deployed hook not found at ${DEPLOYED_HOOK}"
    echo "Please run install.sh first."
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required. Please install jq and re-run."
    return 1
  fi

  # Unregister old/broken entries, then re-register with correct nested format
  unregister_hook "${DEPLOYED_HOOK}"
  register_hook "${DEPLOYED_HOOK}"

  echo ""
  echo "✓ Hooks re-registered. Restart Claude Code to apply changes."
}

# Handle direct key argument
case "${KEY}" in
  token)        update_token;        exit 0 ;;
  chat_id)      update_chat_id;      exit 0 ;;
  notify_level) update_notify_level; exit 0 ;;
  fix-hooks)    fix_hooks;           exit 0 ;;
  "")
    # Interactive menu
    while true; do
      show_menu
      read -rp "Select option: " choice
      case "${choice}" in
        1) update_token ;;
        2) update_chat_id ;;
        3) update_notify_level ;;
        4) fix_hooks ;;
        q|Q) echo ""; echo "Done."; exit 0 ;;
        *) echo "Invalid choice." ;;
      esac
    done
    ;;
  *)
    echo "Unknown key: ${KEY}"
    echo "Usage: $0 [token|chat_id|notify_level|fix-hooks]"
    exit 1
    ;;
esac

#!/usr/bin/env bash
# Update individual Telegram Notify config settings.
# Usage: bash scripts/notify/telegram/update.sh [token|chat_id|notify_level|fix-hooks|copilot-hooks|status]
# fix-hooks: re-registers hooks with the correct format (use to fix format issues).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# shellcheck source=../notify/lib/config.sh
source "${LIB_DIR}/config.sh"
# shellcheck source=../notify/lib/registry.sh
source "${LIB_DIR}/registry.sh"

# Load existing config for current-value hints
read_config 2>/dev/null || true
NOTIFY_LEVEL="$(normalize_notify_level "${NOTIFY_LEVEL:-all}" 2>/dev/null || printf '%s' 'all')"

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
  echo "  5) Register Copilot CLI hooks"
  echo "  6) Show provider status"
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
  echo "  all                — completion + action required + failure"
  echo "  attention_required — action required + failure; suppress successful completion"
  echo ""
  echo "Current level: ${NOTIFY_LEVEL:-all}"
  local new_level=""
  while true; do
    read -rp "New level (all / attention_required) [${NOTIFY_LEVEL:-all}]: " new_level
    new_level="${new_level:-${NOTIFY_LEVEL:-all}}"
    if [[ "${new_level}" == "all" || "${new_level}" == "attention_required" ]]; then
      break
    fi
    echo "Invalid. Please enter 'all' or 'attention_required'."
  done
  update_config_key "NOTIFY_LEVEL" "${new_level}"
  echo "✓ NOTIFY_LEVEL updated to ${new_level}."
}

fix_hooks() {
  echo ""
  echo "── Re-registering hooks with correct format ──"
  echo ""

  if [[ ! -f "${DEPLOYED_HOOK}" ]]; then
    echo "ERROR: Deployed hook not found at ${DEPLOYED_HOOK}"
    echo "Please run scripts/notify/telegram/install.sh first."
    return 1
  fi

  # Re-deploy hook script from source
  cp "${SCRIPT_DIR}/hook.sh" "${DEPLOYED_HOOK}"
  chmod +x "${DEPLOYED_HOOK}"
  echo "  ✓ Hook script updated at ${DEPLOYED_HOOK}"

  # Unregister old/broken entries, then re-register with correct native formats.
  unregister_hook "${DEPLOYED_HOOK}"
  register_hook "${DEPLOYED_HOOK}"

  # Re-register Copilot hooks if hooks.json already exists
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "${PWD}")"
  if [[ -f "${repo_root}/.github/hooks/hooks.json" ]]; then
    unregister_hook_copilot "${DEPLOYED_HOOK}"
    register_hook_copilot "${DEPLOYED_HOOK}"
  fi

  echo ""
  echo "✓ Hooks re-registered. Restart active AI CLIs to apply changes."
  [[ -f "${CODEX_HOOKS}" ]] && echo "  ℹ Review and trust Codex hooks with /hooks."
}

register_copilot_hooks() {
  echo ""
  echo "── Register Copilot CLI Hooks ──"
  echo ""

  if [[ ! -f "${DEPLOYED_HOOK}" ]]; then
    echo "ERROR: Deployed hook not found at ${DEPLOYED_HOOK}"
    echo "Please run scripts/notify/telegram/install.sh first."
    return 1
  fi

  register_hook_copilot "${DEPLOYED_HOOK}"
  echo "  ℹ You may want to commit .github/hooks/hooks.json to your repository."
  echo ""
  echo "✓ Copilot CLI hooks registered."
}

show_status() {
  echo ""
  echo "── Telegram Notify — Provider Status ──"
  echo ""
  show_hook_status "${DEPLOYED_HOOK}"
}

# Handle direct key argument
case "${KEY}" in
  token)          update_token;          exit 0 ;;
  chat_id)        update_chat_id;        exit 0 ;;
  notify_level)   update_notify_level;   exit 0 ;;
  fix-hooks)      fix_hooks;             exit 0 ;;
  copilot-hooks)  register_copilot_hooks; exit 0 ;;
  status)         show_status;            exit 0 ;;
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
        5) register_copilot_hooks ;;
        6) show_status ;;
        q|Q) echo ""; echo "Done."; exit 0 ;;
        *) echo "Invalid choice." ;;
      esac
    done
    ;;
  *)
    echo "Unknown key: ${KEY}"
    echo "Usage: $0 [token|chat_id|notify_level|fix-hooks|copilot-hooks|status]"
    exit 1
    ;;
esac

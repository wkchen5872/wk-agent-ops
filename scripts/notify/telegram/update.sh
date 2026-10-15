#!/usr/bin/env bash
# Update individual Telegram Notify config settings.
# Usage: bash scripts/notify/telegram/update.sh [token|chat_id|types|notify_level|fix-hooks|copilot-hooks|status]
# fix-hooks: re-registers hooks with the correct format (use to fix format issues).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# shellcheck source=../notify/lib/config.sh
source "${LIB_DIR}/config.sh"
# shellcheck source=../notify/lib/registry.sh
source "${LIB_DIR}/registry.sh"
# shellcheck source=../lib/settings.sh
source "${LIB_DIR}/settings.sh"
# shellcheck source=../lib/runtime.sh
source "${LIB_DIR}/runtime.sh"

# Load existing config for current-value hints
read_config 2>/dev/null || true
NOTIFY_LEVEL="$(normalize_notify_level "${NOTIFY_LEVEL:-all}" 2>/dev/null || printf '%s' 'all')"

KEY="${1:-}"
DEPLOYED_HOOK="${HOME}/.config/ai-notify/hooks/telegram-notify.sh"

show_menu() {
  echo ""
  echo "── Telegram 通知設定 ──"
  echo ""
  echo "通知"
  echo "  1) 通知類型（共用＋Codex 專用）"
  echo "  2) 工具支援與按需檢查狀態"
  echo "Telegram 連線設定"
  echo "  3) Bot Token"
  echo "  4) Chat ID"
  echo "測試與修復"
  echo "  5) 修復與更新 hook"
  echo "  6) 註冊 Copilot CLI hooks"
  echo "  7) 執行離線通知測試"
  echo "  q) 離開"
  echo ""
}

update_token() {
  echo ""
  local current_token="${TELEGRAM_BOT_TOKEN:-}"
  echo "Current token ends in: ...${current_token: -4}"
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
    read -rp "New level (all / attention_required) [${NOTIFY_LEVEL:-all}]: " new_level || return 0
    new_level="${new_level:-${NOTIFY_LEVEL:-all}}"
    if [[ "${new_level}" == "all" || "${new_level}" == "attention_required" ]]; then
      break
    fi
    echo "Invalid. Please enter 'all' or 'attention_required'."
  done
  local completion=true
  [[ "${new_level}" == attention_required ]] && completion=false
  update_config_keys NOTIFY_LEVEL "${new_level}" NOTIFY_COMPLETION "${completion}" NOTIFY_ACTION_REQUIRED true NOTIFY_FAILURE true
  NOTIFY_LEVEL="${new_level}"
  NOTIFY_COMPLETION="${completion}"; NOTIFY_ACTION_REQUIRED=true; NOTIFY_FAILURE=true
  echo "✓ NOTIFY_LEVEL updated to ${new_level}."
}

update_notify_types() {
  if edit_notify_types; then
    save_notify_draft
    deploy_notify_files
    ensure_codex_runtime || true
    register_hook "${DEPLOYED_HOOK}"
    echo '✓ 通知類型已儲存。'
    echo 'Codex 新 hook 需在 /hooks 信任並啟用；可用 status 查看支援狀態。'
  fi
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
  deploy_notify_files
  ensure_codex_runtime || true
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
  init_notify_draft
  show_notify_draft
  show_codex_wait_status
}

# Handle direct key argument
case "${KEY}" in
  token)          update_token;          exit 0 ;;
  chat_id)        update_chat_id;        exit 0 ;;
  notify_level)   update_notify_level;   exit 0 ;;
  types)          update_notify_types;   exit 0 ;;
  fix-hooks)      fix_hooks;             exit 0 ;;
  copilot-hooks)  register_copilot_hooks; exit 0 ;;
  status)         show_status;            exit 0 ;;
  "")
    # Interactive menu
    while true; do
      show_menu
      read -rp "選擇：" choice || exit 0
      case "${choice}" in
        1) update_notify_types ;;
        2) show_status ;;
        3) update_token ;;
        4) update_chat_id ;;
        5) fix_hooks ;;
        6) register_copilot_hooks ;;
        7) bash "${SCRIPT_DIR}/test.sh" ;;
        q|Q) echo ""; echo "Done."; exit 0 ;;
        *) echo "Invalid choice." ;;
      esac
    done
    ;;
  *)
    echo "Unknown key: ${KEY}"
    echo "Usage: $0 [token|chat_id|types|notify_level|fix-hooks|copilot-hooks|status]"
    exit 1
    ;;
esac

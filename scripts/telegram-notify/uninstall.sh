#!/usr/bin/env bash
# Uninstall Telegram Notify hook.
# Removes: hook entries from settings.json, TELEGRAM_* keys from config,
#          and the deployed hook script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../notify/lib"

# shellcheck source=../notify/lib/config.sh
source "${LIB_DIR}/config.sh"
# shellcheck source=../notify/lib/registry.sh
source "${LIB_DIR}/registry.sh"

DEPLOYED_HOOK="${HOME}/.config/ai-notify/hooks/telegram-notify.sh"

echo ""
echo "── Telegram Notify — Uninstall ──"
echo ""
echo "This will:"
echo "  • Remove hook entries from ~/.claude/settings.json"
echo "  • Remove TELEGRAM_* keys from ~/.config/ai-notify/config"
echo "  • Delete ${DEPLOYED_HOOK}"
echo ""
read -rp "Continue? [y/N]: " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

echo ""

# 1. Unregister from AI CLI settings
unregister_hook "${DEPLOYED_HOOK}"

# 2. Remove TELEGRAM_* config keys
remove_config_keys_by_prefix "TELEGRAM_"
echo "✓ Removed TELEGRAM_* keys from ${AI_NOTIFY_CONFIG}"

# 3. Remove deployed hook script
if [[ -f "${DEPLOYED_HOOK}" ]]; then
  rm -f "${DEPLOYED_HOOK}"
  echo "✓ Removed ${DEPLOYED_HOOK}"
else
  echo "  (Hook file not found — already removed)"
fi

echo ""
echo "✓ Telegram Notify uninstalled."
echo "  To reinstall: bash ${SCRIPT_DIR}/install.sh"
echo ""

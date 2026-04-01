#!/usr/bin/env bash
# Telegram Notify — Interactive Install Wizard
# Usage: bash scripts/notify/telegram/install.sh
# All machine state is created by this script; nothing is modified at dev time.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# shellcheck source=../notify/lib/config.sh
source "${LIB_DIR}/config.sh"
# shellcheck source=../notify/lib/registry.sh
source "${LIB_DIR}/registry.sh"

HOOK_DEPLOY_DIR="${HOME}/.config/ai-notify/hooks"
DEPLOYED_HOOK="${HOOK_DEPLOY_DIR}/telegram-notify.sh"
TELEGRAM_API="https://api.telegram.org/bot"

# ── Helpers ────────────────────────────────────────────────────────────────────
print_header() {
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║      Telegram Notify — AI CLI Hook Install Wizard    ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
}

print_step() {
  echo ""
  echo "── Step $1: $2 ──"
}

prompt() {
  local var_name="$1"
  local prompt_text="$2"
  local default="${3:-}"
  local value=""

  if [[ -n "${default}" ]]; then
    read -rp "${prompt_text} [${default}]: " value
    value="${value:-${default}}"
  else
    while [[ -z "${value}" ]]; do
      read -rp "${prompt_text}: " value
    done
  fi
  printf -v "${var_name}" '%s' "${value}"
}

validate_token() {
  local token="$1"
  local response
  response="$(curl --silent --max-time 10 "${TELEGRAM_API}${token}/getMe" 2>/dev/null || true)"
  if echo "${response}" | grep -q '"ok":true'; then
    echo "${response}"
    return 0
  fi
  return 1
}

get_chat_id() {
  local token="$1"
  local response
  response="$(curl --silent --max-time 10 "${TELEGRAM_API}${token}/getUpdates" 2>/dev/null || true)"
  if command -v jq &>/dev/null; then
    echo "${response}" | jq -r '.result[-1].message.chat.id // empty' 2>/dev/null || true
  else
    echo "${response}" | grep -o '"id":[0-9-]*' | tail -1 | grep -o '[0-9-]*' || true
  fi
}

# ── Idempotency check ──────────────────────────────────────────────────────────
# Source existing config to detect previously installed values
read_config 2>/dev/null || true

print_header

echo "This wizard will:"
echo "  1. Guide you through creating a Telegram Bot"
echo "  2. Validate your Bot Token"
echo "  3. Auto-detect your Chat ID"
echo "  4. Set your notification level"
echo "  5. Deploy the hook to ~/.config/ai-notify/"
echo "  6. Register hooks in ~/.claude/settings.json"
echo "  7. Optionally register Copilot CLI hooks"
echo "  8. Send a test notification"
echo ""
echo "Press Ctrl+C at any time to cancel."

# ── Step 1: Create Bot ─────────────────────────────────────────────────────────
print_step 1 "Create a Telegram Bot"
echo ""
echo "If you don't have a Bot yet:"
echo "  1. Open Telegram and search for @BotFather"
echo "  2. Send /newbot"
echo "  3. Follow the prompts to name your bot"
echo "  4. BotFather will give you a token like: 7123456789:ABCdef..."
echo ""

# ── Step 2: Bot Token ──────────────────────────────────────────────────────────
print_step 2 "Enter and Validate Bot Token"

NEW_TOKEN=""
while true; do
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    read -rp "Bot Token [existing token kept, press Enter to skip or type new]: " NEW_TOKEN
    if [[ -z "${NEW_TOKEN}" ]]; then
      NEW_TOKEN="${TELEGRAM_BOT_TOKEN}"
      echo "↳ Using existing token."
    fi
  else
    prompt NEW_TOKEN "Bot Token"
  fi

  echo -n "  Validating token... "
  if validate_token "${NEW_TOKEN}" > /dev/null 2>&1; then
    echo "✓ Valid"
    break
  else
    echo "✗ Invalid or network error. Please check your token and try again."
    NEW_TOKEN=""
    TELEGRAM_BOT_TOKEN=""
  fi
done

# ── Step 3: Chat ID ────────────────────────────────────────────────────────────
print_step 3 "Detect Chat ID"

NEW_CHAT_ID=""
if [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo "  Existing Chat ID found: ${TELEGRAM_CHAT_ID}"
  read -rp "  Press Enter to keep it or type a new Chat ID: " NEW_CHAT_ID
  NEW_CHAT_ID="${NEW_CHAT_ID:-${TELEGRAM_CHAT_ID}}"
else
  echo ""
  echo "  To get your Chat ID automatically:"
  echo "    1. Start your bot by sending it any message in Telegram"
  echo "    2. Press Enter below to auto-detect"
  echo ""
  read -rp "  Press Enter after sending a message to your bot: " _dummy

  echo -n "  Detecting Chat ID... "
  NEW_CHAT_ID="$(get_chat_id "${NEW_TOKEN}")"

  if [[ -n "${NEW_CHAT_ID}" ]]; then
    echo "✓ Found: ${NEW_CHAT_ID}"
  else
    echo "✗ Could not auto-detect."
    echo "  Manual fallback: visit https://api.telegram.org/bot${NEW_TOKEN}/getUpdates"
    prompt NEW_CHAT_ID "Enter your Chat ID manually"
  fi
fi

# ── Step 4: Notify Level ───────────────────────────────────────────────────────
print_step 4 "Choose Notification Level"
echo ""
echo "  all         — notify on task complete (Stop) AND action required (Notification)"
echo "  notify_only — notify only on action required (Notification); suppress Stop"
echo ""

CURRENT_LEVEL="${NOTIFY_LEVEL:-all}"
NEW_LEVEL=""
while true; do
  prompt NEW_LEVEL "Notification level (all / notify_only)" "${CURRENT_LEVEL}"
  if [[ "${NEW_LEVEL}" == "all" || "${NEW_LEVEL}" == "notify_only" ]]; then
    break
  fi
  echo "  Invalid choice. Please enter 'all' or 'notify_only'."
  NEW_LEVEL=""
done

# ── Step 5: Write config ───────────────────────────────────────────────────────
print_step 5 "Write Config"

write_config \
  "TELEGRAM_ENABLED=true" \
  "TELEGRAM_BOT_TOKEN=\"${NEW_TOKEN}\"" \
  "TELEGRAM_CHAT_ID=\"${NEW_CHAT_ID}\"" \
  "NOTIFY_LEVEL=${NEW_LEVEL}"

echo "  ✓ Config written to ${AI_NOTIFY_CONFIG} (chmod 600)"

# ── Step 6: Deploy hook ────────────────────────────────────────────────────────
print_step 6 "Deploy Hook Script"

mkdir -p "${HOOK_DEPLOY_DIR}"
cp "${SCRIPT_DIR}/hook.sh" "${DEPLOYED_HOOK}"
chmod +x "${DEPLOYED_HOOK}"
echo "  ✓ Hook deployed to ${DEPLOYED_HOOK}"

# ── Step 7: Register in AI CLI settings ───────────────────────────────────────
print_step 7 "Register Hooks in AI CLI Settings"

register_hook "${DEPLOYED_HOOK}"

# ── Step 8: Register Copilot CLI hooks (opt-in) ────────────────────────────────
print_step 8 "Register Copilot CLI Hooks (optional)"
echo ""
echo "  Copilot CLI hooks are stored in .github/hooks/hooks.json inside your repo."
echo "  This file can be committed so all machines benefit automatically."
echo ""
read -rp "  Register Copilot CLI hooks? Writes .github/hooks/hooks.json in your repo. [y/N]: " _copilot_choice
if [[ "${_copilot_choice}" =~ ^[Yy]$ ]]; then
  register_hook_copilot "${DEPLOYED_HOOK}"
  echo "  ℹ You may want to commit .github/hooks/hooks.json to your repository."
fi

# ── Step 9: Test notification ──────────────────────────────────────────────────
print_step 9 "Send Test Notification"

echo -n "  Sending test message to Telegram... "
TEST_RESPONSE="$(curl \
  --silent \
  --max-time 10 \
  -X POST "https://api.telegram.org/bot${NEW_TOKEN}/sendMessage" \
  -d "chat_id=${NEW_CHAT_ID}" \
  -d "parse_mode=Markdown" \
  --data-urlencode "text=✅ *Telegram Notify Installed!*

AI CLI hook is active. You will receive notifications when tasks complete or require action.

🔧 Notification level: ${NEW_LEVEL}" \
  2>/dev/null || true)"

if echo "${TEST_RESPONSE}" | grep -q '"ok":true'; then
  echo "✓ Test message sent!"
else
  echo "⚠ Could not send test message (network issue?). Installation is complete regardless."
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              🎉 Installation Complete!               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Config:       ${AI_NOTIFY_CONFIG}"
echo "  Hook:         ${DEPLOYED_HOOK}"
echo "  Claude hooks: ${HOME}/.claude/settings.json"
echo "  Level:        ${NEW_LEVEL}"
echo ""
echo "  To update settings: bash ${SCRIPT_DIR}/update.sh"
echo "  To uninstall:       bash ${SCRIPT_DIR}/uninstall.sh"
echo "  Or use:             /notify-setup in Claude Code"
echo ""

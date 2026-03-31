#!/usr/bin/env bash
# Shared config library for ~/.config/ai-notify/config
# This file only defines functions — it does NOT write anything on source.

AI_NOTIFY_CONFIG="${HOME}/.config/ai-notify/config"

# Read (source) the config file into the current shell environment.
# Usage: read_config
read_config() {
  if [[ -f "${AI_NOTIFY_CONFIG}" ]]; then
    # shellcheck source=/dev/null
    source "${AI_NOTIFY_CONFIG}"
  fi
}

# Write a fresh config file from key=value pairs passed as arguments.
# Creates parent directories and sets chmod 600.
# Usage: write_config KEY1=VALUE1 KEY2=VALUE2 ...
write_config() {
  mkdir -p "$(dirname "${AI_NOTIFY_CONFIG}")"
  : > "${AI_NOTIFY_CONFIG}"
  for pair in "$@"; do
    echo "${pair}" >> "${AI_NOTIFY_CONFIG}"
  done
  chmod 600 "${AI_NOTIFY_CONFIG}"
}

# Update (or insert) a single key in the config file.
# Leaves all other keys untouched.
# Usage: update_config_key KEY VALUE
update_config_key() {
  local key="$1"
  local value="$2"

  mkdir -p "$(dirname "${AI_NOTIFY_CONFIG}")"

  if [[ ! -f "${AI_NOTIFY_CONFIG}" ]]; then
    echo "${key}=\"${value}\"" > "${AI_NOTIFY_CONFIG}"
    chmod 600 "${AI_NOTIFY_CONFIG}"
    return
  fi

  if grep -q "^${key}=" "${AI_NOTIFY_CONFIG}" 2>/dev/null; then
    # Replace existing key (macOS-compatible sed with backup)
    sed -i.bak "s|^${key}=.*|${key}=\"${value}\"|" "${AI_NOTIFY_CONFIG}"
    rm -f "${AI_NOTIFY_CONFIG}.bak"
  else
    echo "${key}=\"${value}\"" >> "${AI_NOTIFY_CONFIG}"
  fi
  chmod 600 "${AI_NOTIFY_CONFIG}"
}

# Remove all keys matching a prefix from the config file.
# Usage: remove_config_keys_by_prefix PREFIX
remove_config_keys_by_prefix() {
  local prefix="$1"
  if [[ -f "${AI_NOTIFY_CONFIG}" ]]; then
    sed -i.bak "/^${prefix}/d" "${AI_NOTIFY_CONFIG}"
    rm -f "${AI_NOTIFY_CONFIG}.bak"
  fi
}

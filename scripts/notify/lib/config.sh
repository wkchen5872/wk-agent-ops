#!/usr/bin/env bash
# Shared config library for ~/.config/ai-notify/config
# This file only defines functions — it does NOT write anything on source.

AI_NOTIFY_CONFIG="${HOME}/.config/ai-notify/config"
NOTIFY_CATEGORY_KEYS=(NOTIFY_COMPLETION NOTIFY_ACTION_REQUIRED NOTIFY_FAILURE NOTIFY_CODEX_HUMAN_APPROVAL NOTIFY_CODEX_USER_INPUT)

# Missing shared keys inherit the legacy level; new Codex keys are opt-in.
notify_category_value() {
  local key="$1" value="${!1:-}"
  case "${value}" in true|false) printf '%s\n' "${value}"; return ;; esac
  case "${key}" in
    NOTIFY_COMPLETION)
      case "${NOTIFY_LEVEL:-all}" in attention_required|notify_only) echo false ;; *) echo true ;; esac ;;
    NOTIFY_ACTION_REQUIRED|NOTIFY_FAILURE) echo true ;;
    NOTIFY_CODEX_HUMAN_APPROVAL|NOTIFY_CODEX_USER_INPUT) echo false ;;
    *) return 1 ;;
  esac
}

notify_category_enabled() { [[ "$(notify_category_value "$1")" == "true" ]]; }

# Return a canonical notification level; keep the old value as a read-time alias.
normalize_notify_level() {
  case "${1:-all}" in
    all|attention_required) printf '%s\n' "${1:-all}" ;;
    notify_only) printf '%s\n' "attention_required" ;;
    *) return 1 ;;
  esac
}

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
  local tmp
  tmp="$(mktemp "${AI_NOTIFY_CONFIG}.XXXXXX")" || return 1
  if printf '%s\n' "$@" > "${tmp}" && chmod 600 "${tmp}" && mv "${tmp}" "${AI_NOTIFY_CONFIG}"; then
    return 0
  fi
  rm -f -- "${tmp}"
  return 1
}

# Update (or insert) a single key in the config file.
# Leaves all other keys untouched.
# Usage: update_config_key KEY VALUE
update_config_key() {
  update_config_keys "$1" "$2"
}

# One atomic replacement for a whole settings draft; never evaluate values.
update_config_keys() {
  [[ $# -gt 0 && $(( $# % 2 )) -eq 0 ]] || return 1
  local keys=() values=() key value line replace i tmp
  while [[ $# -gt 0 ]]; do
    key="$1"; value="$2"; shift 2
    [[ "${key}" =~ ^[A-Z][A-Z0-9_]*$ ]] || return 1
    keys+=("${key}"); values+=("${value}")
  done
  mkdir -p "$(dirname "${AI_NOTIFY_CONFIG}")" || return 1
  tmp="$(mktemp "${AI_NOTIFY_CONFIG}.XXXXXX")" || return 1
  if [[ -f "${AI_NOTIFY_CONFIG}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      replace=false
      for key in "${keys[@]}"; do
        [[ "${line}" == "${key}="* ]] && replace=true
      done
      if [[ "${replace}" != true ]]; then
        printf '%s\n' "${line}" >> "${tmp}" || { rm -f -- "${tmp}"; return 1; }
      fi
    done < "${AI_NOTIFY_CONFIG}" || { rm -f -- "${tmp}"; return 1; }
  fi
  for ((i=0; i<${#keys[@]}; i++)); do
    printf '%s=%q\n' "${keys[i]}" "${values[i]}" >> "${tmp}" || { rm -f -- "${tmp}"; return 1; }
  done
  chmod 600 "${tmp}" && mv "${tmp}" "${AI_NOTIFY_CONFIG}" && return 0
  rm -f -- "${tmp}"
  return 1
}

# Remove all keys matching a prefix from the config file.
# Usage: remove_config_keys_by_prefix PREFIX
remove_config_keys_by_prefix() {
  local prefix="$1"
  [[ -f "${AI_NOTIFY_CONFIG}" ]] || return 0
  sed -i.bak "/^${prefix}/d" "${AI_NOTIFY_CONFIG}"
  rm -f "${AI_NOTIFY_CONFIG}.bak"
}

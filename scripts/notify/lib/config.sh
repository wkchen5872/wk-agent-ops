#!/usr/bin/env bash
# Shared config library for ~/.config/ai-notify/config
# This file only defines functions — it does NOT write anything on source.

AI_NOTIFY_CONFIG="${HOME}/.config/ai-notify/config"
NOTIFY_CATEGORY_KEYS=(NOTIFY_COMPLETION NOTIFY_AUTHORIZATION NOTIFY_USER_INPUT NOTIFY_FAILURE)
NOTIFY_LEGACY_CATEGORY_KEYS=(NOTIFY_ACTION_REQUIRED NOTIFY_CODEX_HUMAN_APPROVAL NOTIFY_CODEX_USER_INPUT)
# Handoff loop progress switches; attention notices have no switch.
NOTIFY_HANDOFF_KEYS=(NOTIFY_HANDOFF_IMPLEMENT NOTIFY_HANDOFF_REVIEW NOTIFY_HANDOFF_FINISH)

# Snapshot category keys from the environment before any config file is sourced,
# so the environment and the file stay separate sources (design decision 2).
for _notify_key in "${NOTIFY_CATEGORY_KEYS[@]}" "${NOTIFY_LEGACY_CATEGORY_KEYS[@]}" "${NOTIFY_HANDOFF_KEYS[@]}"; do
  printf -v "_NOTIFY_ENV_${_notify_key}" '%s' "${!_notify_key:-}"
done
unset _notify_key

# Only the exact strings true and false count as defined.
_notify_bool() { case "$1" in true|false) printf '%s\n' "$1" ;; *) return 1 ;; esac; }

_notify_file_value() {
  local key="$1" line value="" found=false
  [[ -r "${AI_NOTIFY_CONFIG}" ]] || return 1
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" == "${key}="* ]] && { value="${line#*=}"; found=true; }
  done < "${AI_NOTIFY_CONFIG}"
  [[ "${found}" == true ]] || return 1
  value="${value#\"}"; value="${value%\"}"; value="${value#\'}"; value="${value%\'}"
  _notify_bool "${value}"
}

_notify_env_value() { local var="_NOTIFY_ENV_$1"; _notify_bool "${!var:-}"; }

# Legacy keys of one source: any true wins; otherwise any false; otherwise undefined.
_notify_legacy() {
  local source="$1" key value any_false=false
  shift
  for key in "$@"; do
    value="$("_notify_${source}_value" "${key}")" || continue
    [[ "${value}" == true ]] && { echo true; return 0; }
    any_false=true
  done
  [[ "${any_false}" == true ]] && echo false
}

# Order: env new key → env legacy keys → file new key → file legacy keys → default.
notify_category_value() {
  local key="$1" legacy=() value
  case "${key}" in
    NOTIFY_AUTHORIZATION) legacy=(NOTIFY_ACTION_REQUIRED NOTIFY_CODEX_HUMAN_APPROVAL) ;;
    NOTIFY_USER_INPUT) legacy=(NOTIFY_ACTION_REQUIRED NOTIFY_CODEX_USER_INPUT) ;;
    NOTIFY_COMPLETION|NOTIFY_FAILURE|NOTIFY_HANDOFF_IMPLEMENT|NOTIFY_HANDOFF_REVIEW|NOTIFY_HANDOFF_FINISH) ;;
    *) return 1 ;;
  esac
  for source in env file; do
    value="$("_notify_${source}_value" "${key}")" && { echo "${value}"; return 0; }
    if [[ ${#legacy[@]} -gt 0 ]]; then
      value="$(_notify_legacy "${source}" "${legacy[@]}")"
      [[ -n "${value}" ]] && { echo "${value}"; return 0; }
    fi
  done
  case "${key}" in
    NOTIFY_COMPLETION)
      case "${NOTIFY_LEVEL:-all}" in attention_required|notify_only) echo false ;; *) echo true ;; esac ;;
    *) echo true ;;
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
  update_config_keys_dropping "" "$@"
}

# update_config_keys_dropping "<keys to remove>" KEY VALUE... — same atomic write,
# also removing the listed keys (used to retire legacy category keys).
update_config_keys_dropping() {
  local drop=" $1 "
  shift
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
      [[ "${line}" =~ ^([A-Z][A-Z0-9_]*)= && "${drop}" == *" ${BASH_REMATCH[1]} "* ]] && replace=true
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

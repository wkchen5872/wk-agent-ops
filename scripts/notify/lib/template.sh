#!/usr/bin/env bash
# Message templates: {name} substitution only — no eval, conditions, or loops.
# Callers set tpl_<name> variables for the parameters below, then render.

shopt -u patsub_replacement 2>/dev/null || true

NOTIFY_TPL_PARAMS=" title_suffix tool model_suffix model_family_suffix project time tag message reason request_tool delay agent change round verdict commit next detail "
NOTIFY_USER_TEMPLATES="${HOME}/.config/ai-notify/templates"

# Telegram legacy Markdown treats these characters as markup inside values.
notify_escape() {
  local value="$1"
  value="${value//_/\\_}"
  value="${value//\*/\\*}"
  value="${value//\`/\\\`}"
  value="${value//\[/\\[}"
  printf '%s' "${value}"
}

# One left-to-right pass, so a substituted value is never scanned again.
_notify_render_line() {
  local rest="$1" out="" name var
  while [[ "${rest}" == *"{"* ]]; do
    out+="${rest%%\{*}"
    rest="${rest#*\{}"
    if [[ "${rest}" =~ ^([a-z_]+)\} ]] && [[ "${NOTIFY_TPL_PARAMS}" == *" ${BASH_REMATCH[1]} "* ]]; then
      name="${BASH_REMATCH[1]}"
      var="tpl_${name}"
      out+="$(notify_escape "${!var:-}")"
      rest="${rest#"${name}"\}}"
    else
      out+="{"
    fi
  done
  printf '%s' "${out}${rest}"
}

notify_render_text() {
  local line rendered out="" first=true
  while IFS= read -r line || [[ -n "${line}" ]]; do
    rendered="$(_notify_render_line "${line}")"
    # A line made only of placeholders that rendered empty is dropped.
    if [[ "${line}" =~ ^[[:space:]]*(\{[a-z_]+\}[[:space:]]*)+$ && -z "${rendered//[[:space:]]/}" ]]; then
      continue
    fi
    if [[ "${first}" == true ]]; then out="${rendered}"; first=false; else out+=$'\n'"${rendered}"; fi
  done <<< "$1"
  printf '%s' "${out}"
}

# User template wins when it is a non-empty readable file; otherwise the built-in.
notify_template_file() {
  local name="$1" builtin_dir="$2" user
  [[ "${name}" =~ ^[a-z0-9-]+$ ]] || return 1
  user="${NOTIFY_USER_TEMPLATES}/${name}.md"
  if [[ -s "${user}" && -r "${user}" ]]; then printf '%s\n' "${user}"; return 0; fi
  [[ -r "${builtin_dir}/${name}.md" ]] && printf '%s\n' "${builtin_dir}/${name}.md"
}

# notify_render <name> <built-in dir>
notify_render() {
  local file text
  file="$(notify_template_file "$1" "$2")" || return 1
  [[ -n "${file}" ]] || return 1
  text="$(cat -- "${file}" 2>/dev/null)" || text=""
  if [[ -z "${text}" && "${file}" != "$2/$1.md" ]]; then
    text="$(cat -- "$2/$1.md" 2>/dev/null)" || return 1
  fi
  notify_render_text "${text}"
}

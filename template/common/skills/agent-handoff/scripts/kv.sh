#!/usr/bin/env bash
# Minimal reader for agent-handoff files: one- or two-level "key: value" lines.
#   kv_get <file> <key>            top-level value
#   kv_get <file> <section>.<key>  value indented under "section:"
# Rules: full-line "#" comments are ignored; the value is everything after the
# first ": "; one pair of surrounding double quotes is removed. Exit 1 when absent.
kv_get() {
  local file="$1" path="$2" section="" key="$2"
  [[ -r "$file" ]] || return 1
  if [[ "$path" == *.* ]]; then section="${path%%.*}"; key="${path#*.}"; fi
  awk -v want_sec="$section" -v want_key="$key" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      indented = ($0 ~ /^[[:space:]]/)
      line = $0; sub(/^[[:space:]]+/, "", line)
      n = index(line, ":"); if (n == 0) next
      k = substr(line, 1, n - 1); v = substr(line, n + 1); sub(/^ /, "", v)
      if (!indented) { cur = (v == "" ? k : ""); if (want_sec == "" && k == want_key) { found = 1; val = v; exit } ; next }
      if (want_sec != "" && cur == want_sec && k == want_key) { found = 1; val = v; exit }
    }
    END {
      if (!found) exit 1
      if (val ~ /^".*"$/) val = substr(val, 2, length(val) - 2)
      print val
    }' "$file"
}

#!/usr/bin/env bash
# Verifies template/common/AGENTS.md stays a tool-agnostic map.
# Each check maps to a scenario in specs/portable-agents-md/spec.md.
# ponytail: grep is a floor (proves absence of tool-binding), not a ceiling —
# the "hide the parentheses" human read in the DoD is the real intent check.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/template/common/AGENTS.md"
DOCS="$ROOT/template/common/docs"
fail=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=1; }

[[ -f "$F" ]] || { echo "missing $F"; exit 1; }
header="$(sed -n '1,15p' "$F")"

# R1 — no named secondary tool binding
grep -qi 'claude code' <<<"$header"                     && ok  "R1 header names Claude Code" || bad "R1 header names Claude Code"
grep -qiE 'portable|agents\.md-aware' <<<"$header"      && ok  "R1 header states generic portability" || bad "R1 header states generic portability"
if grep -qiE '\bcodex\b|antigravity|and others supported' "$F"; then
  bad "R1 no named secondary tool anywhere"
else ok "R1 no named secondary tool anywhere"; fi

# R2 — prohibition states principle, not a .codex/ dir list
if grep -q '\.codex' "$F"; then bad "R2 no .codex/ reference"; else ok "R2 no .codex/ reference"; fi
grep -qiE 'vendored|generated' "$F"                     && ok  "R2 prohibition is principle-based" || bad "R2 prohibition is principle-based"

# R3 — stages readable with commands hidden: after stripping (Claude Code: ...),
# no bare /opsx or /openspec command may remain anywhere.
stripped="$(sed -E 's/\(Claude Code:[^)]*\)//g' "$F")"
if grep -qE '/opsx|/openspec' <<<"$stripped"; then
  bad "R3 no command survives outside a (Claude Code: ...) example"
else ok "R3 no command survives outside a (Claude Code: ...) example"; fi

# R3b — no pinned command for the open "other tools" set
if grep -q 'openspec-verify-change' "$F"; then bad "R3b no fake other-tools command"; else ok "R3b no fake other-tools command"; fi

# R4 — no dangling refs: every docs/*.md referenced ships; enforcement.md not referenced
if grep -q 'docs/enforcement.md' "$F"; then bad "R4 no reference to non-existent docs/enforcement.md"; else ok "R4 no reference to non-existent docs/enforcement.md"; fi
missing=0
while read -r ref; do
  base="${ref#docs/}"
  [[ -f "$DOCS/$base" ]] || { printf '       -> %s not in template/common/docs/\n' "$ref"; missing=1; }
done < <(grep -oE 'docs/[A-Za-z0-9_-]+\.md' "$F" | sort -u)
[[ $missing -eq 0 ]] && ok "R4 every referenced docs/*.md ships" || bad "R4 every referenced docs/*.md ships"

# R5 — no language-specific mechanics leak into the portable map
if grep -qE '\-\-cov|cov-fail-under|pytest-cov' "$F"; then bad "R5 no language-specific coverage mechanics"; else ok "R5 no language-specific coverage mechanics"; fi

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }

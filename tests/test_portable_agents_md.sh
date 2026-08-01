#!/usr/bin/env bash
# Verifies the split: the shared operating protocol lives in a MANAGED doc that stays
# tool-agnostic, while template/common/AGENTS.md is a thin project-owned pointer.
# Each check maps to a scenario in specs/portable-agents-md + install-profile-cli.
# ponytail: grep is a floor (proves the invariants), not a ceiling — the "hide the
# parentheses" read is still the real intent check.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS="$ROOT/template/common/docs"
PROTO="$DOCS/agent-protocol.md"       # managed: the relocated operating protocol
AGENTS="$ROOT/template/common/AGENTS.md"  # seed: thin pointer
BANNER='Managed by wk-agent-ops'
fail=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=1; }

[[ -f "$PROTO" ]]  || { bad "protocol doc exists ($PROTO)"; }
[[ -f "$AGENTS" ]] || { echo "missing $AGENTS"; exit 1; }

# ── Tool-invariant checks now target the protocol doc ────────────────────────
if [[ -f "$PROTO" ]]; then
  header="$(sed -n '1,22p' "$PROTO")"

  # R1 — no named secondary tool binding
  grep -qi 'claude code' <<<"$header"                && ok  "R1 protocol names Claude Code" || bad "R1 protocol names Claude Code"
  grep -qiE 'portable|agents\.md-aware' <<<"$header"  && ok  "R1 protocol states generic portability" || bad "R1 protocol states generic portability"
  if grep -qiE '\bcodex\b|antigravity|and others supported' "$PROTO"; then
    bad "R1 no named secondary tool anywhere"
  else ok "R1 no named secondary tool anywhere"; fi

  # R2 — prohibition states principle, not a .codex/ dir list
  if grep -q '\.codex' "$PROTO"; then bad "R2 no .codex/ reference"; else ok "R2 no .codex/ reference"; fi
  grep -qiE 'vendored|generated' "$PROTO"            && ok  "R2 prohibition is principle-based" || bad "R2 prohibition is principle-based"

  # R3 — stages readable with commands hidden
  stripped="$(sed -E 's/\(Claude Code:[^)]*\)//g' "$PROTO")"
  if grep -qE '/opsx|/openspec' <<<"$stripped"; then
    bad "R3 no command survives outside a (Claude Code: ...) example"
  else ok "R3 no command survives outside a (Claude Code: ...) example"; fi

  # R3b — no pinned command for the open "other tools" set
  if grep -q 'openspec-verify-change' "$PROTO"; then bad "R3b no fake other-tools command"; else ok "R3b no fake other-tools command"; fi

  # R3c — OpenSpec actions share one branch-preparation guard
  if grep -q 'opsx-branch <change-id>' "$PROTO" \
    && grep -qiE 'new.*fast-forward.*continue|new.*continue.*fast-forward' "$PROTO" \
    && grep -qiE 'non-zero|exits non-zero' "$PROTO"; then
    ok "R3c protocol guards OpenSpec new, fast-forward, and continue"
  else
    bad "R3c protocol guards OpenSpec new, fast-forward, and continue"
  fi

  # R4 — no dangling refs: every docs/*.md referenced ships; enforcement.md not referenced
  if grep -q 'docs/enforcement.md' "$PROTO"; then bad "R4 no reference to non-existent docs/enforcement.md"; else ok "R4 no reference to non-existent docs/enforcement.md"; fi
  missing=0
  while read -r ref; do
    [[ -f "$DOCS/${ref#docs/}" ]] || { printf '       -> %s not in template/common/docs/\n' "$ref"; missing=1; }
  done < <(grep -oE 'docs/[A-Za-z0-9_-]+\.md' "$PROTO" | sort -u)
  [[ $missing -eq 0 ]] && ok "R4 every referenced docs/*.md ships" || bad "R4 every referenced docs/*.md ships"

  # R5 — no language-specific mechanics leak into the protocol
  if grep -qE '\-\-cov|cov-fail-under|pytest-cov' "$PROTO"; then bad "R5 no language-specific coverage mechanics"; else ok "R5 no language-specific coverage mechanics"; fi
fi

# ── AGENTS.md is a thin pointer ──────────────────────────────────────────────
grep -q 'docs/agent-protocol.md' "$AGENTS" && ok "P1 AGENTS.md points to the protocol doc" || bad "P1 AGENTS.md points to the protocol doc"
if grep -qiE 'Definition of Done|Implementation Loop' "$AGENTS"; then
  bad "P2 AGENTS.md does not inline the protocol"
else ok "P2 AGENTS.md does not inline the protocol"; fi

# ── Managed docs carry the banner; seed docs do not ──────────────────────────
for m in agent-protocol.md okf-conventions.md; do
  grep -q "$BANNER" "$DOCS/$m" 2>/dev/null && ok "B1 managed $m has banner" || bad "B1 managed $m has banner"
done
for s in architecture.md conventions.md; do
  if grep -q "$BANNER" "$DOCS/$s" 2>/dev/null; then bad "B2 seed $s has no banner"; else ok "B2 seed $s has no banner"; fi
done

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }

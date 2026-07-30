#!/usr/bin/env bash
# Verifies the repo unified on plural .agents/ (no singular .agent/ remains live), that
# install.sh lands workflows/rules in .agents/, and that retired managed rules are removed.
# Maps to spec tooling-target-scope "Rules 必須同時送達" scenarios.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
ok(){ printf '  ok   %s\n' "$1"; }
bad(){ printf '  FAIL %s\n' "$1"; fail=1; }

# 1.2 — no live singular .agent/ reference ( .agents/ does NOT match \.agent/ )
grep -qE '\.agent/' "$ROOT/scripts/skills/install.sh" && bad "install.sh has no singular .agent/" || ok "install.sh has no singular .agent/"
grep -qE '\.agent/' "$ROOT/AGENTS.md"                  && bad "root AGENTS.md has no singular .agent/" || ok "root AGENTS.md has no singular .agent/"
# Main spec correctness (openspec/specs/tooling-target-scope) is enforced by the delta +
# sync-at-archive, not by this apply-time check.

# 1.1 — install is non-no-op into .agents/
T="$(mktemp -d)"; ( cd "$T" && git init -q )
mkdir -p "$T/.claude/rules" "$T/.agents/rules"
touch "$T/.claude/rules/openspec-commits.md" "$T/.agents/rules/openspec-commits.md"
bash "$ROOT/scripts/skills/install.sh" --target "$T" python >/dev/null 2>&1
[[ -n "$(ls -A "$T/.agents/workflows" 2>/dev/null)" ]] && ok ".agents/workflows populated" || bad ".agents/workflows populated"
[[ -n "$(ls -A "$T/.agents/rules" 2>/dev/null)" ]]     && ok ".agents/rules populated"     || bad ".agents/rules populated"
[[ ! -d "$T/.agent" ]] && ok "no singular .agent/ dir created" || bad "no singular .agent/ dir created"
[[ ! -e "$T/.claude/rules/openspec-commits.md" && ! -e "$T/.agents/rules/openspec-commits.md" ]] \
  && ok "retired openspec commit rule removed" || bad "retired openspec commit rule removed"
rm -rf "$T"

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }

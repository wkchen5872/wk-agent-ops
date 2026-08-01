#!/usr/bin/env bash
# Verifies the repo unified on plural .agents/ (no singular .agent/ remains live), that
# install.sh lands workflows/rules in .agents/, and that retired managed rules are removed.
# Maps to spec tooling-target-scope "Rules 必須同時送達" scenarios.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_ENTRYPOINT="$ROOT/template/common/.claude/commands/opsx/commit.md"
ANTIGRAVITY_ENTRYPOINT="$ROOT/template/common/.agents/workflows/opsx-commit.md"
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
mkdir -p "$T/.claude/rules" "$T/.agents/rules" \
  "$T/.claude/skills/entropy-check" "$T/.agents/skills/entropy-check" "$T/openspec"
touch "$T/.claude/rules/openspec-commits.md" "$T/.agents/rules/openspec-commits.md"
touch "$T/.claude/skills/entropy-check/SKILL.md" \
  "$T/.agents/skills/entropy-check/SKILL.md" "$T/openspec/.entropy-state"
printf 'keep-me\nopenspec/.entropy-state\n' > "$T/.gitignore"
bash "$ROOT/scripts/skills/install.sh" --target "$T" python >/dev/null 2>&1
[[ -n "$(ls -A "$T/.agents/workflows" 2>/dev/null)" ]] && ok ".agents/workflows populated" || bad ".agents/workflows populated"
[[ -n "$(ls -A "$T/.agents/rules" 2>/dev/null)" ]]     && ok ".agents/rules populated"     || bad ".agents/rules populated"
cmp -s "$CLAUDE_ENTRYPOINT" "$T/.claude/commands/opsx/commit.md" \
  && ok "Claude commit entrypoint copied exactly" || bad "Claude commit entrypoint copied exactly"
cmp -s "$ANTIGRAVITY_ENTRYPOINT" "$T/.agents/workflows/opsx-commit.md" \
  && ok "Antigravity commit entrypoint copied exactly" || bad "Antigravity commit entrypoint copied exactly"
[[ ! -d "$T/.agent" ]] && ok "no singular .agent/ dir created" || bad "no singular .agent/ dir created"
[[ ! -d "$T/.codex" ]] && ok "no .codex/ dir created" || bad "no .codex/ dir created"
[[ ! -e "$T/.claude/rules/openspec-commits.md" && ! -e "$T/.agents/rules/openspec-commits.md" ]] \
  && ok "retired openspec commit rule removed" || bad "retired openspec commit rule removed"
if [[ ! -e "$T/.claude/skills/entropy-check" \
  && ! -e "$T/.agents/skills/entropy-check" \
  && ! -e "$T/openspec/.entropy-state" \
  && "$(cat "$T/.gitignore")" == "keep-me" ]]; then
  ok "retired entropy artifacts removed without changing unrelated ignores"
else
  bad "retired entropy artifacts removed without changing unrelated ignores"
fi
rm -rf "$T"

# Linked worktrees use a .git file and share the repository hooks path.
WT_REPO="$(mktemp -d)"
WT_TARGET="${WT_REPO}-linked"
git -C "$WT_REPO" init -q
git -C "$WT_REPO" \
  -c user.name="Installer Test" \
  -c user.email="installer-test@example.invalid" \
  -c commit.gpgsign=false \
  commit --allow-empty -qm "baseline"
git -C "$WT_REPO" worktree add -q -b installer-test "$WT_TARGET"

if bash "$ROOT/scripts/skills/install.sh" --target "$WT_TARGET" python >/dev/null 2>&1; then
  ok "linked worktree accepted as repository root"
else
  bad "linked worktree accepted as repository root"
fi
cmp -s "$CLAUDE_ENTRYPOINT" "$WT_TARGET/.claude/commands/opsx/commit.md" \
  && ok "linked worktree receives Claude entrypoint" || bad "linked worktree receives Claude entrypoint"
cmp -s "$ANTIGRAVITY_ENTRYPOINT" "$WT_TARGET/.agents/workflows/opsx-commit.md" \
  && ok "linked worktree receives Antigravity entrypoint" || bad "linked worktree receives Antigravity entrypoint"
WT_HOOKS="$(git -C "$WT_TARGET" rev-parse --git-path hooks)"
cmp -s "$ROOT/template/python/hooks/pre-commit" "$WT_HOOKS/pre-commit" \
  && ok "linked worktree profile hook uses Git hooks path" || bad "linked worktree profile hook uses Git hooks path"

mkdir -p "$WT_TARGET/nested"
if bash "$ROOT/scripts/skills/install.sh" --target "$WT_TARGET/nested" >/dev/null 2>&1; then
  bad "repository subdirectory rejected as install target"
else
  ok "repository subdirectory rejected as install target"
fi

git -C "$WT_REPO" worktree remove --force "$WT_TARGET" >/dev/null 2>&1
rm -rf "$WT_REPO"

cmp -s "$CLAUDE_ENTRYPOINT" "$ROOT/.claude/commands/opsx/commit.md" \
  && ok "repository Claude commit entrypoint synchronized" || bad "repository Claude commit entrypoint synchronized"
cmp -s "$ANTIGRAVITY_ENTRYPOINT" "$ROOT/.agents/workflows/opsx-commit.md" \
  && ok "repository Antigravity commit entrypoint synchronized" || bad "repository Antigravity commit entrypoint synchronized"

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }

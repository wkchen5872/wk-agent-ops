#!/usr/bin/env bash
# Verifies the portable TDD policy, provider entrypoints, and installer mapping.
# Maps to openspec/specs/tdd-enforcement-rules scenarios.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/template/common"
PROTO="$COMMON/docs/agent-protocol.md"
RULE="$COMMON/.claude/rules/tdd-enforcement.md"
AGENTS="$COMMON/AGENTS.md"
fail=0

ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

expect_present() {
  local pattern="$1" file="$2" label="$3"
  grep -Fq "$pattern" "$file" 2>/dev/null && ok "$label" || bad "$label"
}

expect_absent() {
  local pattern="$1" file="$2" label="$3"
  grep -Fq "$pattern" "$file" 2>/dev/null && bad "$label" || ok "$label"
}

# Provider-neutral policy invariants.
expect_present "Behavior-changing work and bug fixes" "$PROTO" "policy scopes formal TDD by behavior"
expect_present "Expected Red evidence" "$PROTO" "policy defines valid Red evidence"
expect_present "Test integrity" "$PROTO" "policy protects test intent"
expect_present "Layered verification" "$PROTO" "policy layers verification"
expect_present "Conditional causal checks" "$PROTO" "policy makes causal checks conditional"
expect_absent  "minor fixes" "$PROTO" "Level 1 does not exempt behavioral fixes"

# Native rules stay thin and point at the managed policy.
expect_present "docs/agent-protocol.md" "$RULE" "native rule points to managed protocol"
expect_present "MUST read" "$RULE" "native rule requires loading the policy"
expect_absent  "實作任何 task" "$RULE" "native rule does not mandate TDD for every task"
expect_absent  "執行完整測試套件" "$RULE" "native rule does not run full suite per task"
expect_absent  "stash 或註解" "$RULE" "native rule does not prescribe unsafe revert mechanics"
expect_absent  "python -m pytest" "$RULE" "native rule is test-runner neutral"
expect_absent  "npm test" "$RULE" "native rule is language neutral"

# Codex and other AGENTS.md-aware tools enter through the portable pointer.
expect_present "docs/agent-protocol.md" "$AGENTS" "AGENTS.md points to managed protocol"

# Scratch install proves managed policy + native rule delivery.
TARGET="$(mktemp -d)"
trap 'rm -rf "$TARGET"' EXIT
( cd "$TARGET" && git init -q )
bash "$ROOT/scripts/skills/install.sh" --target "$TARGET" >/dev/null 2>&1

cmp -s "$PROTO" "$TARGET/docs/agent-protocol.md" \
  && ok "managed protocol installed exactly" || bad "managed protocol installed exactly"
cmp -s "$RULE" "$TARGET/.claude/rules/tdd-enforcement.md" \
  && ok "Claude receives thin entrypoint" || bad "Claude receives thin entrypoint"
cmp -s "$RULE" "$TARGET/.agents/rules/tdd-enforcement.md" \
  && ok "Antigravity receives identical thin entrypoint" || bad "Antigravity receives identical thin entrypoint"
expect_present "docs/agent-protocol.md" "$TARGET/AGENTS.md" "installed AGENTS.md keeps portable pointer"
[[ ! -d "$TARGET/.codex/rules" ]] \
  && ok "installer does not invent .codex/rules" || bad "installer does not invent .codex/rules"

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }

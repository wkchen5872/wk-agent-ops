#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/template/user/bulk-read-routing"
SKILL="$TEMPLATE/skill/SKILL.md"
CLAUDE_AGENT="$TEMPLATE/claude/bulk-reader-agent.md"
CODEX_AGENT="$TEMPLATE/codex/bulk-reader-agent.toml"
INSTALLER="$ROOT/scripts/user/install-bulk-read-routing.sh"
PLAYBOOK="$ROOT/docs/skills/bulk-read-routing.md"
fail=0

ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
require_text() {
  local file="$1" text="$2" label="$3"
  grep -Fq -- "$text" "$file" 2>/dev/null && ok "$label" || bad "$label"
}

for file in "$SKILL" "$CLAUDE_AGENT" "$CODEX_AGENT" "$INSTALLER"; do
  [[ -f "$file" ]] && ok "$(basename "$file") exists" || bad "$(basename "$file") exists"
done

for text in 'Claude Code' 'Codex' 'Parent tokens' 'Subagent tokens' 'Total tokens' \
  'Elapsed time' 'Correct evidence' 'Spawn count' 'Write attempts'; do
  require_text "$PLAYBOOK" "$text" "playbook records $text"
done

require_text "$SKILL" 'spawn exactly one custom subagent named `bulk-reader-agent`' "skill requires one named agent"
require_text "$SKILL" 'Do not use when targeted search has already located' "skill excludes located work"
require_text "$SKILL" 'Do not invoke this skill again during the same discovery phase.' "skill prevents repeated routing"
require_text "$SKILL" 'perform targeted discovery in the parent' "skill defines missing-agent fallback"
require_text "$SKILL" 'verify every quote or claim' "skill requires parent verification"

require_text "$CLAUDE_AGENT" 'name: bulk-reader-agent' "Claude agent name matches"
require_text "$CLAUDE_AGENT" 'model: haiku' "Claude agent model configured"
require_text "$CLAUDE_AGENT" 'tools: Read, Grep, Glob' "Claude agent has read-only tool allowlist"
grep -Eq '^tools:.*(Bash|Edit|Write)' "$CLAUDE_AGENT" 2>/dev/null \
  && bad "Claude agent excludes mutating tools" || ok "Claude agent excludes mutating tools"

require_text "$CODEX_AGENT" 'name = "bulk-reader-agent"' "Codex agent name matches"
require_text "$CODEX_AGENT" 'model = "gpt-5.6-luna"' "Codex agent model configured"
require_text "$CODEX_AGENT" 'model_reasoning_effort = "medium"' "Codex reasoning configured"
require_text "$CODEX_AGENT" 'sandbox_mode = "read-only"' "Codex agent sandbox is read-only"

for file in "$CLAUDE_AGENT" "$CODEX_AGENT"; do
  require_text "$file" 'at most 10 findings' "$(basename "$file") limits findings"
  require_text "$file" 'at most 3 lines' "$(basename "$file") limits quotes"
  require_text "$file" 'Do not infer or report a final root cause.' "$(basename "$file") leaves root cause to parent"
done

if [[ -f "$INSTALLER" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  CLAUDE_ROOT="$TMP/claude"
  CODEX_ROOT="$TMP/codex"
  mkdir -p "$CLAUDE_ROOT/agents" "$CODEX_ROOT/agents"
  printf 'keep\n' > "$CLAUDE_ROOT/agents/unrelated.md"
  printf 'keep\n' > "$CODEX_ROOT/agents/unrelated.toml"

  if bash "$INSTALLER" --claude-root "$CLAUDE_ROOT" --codex-root "$CODEX_ROOT" claude codex >/dev/null; then
    ok "both-provider install succeeds"
  else
    bad "both-provider install succeeds"
  fi
  bash "$INSTALLER" --claude-root "$CLAUDE_ROOT" --codex-root "$CODEX_ROOT" claude codex >/dev/null 2>&1 \
    && ok "installer is idempotent" || bad "installer is idempotent"

  cmp -s "$SKILL" "$CLAUDE_ROOT/skills/bulk-read-routing/SKILL.md" \
    && ok "Claude skill copied exactly" || bad "Claude skill copied exactly"
  cmp -s "$CLAUDE_AGENT" "$CLAUDE_ROOT/agents/bulk-reader-agent.md" \
    && ok "Claude agent copied exactly" || bad "Claude agent copied exactly"
  cmp -s "$SKILL" "$CODEX_ROOT/skills/bulk-read-routing/SKILL.md" \
    && ok "Codex skill copied exactly" || bad "Codex skill copied exactly"
  cmp -s "$CODEX_AGENT" "$CODEX_ROOT/agents/bulk-reader-agent.toml" \
    && ok "Codex agent copied exactly" || bad "Codex agent copied exactly"
  [[ "$(cat "$CLAUDE_ROOT/agents/unrelated.md")" == keep \
    && "$(cat "$CODEX_ROOT/agents/unrelated.toml")" == keep ]] \
    && ok "unrelated user files preserved" || bad "unrelated user files preserved"

  ONLY="$TMP/only"
  bash "$INSTALLER" --claude-root "$ONLY/claude" --codex-root "$ONLY/codex" claude >/dev/null 2>&1
  [[ -f "$ONLY/claude/agents/bulk-reader-agent.md" && ! -e "$ONLY/codex" ]] \
    && ok "Claude-only selection is isolated" || bad "Claude-only selection is isolated"

  if bash "$INSTALLER" --claude-root "$TMP/bad-claude" --codex-root "$TMP/bad-codex" unknown >/dev/null 2>&1; then
    bad "unknown provider rejected"
  else
    ok "unknown provider rejected"
  fi
fi

printf '\n'
[[ $fail -eq 0 ]] && { echo PASS; exit 0; } || { echo FAIL; exit 1; }

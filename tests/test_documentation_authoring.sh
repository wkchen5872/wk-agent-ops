#!/usr/bin/env bash
# Contract presence only; semantic and rendered checks are recorded separately.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT/template/common/docs/okf-conventions.md"
fail=0
require() {
  if grep -Fq "$2" "$1"; then
    printf 'PASS %s\n' "$3"
  else
    printf 'FAIL %s\n' "$3"
    fail=1
  fi
}
require "$POLICY" 'OKF v0.2' 'policy version'
require "$POLICY" 'generated' 'generation metadata'
require "$POLICY" 'sources' 'source attribution'
require "$POLICY" '## API 文件' 'API contract'
require "$POLICY" '## 操作文件' 'operation contract'
require "$POLICY" '## 設計與規格文件' 'design contract'
require "$POLICY" 'SVG' 'static deliverable'
require "$POLICY" 'HTML' 'interactive deliverable'
require "$POLICY" '漸進遷移' 'legacy migration'
require "$POLICY" 'work-items/AGENTS.md' 'Work Item policy reference'
require "$ROOT/template/common/work-items/AGENTS.md" 'diagrams/' 'Work Item diagram location'
require "$ROOT/template/common/work-items/AGENTS.md" '../docs/okf-conventions.md' 'Work Item shared visual policy'
if grep -Eq '圖檔.*Work Item|Work Item.*`diagrams/`' "$POLICY"; then
  printf 'FAIL Work Item storage rule belongs to its convention\n'
  fail=1
fi
require "$ROOT/template/common/docs/agent-protocol.md" 'nested module docs' 'nested documentation activation'
require "$ROOT/template/common/docs/agent-protocol.md" 'Work Item diagrams' 'standalone diagram activation'
for entry in \
  skills/doc-updater/SKILL.md \
  .claude/agents/doc-updater-agent.md \
  .codex/agents/doc-updater-agent.toml; do
  require "$ROOT/template/common/$entry" 'docs/okf-conventions.md' "$entry shared policy"
  require "$ROOT/template/common/$entry" 'diagrams' "$entry diagram discovery"
done
exit "$fail"

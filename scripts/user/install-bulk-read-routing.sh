#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$SOURCE_REPO/template/user/bulk-read-routing"
CLAUDE_ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
PROVIDERS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude-root)
      CLAUDE_ROOT="$2"; shift 2 ;;
    --codex-root)
      CODEX_ROOT="$2"; shift 2 ;;
    claude|codex)
      PROVIDERS+=("$1"); shift ;;
    *)
      echo "❌ Unknown option or provider: $1" >&2
      exit 1 ;;
  esac
done

[[ ${#PROVIDERS[@]} -gt 0 ]] || PROVIDERS=(claude codex)

install_provider() {
  local provider="$1" root="$2" agent_source agent_target
  case "$provider" in
    claude)
      agent_source="$TEMPLATE/claude/bulk-reader-agent.md"
      agent_target="$root/agents/bulk-reader-agent.md" ;;
    codex)
      agent_source="$TEMPLATE/codex/bulk-reader-agent.toml"
      agent_target="$root/agents/bulk-reader-agent.toml" ;;
  esac

  mkdir -p "$root/skills/bulk-read-routing" "$root/agents"
  cp "$TEMPLATE/skill/SKILL.md" "$root/skills/bulk-read-routing/SKILL.md"
  cp "$agent_source" "$agent_target"
  echo "✓ Installed bulk-read-routing for $provider in $root"
}

for provider in "${PROVIDERS[@]}"; do
  case "$provider" in
    claude) install_provider claude "$CLAUDE_ROOT" ;;
    codex) install_provider codex "$CODEX_ROOT" ;;
  esac
done

#!/usr/bin/env bash
# Install the agent handoff loop for the current user:
#   ~/.local/bin/handoff-start, handoff-finish, handoff-cleanup, handoff-role, handoff-doctor
#   ~/.config/wk-workflow/handoff/handoff-route, handoff-pi-trust (+ lib/)
#   ~/.pi/agent/extensions/wk-handoff.ts (the Pi trigger)
# and register handoff-route as a Stop hook for Claude Code and Codex. Idempotent.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SRC/../.." && pwd)"
BIN_DIR="$HOME/.local/bin"
HOME_DIR="$HOME/.config/wk-workflow/handoff"
HOOK_CMD="bash \"$HOME_DIR/handoff-route\""

command -v jq >/dev/null 2>&1 || { echo "❌ jq is required" >&2; exit 1; }
# shellcheck source=../workflow/lib.sh
source "$REPO/scripts/workflow/lib.sh"

mkdir -p "$BIN_DIR" "$HOME_DIR/lib"
install -m 0755 "$SRC/handoff-start" "$BIN_DIR/handoff-start"
install -m 0755 "$SRC/handoff-finish" "$BIN_DIR/handoff-finish"
install -m 0755 "$SRC/handoff-cleanup" "$BIN_DIR/handoff-cleanup"
install -m 0755 "$SRC/handoff-role" "$BIN_DIR/handoff-role"
install -m 0755 "$SRC/handoff-doctor" "$BIN_DIR/handoff-doctor"
install -m 0755 "$SRC/handoff-route" "$HOME_DIR/handoff-route"
install -m 0755 "$SRC/handoff-pi-trust" "$HOME_DIR/handoff-pi-trust"
install -m 0644 "$SRC/lib/handoff.sh" "$HOME_DIR/lib/handoff.sh"
install -m 0644 "$REPO/template/common/skills/agent-handoff/scripts/kv.sh" "$HOME_DIR/lib/kv.sh"
echo "  ✓ Installed handoff-start, handoff-finish, handoff-cleanup, handoff-role and handoff-doctor in $BIN_DIR"
echo "  ✓ Installed handoff-route in $HOME_DIR"
PI_EXT_DIR="$HOME/.pi/agent/extensions"
mkdir -p "$PI_EXT_DIR"
install -m 0644 "$SRC/pi/wk-handoff.ts" "$PI_EXT_DIR/wk-handoff.ts"
echo "  ✓ Installed the Pi trigger $PI_EXT_DIR/wk-handoff.ts"

# Codex profile for roles that must reach GitHub (finish with delivery: pr). Codex's default
# workspace-write sandbox has no network; this profile is used only when a role names it.
NET_PROFILE="$HOME/.codex/handoff-net.config.toml"
if [[ ! -e "$NET_PROFILE" ]]; then
  mkdir -p "$HOME/.codex"
  cat > "$NET_PROFILE" <<'TOML'
# Created by wk-agent-ops scripts/handoff/install.sh. Selected by "profile: handoff-net"
# in .agent-handoff/roles.yaml; plain Codex sessions do not use it.
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
TOML
  echo "  ✓ Created Codex profile $NET_PROFILE (workspace-write with network)"
fi

_register_settings_hook "$HOME/.claude/settings.json" "Stop" "" "$HOOK_CMD"
_register_settings_hook "$HOME/.codex/hooks.json" "Stop" "" "$HOOK_CMD" "Agent 交接派送"

cat <<'MSG'

Next steps:
  • Codex: open a new Codex session, find the Stop hook "Agent 交接派送" in /hooks, and
    trust and enable it again whenever it is new or its definition changed (for example, a
    name was added). This installer does not change Codex trust or enable state.
  • Hooks load when a session starts: sessions opened before this install do not route.
    Pi: run /reload (or restart) in Pi sessions opened before this install.
  • Pi roles: run /trust in Pi once in the repository's main worktree; handoff worktrees of a
    trusted repository are then trusted automatically, for that session only.
  • Each repository needs the wk-agent-ops project installer (scripts/skills/install.sh)
    for the agent-handoff skill, the /.agent-handoff/ ignore rule and roles.yaml.
MSG

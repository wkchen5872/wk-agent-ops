## Why

`scripts/` is growing: `telegram-notify/`, `notify/`, `line-notify/` sit alongside `worktree/` and `skills/`. As more notification channels are added (Line, Slack, etc.) the flat layout becomes hard to navigate. Consolidating all notify providers under `scripts/notify/` makes the hierarchy self-evident. Separately, GitHub Copilot CLI supports hooks but `registry.sh` only registers in Claude Code and Gemini CLI settings — multi-agent users running Copilot CLI get no notifications.

## What Changes

- **Directory consolidation**: Move `scripts/telegram-notify/` → `scripts/notify/telegram/` and `scripts/line-notify/` → `scripts/notify/line/`. The shared libraries (`scripts/notify/lib/`) stay in place. All internal paths in hook.sh, install.sh, update.sh, uninstall.sh updated accordingly.
- **Copilot CLI hook registration**: `registry.sh` gains `register_hook_copilot()` and `unregister_hook_copilot()` that write/update `.github/hooks/hooks.json` in the repo root. Hooks registered: `sessionEnd` (task complete) and `userPromptSubmitted` (action required).
- **hook.sh Copilot detection**: Detect Copilot CLI execution via `GITHUB_COPILOT_*` environment variable; set `TOOL_NAME="Copilot CLI"` and map `sessionEnd` → task-complete, `userPromptSubmitted` → action-required message format.
- **install.sh Copilot step**: After Claude/Gemini registration, prompt user whether to also register Copilot CLI hooks (writes `.github/hooks/hooks.json`).
- **update.sh `fix-hooks`**: Re-run all three registrations (Claude, Gemini, Copilot) from the fix-hooks command.
- **Docs updated**: `docs/notify-hooks-architecture.md` reflects new paths and Copilot CLI section.

## Capabilities

### New Capabilities

### Modified Capabilities
- `telegram-notify-hook`: `registry.sh` adds Copilot CLI hook registration (`register_hook_copilot` / `unregister_hook_copilot`); `hook.sh` adds Copilot CLI tool detection and event mapping; install paths change from `scripts/telegram-notify/` to `scripts/notify/telegram/`.

## Impact

- `scripts/notify/telegram/` (moved from `scripts/telegram-notify/`) — all 4 scripts updated for new paths
- `scripts/notify/line/` (moved from `scripts/line-notify/`) — .placeholder updated
- `scripts/notify/lib/registry.sh` — new Copilot functions + `.github/hooks/hooks.json` management
- `.github/hooks/hooks.json` — new file created by install.sh when Copilot opt-in
- `docs/notify-hooks-architecture.md` — new directory structure + Copilot section
- `docs/telegram-notify-hook.md` — updated install paths
- `.claude/commands/notify-setup.md` — script paths updated

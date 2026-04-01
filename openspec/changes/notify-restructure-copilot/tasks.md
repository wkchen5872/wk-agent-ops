## 1. Directory Restructure

- [ ] 1.1 `git mv scripts/telegram-notify scripts/notify/telegram`
- [ ] 1.2 `git mv scripts/line-notify scripts/notify/line`
- [ ] 1.3 Grep entire repo for references to `scripts/telegram-notify` and update all paths found (docs, .claude/commands, README, any other scripts)
- [ ] 1.4 Verify: `scripts/notify/telegram/hook.sh`, `install.sh`, `update.sh`, `uninstall.sh` all exist; `scripts/notify/line/.placeholder` exists; old top-level dirs are gone

## 2. registry.sh — Copilot CLI Functions

- [ ] 2.1 Add `register_hook_copilot <hook_path>` function: resolves `$REPO_ROOT` via `git rev-parse --show-toplevel`, creates `.github/hooks/` dir if needed, writes/merges into `.github/hooks/hooks.json` using jq (version:1, sessionEnd + userPromptSubmitted entries)
- [ ] 2.2 Add `unregister_hook_copilot <hook_path>` function: removes matching bash command entries from sessionEnd and userPromptSubmitted arrays in `.github/hooks/hooks.json`
- [ ] 2.3 Ensure both functions are idempotent (no duplicate entries on repeated calls)
- [ ] 2.4 Verify: run `register_hook_copilot` twice → `.github/hooks/hooks.json` has exactly 1 entry per event; run `unregister_hook_copilot` → entries removed, file structure intact

## 3. hook.sh — Copilot CLI Detection & Event Mapping

- [ ] 3.1 Add Copilot CLI detection: check `GITHUB_COPILOT_SESSION_ID`; set `TOOL_NAME="Copilot CLI"` and `PROJECT_DIR="$PWD"` when detected
- [ ] 3.2 Update tool detection order: Gemini → Copilot → Claude → "AI CLI"
- [ ] 3.3 Add event mapping: `sessionEnd` → task-complete path (same as `stop`); `userPromptSubmitted` → action-required path (same as `notification`)
- [ ] 3.4 **Note**: Verify `GITHUB_COPILOT_SESSION_ID` is the correct env var name by testing with actual Copilot CLI; adjust if different
- [ ] 3.5 Verify: simulate `GITHUB_COPILOT_SESSION_ID=test bash hook.sh sessionEnd` → task complete message sent; `bash hook.sh userPromptSubmitted` → action required message sent

## 4. install.sh — Copilot CLI Step

- [ ] 4.1 Add Step 8 (or after Gemini step): "Register Copilot CLI hooks? Writes `.github/hooks/hooks.json` in your repo. [y/N]"
- [ ] 4.2 If user answers y: call `register_hook_copilot` and print note that the file can/should be committed
- [ ] 4.3 If user answers N (default): skip silently
- [ ] 4.4 Verify: `bash scripts/notify/telegram/install.sh` → prompts for Copilot step; y creates `.github/hooks/hooks.json`; N skips

## 5. update.sh & uninstall.sh — Copilot Support

- [ ] 5.1 In `update.sh`: add `copilot-hooks` option to re-run `register_hook_copilot` (similar to `fix-hooks`)
- [ ] 5.2 In `update.sh` `fix-hooks` command: also call `register_hook_copilot` if `.github/hooks/hooks.json` exists (re-register)
- [ ] 5.3 In `uninstall.sh`: add prompt "Remove Copilot CLI hooks from .github/hooks/hooks.json? [y/N]"; if y call `unregister_hook_copilot`
- [ ] 5.4 Verify: `fix-hooks` re-registers all three CLIs; uninstall removes Copilot entries

## 6. Docs Update

- [ ] 6.1 Update `docs/telegram-notify-hook.md`: change install path references from `scripts/telegram-notify/` to `scripts/notify/telegram/`
- [ ] 6.2 Update `docs/notify-hooks-architecture.md` (or create if missing): document new directory tree, add Copilot CLI section explaining `.github/hooks/hooks.json` setup
- [ ] 6.3 Update `.claude/commands/notify-setup.md`: update script paths
- [ ] 6.4 Update `scripts/notify/README.md`: reflect new provider directory layout (`notify/telegram/`, `notify/line/`)

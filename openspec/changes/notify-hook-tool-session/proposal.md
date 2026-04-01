## Why

Copilot CLI 的 `GITHUB_COPILOT_SESSION_ID` env var 在 hook 執行時未必能被正確識別，導致工具偵測落回 `CLAUDE_PROJECT_DIR`，顯示錯誤的 TOOL_NAME。另外通知訊息目前缺少 session 資訊，無法區分同一專案的不同 session。

## What Changes

- **hook.sh CLI 介面變更**：呼叫指令從 `hook.sh <event>` 改為 `hook.sh <event> <tool_name>`，TOOL_NAME 由呼叫端（registry.sh）傳入，不再依賴 env var 偵測
- **registry.sh 更新**：`register_hook_copilot` 寫入的 bash 指令帶入 `"Copilot CLI"` 作為第二參數；Claude/Gemini 的 register_hook 同步更新指令格式（帶入對應 tool name）
- **hook.sh 輸出格式**：標題行加入 session 識別（session name 優先，fallback 到 session id 縮短版）
- **Session 資訊來源**：從 stdin JSON 中讀取（Claude: `session_id`；Copilot: `sessionId` 或由 `GITHUB_COPILOT_SESSION_ID` 取得）；Claude 另可從 `CLAUDE_PROJECT_DIR` 路徑推算 session name

## Capabilities

### New Capabilities

### Modified Capabilities

- `telegram-notify-hook`: hook.sh 增加 `<tool_name>` CLI 參數；輸出標題加入 session 識別；registry.sh 在所有工具的 hook 指令中帶入 tool name

## Impact

- `scripts/notify/telegram/hook.sh` — 新增 `$2` tool name 參數，更新訊息格式
- `scripts/notify/lib/registry.sh` — `register_hook`、`register_hook_copilot` 產生的 bash 指令加入 tool name 參數
- `~/.config/ai-notify/hooks/telegram-notify.sh` — 需重新部署（install.sh / update.sh fix-hooks）
- `.github/hooks/hooks.json` — 需重新執行 `register_hook_copilot` 更新指令
- `~/.claude/settings.json`、`~/.gemini/settings.json` — 需重新執行 `register_hook` 更新指令

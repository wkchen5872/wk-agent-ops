## Why

`hook.sh` 的工具偵測邏輯有兩個問題：(1) 使用 env var 順序錯誤導致 Gemini CLI 顯示為 Claude Code（因為 Gemini CLI 刻意同時注入兩個 var 做相容），(2) Telegram 通知排版不易閱讀且缺少 debug 資訊。需修正偵測邏輯並優化訊息格式。

## What Changes

- 修正 `scripts/telegram-notify/hook.sh` 工具偵測邏輯：`GEMINI_PROJECT_DIR` 存在 → Gemini CLI，否則 `CLAUDE_PROJECT_DIR` 存在 → Claude Code
- 修正 `PROJECT_DIR` 優先順序：`GEMINI_PROJECT_DIR` 優先，fallback `CLAUDE_PROJECT_DIR`
- 在 Telegram 通知訊息中加入 `hook_event_name`（debug 用）
- 優化 Telegram 訊息排版（標題、間距、emoji 配置）
- 更新已部署的 `~/.config/ai-notify/hooks/telegram-notify.sh`

## Capabilities

### New Capabilities

（無新 capability）

### Modified Capabilities

- `telegram-notify-hook`：工具偵測邏輯改為 `GEMINI_PROJECT_DIR` 優先判斷；訊息格式加入 `hook_event_name`；排版優化

## Impact

- **修改檔案**：`scripts/telegram-notify/hook.sh`
- **需部署**：更新後的 hook.sh 需複製到 `~/.config/ai-notify/hooks/telegram-notify.sh`
- **不影響**：`registry.sh`、`install.sh`、`update.sh`、`uninstall.sh`、settings.json

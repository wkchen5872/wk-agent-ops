## Why

現有的 Telegram 通知訊息排版風格不一致，emoji 與欄位配置需要統一。新格式以顏色信號（🟢/🔴）作為狀態圖示，並將 agent name、project、時間各佔一行，訊息與 hook event 合併在最後一行，視覺層次更清晰。

## What Changes

- 調整 Stop/AfterAgent 通知標題為 `🟢 **TASK COMPLETE**`
- 調整 Notification 通知標題為 `🔴 **Action Required**`
- 工具名稱改用 🤖 圖示，獨立一行
- 專案名稱改用 📂 圖示，獨立一行
- 時間戳記改用 ⏰ 圖示，獨立一行
- 訊息與 hook event name（`#EventName`）合併在最後一行
- Task Complete 的固定訊息改為 `Process finished successfully`
- Action Required 無 message 時，改用固定文案 `Waiting for user interaction...`

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `telegram-notify-hook`: 訊息格式（emoji、欄位排列、訊息文案）變更

## Impact

- `scripts/telegram-notify/hook.sh` — 訊息組裝邏輯
- `~/.config/ai-notify/hooks/telegram-notify.sh` — 需部署更新版本

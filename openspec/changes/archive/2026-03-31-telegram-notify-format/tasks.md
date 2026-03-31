## 1. 更新 hook.sh 訊息組裝邏輯

- [x] 1.1 TASK COMPLETE 標題改為 `🟢 **TASK COMPLETE**`
- [x] 1.2 Action Required 標題改為 `🔴 **Action Required**`
- [x] 1.3 工具欄位改為 `🤖 {TOOL_NAME}`（獨立一行）
- [x] 1.4 專案欄位改為 `📂 {PROJECT_NAME}`（獨立一行）
- [x] 1.5 時間欄位改為 `⏰ {TIMESTAMP}`（獨立一行）
- [x] 1.6 訊息行改為 `{MESSAGE} #{HOOK_EVENT_NAME}`（合併在最後一行，空行前）
- [x] 1.7 TASK COMPLETE 固定訊息改為 `Process finished successfully`
- [x] 1.8 Action Required 無 message 時，fallback 改為 `Waiting for user interaction...`

## 2. 部署與驗證

- [x] 2.1 部署至 `~/.config/ai-notify/hooks/telegram-notify.sh`
- [x] 2.2 測試 Stop event（應顯示 🟢 TASK COMPLETE 格式）
- [x] 2.3 測試 Notification event（應顯示 🔴 Action Required 格式，含 #Notification tag）

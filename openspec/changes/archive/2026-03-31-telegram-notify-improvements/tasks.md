## 1. 修正工具偵測邏輯

- [x] 1.1 移除以 hook_event_name 判斷 TOOL_NAME 的邏輯（AfterAgent → Gemini CLI、Stop → Claude Code）
- [x] 1.2 改以 GEMINI_PROJECT_DIR 存在與否作為首要判斷：有 → Gemini CLI
- [x] 1.3 改以 CLAUDE_PROJECT_DIR 作為次要判斷：有 → Claude Code
- [x] 1.4 兩者皆無時設定 TOOL_NAME="AI CLI"（bug indicator）
- [x] 1.5 PROJECT_DIR 優先取 GEMINI_PROJECT_DIR，fallback CLAUDE_PROJECT_DIR

## 2. 新增 hook event name 至 Telegram 訊息

- [x] 2.1 從 stdin JSON 解析 hook_event_name（jq 優先，grep fallback）
- [x] 2.2 在每則通知底部加入 `🔍 Event: <hook_event_name>` 欄位

## 3. 訊息排版優化

- [x] 3.1 Task Complete 格式：標題 → 空行 → `🔧 Tool · Project` 單行 → 時間 → 空行 → Event
- [x] 3.2 Action Required 格式：標題 → 空行 → `🔧 Tool · Project` 單行 → 💬 訊息 → 時間 → 空行 → Event
- [x] 3.3 標題使用 Markdown bold（`*Task Complete*`）

## 4. 部署

- [x] 4.1 複製更新後的 hook.sh 至 `~/.config/ai-notify/hooks/telegram-notify.sh`
- [x] 4.2 手動測試 Stop/AfterAgent event（應顯示正確 TOOL_NAME 與 Event 欄位）
- [x] 4.3 手動測試 Notification event（應顯示 message 及 Event 欄位）

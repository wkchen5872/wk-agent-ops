## ADDED Requirements

### Requirement: Notification script supports Claude Code Stop events
腳本 `~/.claude/hooks/telegram-notify.sh` 在 `$1=stop` 且 `TELEGRAM_NOTIFY_LEVEL=all`（或未設定）時 SHALL 透過 Telegram Bot API 傳送「Task Complete」通知。

#### Scenario: Stop event with level=all
- **WHEN** 腳本以 `$1=stop` 呼叫，stdin JSON `hook_event_name` 為 `Stop`，`TELEGRAM_NOTIFY_LEVEL` 為 `all` 或未設定
- **THEN** 傳送包含 icon ✅、標題 "Task Complete"、工具名稱、專案名稱、時間戳記的 Telegram 訊息

#### Scenario: Stop event suppressed in notify_only mode
- **WHEN** 腳本以 `$1=stop` 呼叫，`TELEGRAM_NOTIFY_LEVEL=notify_only`
- **THEN** 腳本立即退出（exit 0），不發送任何通知

---

### Requirement: Notification script supports Notification events
腳本在 `hook_event_name=Notification`（或 `$1=notification`）時 SHALL 傳送「Action Required」通知，包含 stdin 中的 `message` 欄位內容。

#### Scenario: Notification event triggers alert
- **WHEN** 腳本以 `$1=notification` 呼叫，stdin JSON 含 `message` 欄位
- **THEN** 傳送包含 icon ⚠️、標題 "Action Required"、`message` 欄位內容的 Telegram 訊息

#### Scenario: Notification event fires in both notify levels
- **WHEN** `TELEGRAM_NOTIFY_LEVEL` 為任意值（`all` 或 `notify_only`）
- **THEN** Notification 事件均正常傳送，不被抑制

---

### Requirement: Graceful no-op when credentials absent
腳本 SHALL 在 `TELEGRAM_BOT_TOKEN` 或 `TELEGRAM_CHAT_ID` 任一未設定時，靜默退出（exit 0），不輸出任何錯誤。

#### Scenario: Missing token
- **WHEN** `TELEGRAM_BOT_TOKEN` 為空字串或未設定
- **THEN** 腳本立即退出，無輸出，退出碼 0

#### Scenario: Missing chat ID
- **WHEN** `TELEGRAM_CHAT_ID` 為空字串或未設定
- **THEN** 腳本立即退出，無輸出，退出碼 0

---

### Requirement: Graceful failure on network error
腳本 SHALL 在 curl 請求失敗（網路錯誤、Telegram API 錯誤）時仍退出碼 0，不影響 AI CLI 正常運作。

#### Scenario: Network timeout
- **WHEN** curl 超過 10 秒 max-time
- **THEN** curl 被中止，腳本退出碼 0，AI CLI 繼續正常執行

---

### Requirement: Project name extracted from environment
腳本 SHALL 優先從 `CLAUDE_PROJECT_DIR`（Claude Code）取得專案目錄，其次從 `GEMINI_PROJECT_DIR`，最後從 stdin JSON 的 `cwd` 欄位。專案名稱為目錄的 basename。

#### Scenario: Claude Code environment
- **WHEN** `CLAUDE_PROJECT_DIR=/Users/me/my-project` 環境變數存在
- **THEN** Telegram 訊息顯示工具名稱 "Claude Code"，專案名稱 "my-project"

#### Scenario: Gemini CLI environment
- **WHEN** `GEMINI_PROJECT_DIR=/Users/me/another-project` 環境變數存在（且 `CLAUDE_PROJECT_DIR` 不存在）
- **THEN** Telegram 訊息顯示工具名稱 "Gemini CLI"，專案名稱 "another-project"

---

### Requirement: Claude Code global hooks configured
`~/.claude/settings.json` 的 `hooks` 區塊 SHALL 包含 `Stop` 與 `Notification` 兩個事件，均使用 `async: true` 非同步呼叫通知腳本。

#### Scenario: Stop hook fires asynchronously
- **WHEN** Claude Code 完成一個 response
- **THEN** hook 以 `async: true` 在背景執行，不阻塞 Claude Code 回應

#### Scenario: Hooks apply to all projects globally
- **WHEN** Claude Code 在任意專案目錄啟動
- **THEN** 全域 `~/.claude/settings.json` 的 hooks 自動生效，無需專案級設定

---

### Requirement: Gemini CLI global hooks configured
`~/.gemini/settings.json` 的 `hooks` 區塊 SHALL 包含 `AfterAgent` 與 `Notification` 兩個事件，呼叫同一通知腳本。

#### Scenario: AfterAgent hook fires on response completion
- **WHEN** Gemini CLI 完成一個 agent 回應
- **THEN** `AfterAgent` hook 執行通知腳本

---

### Requirement: docs/telegram-notify-hook.md 安裝說明
`docs/telegram-notify-hook.md` SHALL 包含完整安裝步驟：Telegram Bot 建立、環境變數設定、腳本安裝、settings.json 修改方式、手動測試指令，以及 `TELEGRAM_NOTIFY_LEVEL` 切換說明。

#### Scenario: User can follow docs to complete setup
- **WHEN** 使用者閱讀 `docs/telegram-notify-hook.md`
- **THEN** 能夠按步驟完成從 0 到收到第一則 Telegram 通知的完整設定

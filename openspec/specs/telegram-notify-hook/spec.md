# Spec: telegram-notify-hook

## Purpose

提供 AI CLI（Claude Code、Gemini CLI 等）的 Telegram 通知 hook 整合，讓 AI 任務完成或需要使用者操作時自動發送 Telegram 訊息。

## Requirements

### Requirement: 共用基礎庫 — config.sh
`scripts/notify/lib/config.sh` SHALL 提供讀寫 `~/.config/ai-notify/config` 的 shell 函式，格式為 shell-sourceable key=value，支援 read_config、write_config、update_config_key。

#### Scenario: 首次安裝寫入 config
- **WHEN** install.sh 呼叫 write_config 並傳入 TELEGRAM_BOT_TOKEN、TELEGRAM_CHAT_ID、NOTIFY_LEVEL
- **THEN** `~/.config/ai-notify/config` 被建立，chmod 600，包含正確的 key=value 條目

#### Scenario: 更新單一 config key
- **WHEN** update.sh 呼叫 update_config_key NOTIFY_LEVEL notify_only
- **THEN** config 檔案中的 NOTIFY_LEVEL 被更新，其他 key 不受影響

---

### Requirement: 共用基礎庫 — registry.sh (idempotent hook 註冊)
`scripts/notify/lib/registry.sh` 的 `register_hook()` SHALL 以 jq 安全地將 hook 條目加入 `~/.claude/settings.json` 與 `~/.gemini/settings.json`，並確保重複執行不產生重複條目（idempotent）。

#### Scenario: 首次註冊 hook
- **WHEN** register_hook 被呼叫，settings.json 尚無此 hook
- **THEN** Stop 與 Notification 事件的 hook 條目被加入，JSON 結構合法

#### Scenario: 重複註冊
- **WHEN** register_hook 被呼叫兩次（install.sh 重複執行）
- **THEN** settings.json 中的 hook 條目不重複，數量與第一次相同

#### Scenario: unregister_hook 清除
- **WHEN** unregister_hook 被呼叫
- **THEN** 對應的 hook 條目從 settings.json 移除，其他 hook 條目不受影響

---

### Requirement: install.sh 互動式安裝精靈
`scripts/telegram-notify/install.sh` SHALL 引導使用者完成從零到收到第一則 Telegram 通知的完整流程，包含 token 驗證、Chat ID 自動偵測、config 寫入、hook 部署、settings.json 更新。

#### Scenario: 成功完整安裝
- **WHEN** 使用者執行 `bash scripts/telegram-notify/install.sh` 並輸入有效的 Bot Token
- **THEN** `~/.config/ai-notify/config` 建立（含 TELEGRAM_ENABLED=true、token、chat_id、NOTIFY_LEVEL）；`~/.config/ai-notify/hooks/telegram-notify.sh` 存在且可執行；`~/.claude/settings.json` 包含 Stop + Notification hooks

#### Scenario: 重複執行 install（幂等）
- **WHEN** install.sh 在已安裝的環境執行第二次
- **THEN** 流程成功完成，settings.json 無重複 hook，config 不重複寫入

#### Scenario: Bot Token 無效
- **WHEN** 使用者輸入無效的 Bot Token
- **THEN** install.sh 顯示錯誤說明，要求重新輸入，不繼續後續步驟

---

### Requirement: hook.sh — 通知腳本
`~/.config/ai-notify/hooks/telegram-notify.sh`（從 `scripts/telegram-notify/hook.sh` 複製）SHALL source `~/.config/ai-notify/config`，依 TELEGRAM_ENABLED 與 NOTIFY_LEVEL 決定是否傳送 Telegram 通知。

### Requirement: 工具偵測以環境變數為準
腳本 SHALL 以 `GEMINI_PROJECT_DIR` 作為首要工具識別信號：有此 var → Gemini CLI；無此 var 但有 `CLAUDE_PROJECT_DIR` → Claude Code；兩者皆無 → "AI CLI"（bug indicator）。`PROJECT_DIR` 優先取 `GEMINI_PROJECT_DIR`，fallback `CLAUDE_PROJECT_DIR`。

#### Scenario: Gemini CLI environment（GEMINI_PROJECT_DIR 存在）
- **WHEN** `GEMINI_PROJECT_DIR=/Users/me/my-project` 存在（無論 `CLAUDE_PROJECT_DIR` 是否也存在）
- **THEN** TOOL_NAME="Gemini CLI"，PROJECT_DIR 取 `GEMINI_PROJECT_DIR` 值

#### Scenario: Claude Code environment（僅 CLAUDE_PROJECT_DIR）
- **WHEN** `CLAUDE_PROJECT_DIR=/Users/me/my-project` 存在，且 `GEMINI_PROJECT_DIR` 不存在
- **THEN** TOOL_NAME="Claude Code"，PROJECT_DIR 取 `CLAUDE_PROJECT_DIR` 值

#### Scenario: 兩者皆無
- **WHEN** `GEMINI_PROJECT_DIR` 和 `CLAUDE_PROJECT_DIR` 均未設定
- **THEN** TOOL_NAME="AI CLI"，PROJECT_DIR 為空字串

### Requirement: 訊息排版
通知訊息 SHALL 使用以下結構，兩種通知類型共用相同的欄位順序：

```
{STATUS_ICON} **{TITLE}**

🤖 {TOOL_NAME}
📂 {PROJECT_NAME}
⏰ {TIMESTAMP}

{MESSAGE} #{HOOK_EVENT_NAME}
```

- TASK COMPLETE：STATUS_ICON = 🟢，TITLE = `TASK COMPLETE`
- Action Required：STATUS_ICON = 🔴，TITLE = `Action Required`
- `{MESSAGE}` fallback：TASK COMPLETE → `Process finished successfully`；Action Required → `Waiting for user interaction...`
- `#{HOOK_EVENT_NAME}` 附加於訊息行末，例如 `#Stop`、`#AfterAgent`、`#Notification`

#### Scenario: TASK COMPLETE 訊息格式
- **WHEN** Stop 或 AfterAgent event 觸發，PROJECT_NAME=wk-agent-ops，TOOL_NAME=Claude Code
- **THEN** 訊息為：
  ```
  🟢 **TASK COMPLETE**

  🤖 Claude Code
  📂 wk-agent-ops
  ⏰ 2026-03-31 16:36:23

  Process finished successfully #Stop
  ```

#### Scenario: Action Required 訊息格式（含 message）
- **WHEN** Notification event 觸發，stdin JSON 含 `message` 欄位
- **THEN** 訊息為：
  ```
  🔴 **Action Required**

  🤖 Claude Code
  📂 wk-agent-ops
  ⏰ 2026-03-31 16:36:03

  Claude needs your permission to use Bash #Notification
  ```

#### Scenario: Action Required 訊息格式（無 message）
- **WHEN** Notification event 觸發，stdin JSON 無 `message` 欄位（或為空）
- **THEN** 訊息為：
  ```
  🔴 **Action Required**

  🤖 Claude Code
  📂 wk-agent-ops
  ⏰ 2026-03-31 16:36:03

  Waiting for user interaction... #Notification
  ```

#### Scenario: Gemini CLI AfterAgent event
- **WHEN** AfterAgent event 觸發，GEMINI_PROJECT_DIR 存在
- **THEN** 訊息格式與 TASK COMPLETE 相同，TOOL_NAME=Gemini CLI，#tag 為 `#AfterAgent`

#### Scenario: Stop event（NOTIFY_LEVEL=all）
- **WHEN** 腳本以 `$1=stop` 呼叫，NOTIFY_LEVEL=all（或未設定），TELEGRAM_ENABLED=true
- **THEN** 傳送含 🟢 圖示、"TASK COMPLETE"、工具名稱、專案名稱、時間戳記、#EventTag 的 Telegram 訊息

#### Scenario: Stop event 被抑制（NOTIFY_LEVEL=notify_only）
- **WHEN** 腳本以 `$1=stop` 呼叫，NOTIFY_LEVEL=notify_only
- **THEN** 腳本立即退出（exit 0），不傳送

#### Scenario: Notification event（任意 NOTIFY_LEVEL）
- **WHEN** 腳本以 `$1=notification` 呼叫，stdin JSON 含 message 欄位
- **THEN** 傳送含 🔴 圖示、"Action Required"、message 欄位內容（或 fallback）、#Notification tag 的 Telegram 訊息

#### Scenario: credentials 缺失
- **WHEN** TELEGRAM_BOT_TOKEN 或 TELEGRAM_CHAT_ID 未設定（config 檔不存在或 key 為空）
- **THEN** 腳本靜默退出（exit 0），無輸出

#### Scenario: 網路失敗
- **WHEN** curl 請求超過 10 秒或失敗
- **THEN** 腳本退出碼 0，AI CLI 不受影響

---

### Requirement: /notify-setup Claude Code 指令
`.claude/commands/notify-setup.md` SHALL 定義 `/notify-setup` 指令，使使用者能在 Claude Code 內完成 Telegram 通知的設定、更新、測試與移除。

#### Scenario: 無參數呼叫
- **WHEN** 使用者輸入 `/notify-setup`（無額外參數）
- **THEN** Claude 呈現選單：setup / update / test / status / uninstall，並根據選擇執行對應腳本

#### Scenario: 顯示目前設定（status）
- **WHEN** 使用者選擇 status
- **THEN** Claude 讀取 `~/.config/ai-notify/config`，顯示 NOTIFY_LEVEL、TELEGRAM_ENABLED，Bot Token 僅顯示末 4 碼

---

### Requirement: Line Notify 架構佔位
`scripts/line-notify/` 目錄 SHALL 存在，包含 `.placeholder` 檔案，說明實作時應參考 `scripts/notify/README.md` 的 Provider 擴充指南。

---

### Requirement: 說明文件
`docs/notify-hooks-architecture.md` SHALL 說明整體架構（目錄結構、config 格式、hook 生命週期、如何新增 provider）。
`docs/telegram-notify-hook.md` SHALL 提供 Telegram 快速安裝說明（含 `/notify-setup` 指令用法與手動方式）。

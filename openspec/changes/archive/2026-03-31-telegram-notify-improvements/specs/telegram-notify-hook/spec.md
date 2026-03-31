## MODIFIED Requirements

### Requirement: Project name extracted from environment
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

---

### Requirement: Telegram 訊息包含 hook event name
Telegram 通知訊息 SHALL 在底部顯示 `🔍 Event: <hook_event_name>`，供使用者確認觸發事件類型。

#### Scenario: Stop event 通知含 event name
- **WHEN** hook 以 `hook_event_name=Stop` 觸發
- **THEN** 訊息底部包含 `🔍 Event: Stop`

#### Scenario: AfterAgent event 通知含 event name
- **WHEN** hook 以 `hook_event_name=AfterAgent` 觸發
- **THEN** 訊息底部包含 `🔍 Event: AfterAgent`

#### Scenario: Notification event 通知含 event name
- **WHEN** hook 以 `hook_event_name=Notification` 觸發
- **THEN** 訊息底部包含 `🔍 Event: Notification`

---

### Requirement: Telegram 訊息排版優化
訊息格式 SHALL 具備清晰的視覺層次：標題（emoji + bold）、內容欄位（Tool、Project）、可選欄位（Message）、debug 欄位（Event）依序排列，欄位間使用空行分隔以提升可讀性。

#### Scenario: Task Complete 訊息格式
- **WHEN** Stop 或 AfterAgent event 觸發
- **THEN** 訊息格式為：
  ```
  ✅ *Task Complete*

  🔧 Claude Code  ·  wk-agent-ops
  🕐 2026-03-31 16:07:49

  🔍 Event: Stop
  ```

#### Scenario: Action Required 訊息格式
- **WHEN** Notification event 觸發，含 message 欄位
- **THEN** 訊息格式為：
  ```
  ⚠️ *Action Required*

  🔧 Claude Code  ·  wk-agent-ops
  💬 Claude needs your permission to use Bash
  🕐 2026-03-31 16:07:13

  🔍 Event: Notification
  ```

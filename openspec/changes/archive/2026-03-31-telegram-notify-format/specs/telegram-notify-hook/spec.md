## MODIFIED Requirements

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

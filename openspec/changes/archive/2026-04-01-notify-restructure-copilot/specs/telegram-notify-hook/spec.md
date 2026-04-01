## MODIFIED Requirements

### Requirement: 共用基礎庫 — registry.sh (idempotent hook 註冊)
`scripts/notify/lib/registry.sh` 的 `register_hook()` SHALL 以 jq 安全地將 hook 條目加入 `~/.claude/settings.json` 與 `~/.gemini/settings.json`，並確保重複執行不產生重複條目（idempotent）。新增 `register_hook_copilot()` SHALL 將 hook 條目寫入當前 repo 的 `.github/hooks/hooks.json`（Copilot CLI 格式，version:1），`unregister_hook_copilot()` SHALL 移除對應條目。

#### Scenario: 首次註冊 hook（Claude/Gemini）
- **WHEN** register_hook 被呼叫，settings.json 尚無此 hook
- **THEN** Stop 與 Notification 事件的 hook 條目被加入，JSON 結構合法

#### Scenario: 重複註冊（Claude/Gemini）
- **WHEN** register_hook 被呼叫兩次（install.sh 重複執行）
- **THEN** settings.json 中的 hook 條目不重複，數量與第一次相同

#### Scenario: unregister_hook 清除（Claude/Gemini）
- **WHEN** unregister_hook 被呼叫
- **THEN** 對應的 hook 條目從 settings.json 移除，其他 hook 條目不受影響

#### Scenario: 首次註冊 Copilot CLI hook
- **WHEN** `register_hook_copilot <hook_path>` 被呼叫，`.github/hooks/hooks.json` 不存在
- **THEN** `.github/hooks/hooks.json` 被建立，包含 `version:1`，`sessionEnd` 與 `userPromptSubmitted` 各含一條 bash 命令條目

#### Scenario: 重複註冊 Copilot CLI hook（idempotent）
- **WHEN** `register_hook_copilot` 被呼叫兩次
- **THEN** `.github/hooks/hooks.json` 中的條目不重複

#### Scenario: unregister_hook_copilot 清除
- **WHEN** `unregister_hook_copilot <hook_path>` 被呼叫
- **THEN** 對應 bash 命令從 `sessionEnd` 與 `userPromptSubmitted` 陣列移除，其他條目不受影響

---

### Requirement: install.sh 互動式安裝精靈
`scripts/notify/telegram/install.sh`（原 `scripts/telegram-notify/install.sh`）SHALL 引導使用者完成從零到收到第一則 Telegram 通知的完整流程，包含 token 驗證、Chat ID 自動偵測、config 寫入、hook 部署、settings.json 更新，並新增選擇性的 Copilot CLI hook 註冊步驟。

#### Scenario: 成功完整安裝
- **WHEN** 使用者執行 `bash scripts/notify/telegram/install.sh` 並輸入有效的 Bot Token
- **THEN** `~/.config/ai-notify/config` 建立（含 TELEGRAM_ENABLED=true、token、chat_id、NOTIFY_LEVEL）；`~/.config/ai-notify/hooks/telegram-notify.sh` 存在且可執行；`~/.claude/settings.json` 包含 Stop + Notification hooks

#### Scenario: 重複執行 install（幂等）
- **WHEN** install.sh 在已安裝的環境執行第二次
- **THEN** 流程成功完成，settings.json 無重複 hook，config 不重複寫入

#### Scenario: Bot Token 無效
- **WHEN** 使用者輸入無效的 Bot Token
- **THEN** install.sh 顯示錯誤說明，要求重新輸入，不繼續後續步驟

#### Scenario: 選擇註冊 Copilot CLI hook
- **WHEN** install.sh 完成 Claude/Gemini 步驟，詢問是否註冊 Copilot CLI hooks，使用者回答 y
- **THEN** `.github/hooks/hooks.json` 被建立或更新，包含 sessionEnd 與 userPromptSubmitted 條目；install.sh 顯示說明提示此檔案可被 git commit

#### Scenario: 跳過 Copilot CLI hook 註冊
- **WHEN** 使用者在 Copilot 詢問步驟回答 N（預設）
- **THEN** `.github/hooks/hooks.json` 不被建立或修改

---

### Requirement: hook.sh — 通知腳本
`~/.config/ai-notify/hooks/telegram-notify.sh`（從 `scripts/notify/telegram/hook.sh` 複製）SHALL source `~/.config/ai-notify/config`，依 TELEGRAM_ENABLED 與 NOTIFY_LEVEL 決定是否傳送 Telegram 通知。

### Requirement: 工具偵測以環境變數為準
腳本 SHALL 以環境變數偵測執行工具：`GEMINI_PROJECT_DIR` 存在 → Gemini CLI；`GITHUB_COPILOT_SESSION_ID` 存在 → Copilot CLI；`CLAUDE_PROJECT_DIR` 存在 → Claude Code；三者皆無 → "AI CLI"。`PROJECT_DIR` 取對應的 project dir 變數（Copilot 無 project dir 環境變數，取 `PWD`）。

#### Scenario: Gemini CLI environment（GEMINI_PROJECT_DIR 存在）
- **WHEN** `GEMINI_PROJECT_DIR=/Users/me/my-project` 存在
- **THEN** TOOL_NAME="Gemini CLI"，PROJECT_DIR 取 `GEMINI_PROJECT_DIR` 值

#### Scenario: Claude Code environment（僅 CLAUDE_PROJECT_DIR）
- **WHEN** `CLAUDE_PROJECT_DIR=/Users/me/my-project` 存在，且 `GEMINI_PROJECT_DIR` 不存在
- **THEN** TOOL_NAME="Claude Code"，PROJECT_DIR 取 `CLAUDE_PROJECT_DIR` 值

#### Scenario: Copilot CLI environment
- **WHEN** `GITHUB_COPILOT_SESSION_ID` 存在，`GEMINI_PROJECT_DIR` 不存在
- **THEN** TOOL_NAME="Copilot CLI"，PROJECT_DIR 取 `PWD` 值

#### Scenario: 兩者皆無
- **WHEN** 所有工具環境變數均未設定
- **THEN** TOOL_NAME="AI CLI"，PROJECT_DIR 為空字串

### Requirement: Copilot CLI 事件映射
hook.sh SHALL 將 Copilot CLI 的 hook 事件名稱映射到既有的通知類型：`sessionEnd` → task complete（與 Stop 相同處理）；`userPromptSubmitted` → action required（與 Notification 相同處理）。

#### Scenario: Copilot sessionEnd 事件
- **WHEN** hook.sh 以 `$1=sessionEnd` 呼叫，TOOL_NAME=Copilot CLI，NOTIFY_LEVEL=all
- **THEN** 傳送含 🟢、"Task Complete"、"Copilot CLI"、PROJECT_NAME、`#sessionEnd` tag 的 Telegram 訊息

#### Scenario: Copilot userPromptSubmitted 事件
- **WHEN** hook.sh 以 `$1=userPromptSubmitted` 呼叫，TOOL_NAME=Copilot CLI
- **THEN** 傳送含 🟠、"Action Required"、"Copilot CLI"、`#userPromptSubmitted` tag 的 Telegram 訊息

#### Scenario: sessionEnd 被抑制（NOTIFY_LEVEL=notify_only）
- **WHEN** hook.sh 以 `$1=sessionEnd` 呼叫，NOTIFY_LEVEL=notify_only
- **THEN** 腳本立即退出（exit 0），不傳送

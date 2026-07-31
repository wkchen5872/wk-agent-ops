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

### Requirement: registry.sh 在 hook 指令中帶入 tool name
`register_hook()` 產生的 Claude/Gemini bash 指令 SHALL 包含對應 tool name 作為第二參數。`register_hook_copilot()` 產生的 bash 指令 SHALL 包含 `"Copilot CLI"` 作為第二參數。

#### Scenario: register_hook 產生帶 tool name 的指令（Claude）
- **WHEN** `register_hook` 以 Claude hook path 呼叫
- **THEN** `~/.claude/settings.json` 中的指令包含 `"Claude Code"` 作為第二參數，格式為 `bash "..." stop "Claude Code"`

#### Scenario: register_hook_copilot 產生帶 tool name 的指令
- **WHEN** `register_hook_copilot` 被呼叫
- **THEN** `.github/hooks/hooks.json` 中的 sessionEnd bash 指令包含 `"Copilot CLI"` 作為第二參數

#### Scenario: 重複呼叫 idempotent（含 tool name）
- **WHEN** `register_hook_copilot` 被呼叫兩次
- **THEN** `.github/hooks/hooks.json` 中 sessionEnd 只有一條指令，不重複

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

#### Scenario: 啟用所有通知時傳送 Telegram 訊息
- **WHEN** hook.sh 讀取的 config 包含 `TELEGRAM_ENABLED=true` 與 `NOTIFY_LEVEL=all`，並收到支援的完成事件
- **THEN** hook.sh 傳送 Telegram 通知

### Requirement: 工具偵測以 CLI 參數為主、環境變數為輔
hook.sh SHALL 優先以 `$2` 參數取得 TOOL_NAME；`$2` 為空時才 fallback 到環境變數偵測（`GEMINI_PROJECT_DIR` → `GITHUB_COPILOT_SESSION_ID` / event name → `CLAUDE_PROJECT_DIR` → "AI CLI"）。`PROJECT_DIR` 取對應的 project dir 變數（Copilot 無 project dir 環境變數，取 `PWD`）。

#### Scenario: $2 參數帶入 tool name
- **WHEN** hook.sh 以 `bash hook.sh sessionEnd "Copilot CLI"` 呼叫
- **THEN** TOOL_NAME="Copilot CLI"，不進行 env var 偵測

#### Scenario: $2 為空，fallback 到 env var（Gemini）
- **WHEN** hook.sh 以 `bash hook.sh AfterAgent` 呼叫（無 $2），`GEMINI_PROJECT_DIR` 存在
- **THEN** TOOL_NAME="Gemini CLI"

#### Scenario: $2 為空，fallback 到 event name（Copilot）
- **WHEN** hook.sh 以 `bash hook.sh sessionEnd` 呼叫（無 $2），env var 皆未設定
- **THEN** TOOL_NAME="Copilot CLI"（由 event name `sessionend` 判定）

#### Scenario: $2 為空，fallback 到 Claude
- **WHEN** hook.sh 以 `bash hook.sh stop` 呼叫（無 $2），`CLAUDE_PROJECT_DIR` 存在
- **THEN** TOOL_NAME="Claude Code"

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

### Requirement: hook.sh 通知標題帶入 session 識別
hook.sh SHALL 在 Task Complete 與 Action Required 的標題行帶入 session 識別。Session 識別來源依序為：stdin JSON `.session_id`、stdin JSON `.sessionId`、env var `GITHUB_COPILOT_SESSION_ID` 前 8 字元。若為 UUID 格式（含 `-`），顯示前 8 字元加 `#` 前綴；否則直接顯示。無 session 資訊時標題不附加括號。

#### Scenario: Claude session_id 顯示
- **WHEN** stdin JSON 包含 `"session_id": "abc123def456"`, TOOL_NAME=Claude Code, EVENT_TYPE=stop
- **THEN** 標題行為 `🟢 **Task Complete** (#abc123de)`

#### Scenario: Copilot sessionId 顯示
- **WHEN** stdin JSON 包含 `"sessionId": "copilot-xyz"`, TOOL_NAME=Copilot CLI
- **THEN** 標題行為 `🟢 **Task Complete** (copilot-xyz)`（非 UUID 格式，直接顯示）

#### Scenario: 無 session 資訊
- **WHEN** stdin JSON 無 session 欄位，env var 亦無
- **THEN** 標題行為 `🟢 **Task Complete**`（無括號）

#### Scenario: GITHUB_COPILOT_SESSION_ID fallback
- **WHEN** stdin JSON 無 session 欄位，`GITHUB_COPILOT_SESSION_ID=abc12345xyz` 存在
- **THEN** 標題行包含 `(#abc12345)`（取前 8 字元）

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
`scripts/notify/line/` 目錄 SHALL 存在，包含 `.placeholder` 檔案，說明實作時應參考 `scripts/notify/README.md` 的 Provider 擴充指南。

#### Scenario: Line provider 目錄保留擴充指引
- **WHEN** 列出 `scripts/notify/line/` 目錄
- **THEN** `.placeholder` 存在，且內容指向 `scripts/notify/README.md` 的 Provider 擴充指南

---

### Requirement: 說明文件
`docs/notify/architecture.md` SHALL 說明整體架構（目錄結構、config 格式、hook 生命週期、如何新增 provider）。
`docs/notify/telegram.md` SHALL 提供 Telegram 快速安裝說明（含 `/notify-setup` 指令用法與手動方式）。

#### Scenario: 通知文件涵蓋架構與 Telegram 安裝
- **WHEN** 讀取 `docs/notify/architecture.md` 與 `docs/notify/telegram.md`
- **THEN** 文件分別包含通知架構與 Telegram 快速安裝、`/notify-setup`、手動設定說明

---

### Requirement: Codex native lifecycle notifications
The notification installer SHALL register idempotent Codex `Stop` and
`PermissionRequest` command hooks in the user Codex hook configuration when
Codex is detected. The hooks SHALL preserve unrelated configuration and SHALL
not allow, deny, continue, or stop Codex on the user's behalf.

#### Scenario: Codex hooks are registered once
- **WHEN** Codex hook registration runs twice for the same deployed notification hook
- **THEN** `Stop` and `PermissionRequest` each contain one matching command while unrelated hooks remain unchanged

#### Scenario: Codex completion keeps the native stop decision
- **WHEN** the notification hook receives a Codex `Stop` payload
- **THEN** it emits a completion notification and returns neutral JSON that does not continue or stop Codex

#### Scenario: Codex approval keeps the native prompt
- **WHEN** the notification hook receives a Codex `PermissionRequest` payload
- **THEN** it emits an action-required notification and returns no allow or deny decision so the normal Codex approval prompt continues

### Requirement: Antigravity completion notifications
The notification installer SHALL register an idempotent named Antigravity
`Stop` command hook in the global Antigravity hook configuration when
Antigravity CLI is detected. The hook SHALL return a non-continue decision and
SHALL notify only after `fullyIdle` is true.

#### Scenario: Fully idle model stop is complete
- **WHEN** Antigravity sends `fullyIdle=true` and `terminationReason=model_stop`
- **THEN** the hook emits a task-complete notification and returns a decision that allows Antigravity to stop

#### Scenario: Background work remains active
- **WHEN** Antigravity sends `fullyIdle=false`
- **THEN** the hook emits no Telegram notification and still returns a decision that allows the current stop transition

#### Scenario: Error termination is not reported as success
- **WHEN** Antigravity sends `fullyIdle=true` with `terminationReason=error` or `max_steps_exceeded`
- **THEN** the hook reports a stopped execution without including the raw error or claiming successful completion

### Requirement: Opt-in Antigravity approval observer
The installer SHALL offer an opt-in Antigravity status-line observer that emits
an action-required notification when `tool_confirmation_pending` transitions
from false to true for a conversation. Repeated true states SHALL be
deduplicated until a false state resets that conversation.

#### Scenario: First pending confirmation notifies
- **WHEN** an opted-in observer receives `tool_confirmation_pending=true` for a conversation that is not already pending
- **THEN** it emits one action-required notification and records the pending state

#### Scenario: Repeated pending state is deduplicated
- **WHEN** the observer receives another true state for the same still-pending conversation
- **THEN** it emits no additional action-required notification

#### Scenario: Existing custom status line is preserved
- **WHEN** Antigravity settings already contain a different `statusLine.command`
- **THEN** registration reports a conflict and leaves the existing status line unchanged

#### Scenario: Observer remains a valid status line
- **WHEN** the observer is invoked by Antigravity
- **THEN** it writes a compact agent-state value to stdout while keeping Telegram delivery details off stdout

### Requirement: Cross-provider lifecycle preservation
Setup, update, status, and uninstall flows SHALL manage only notification-owned
Codex and Antigravity entries, preserve unrelated JSON fields and hook entries,
and remain idempotent.

#### Scenario: Provider-aware setup
- **WHEN** setup runs on a machine where Codex or Antigravity CLI is detected
- **THEN** completion hooks are registered for each detected CLI and the optional Antigravity approval observer is offered separately

#### Scenario: Status reports provider coverage
- **WHEN** notification status is requested
- **THEN** it reports whether Claude, Gemini, Codex, Antigravity completion, Antigravity approval, and Copilot registrations are present without exposing credentials

#### Scenario: Uninstall preserves unrelated settings
- **WHEN** notification uninstall runs
- **THEN** only commands owned by this notification installation are removed from Codex and Antigravity configuration

### Requirement: Notification privacy and bounded failure
Codex and Antigravity notifications SHALL include only the CLI name, project,
session label, event type, and a generic tool or termination label. They SHALL
exclude raw commands, prompts, transcripts, tool arguments, and raw error text.
Telegram delivery failure SHALL not block the invoking CLI beyond the configured
short timeout.

#### Scenario: Codex approval payload contains a command
- **WHEN** a Codex approval payload includes a raw command or other tool arguments
- **THEN** the Telegram message identifies the requesting tool but does not contain those arguments

#### Scenario: Telegram is unavailable
- **WHEN** Telegram delivery times out or fails
- **THEN** the hook returns the provider's neutral control response and the AI CLI continues its native flow

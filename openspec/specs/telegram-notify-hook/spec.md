# Spec: telegram-notify-hook

## Purpose

提供 Claude Code、Codex、Antigravity CLI 與 Copilot CLI 的 Telegram 通知
hook 整合，讓 AI 任務完成、需要使用者操作或異常停止時自動發送訊息。

## Requirements

### Requirement: 共用基礎庫 — config.sh
`scripts/notify/lib/config.sh` SHALL provide shell functions for reading and
writing `~/.config/ai-notify/config`. Five explicit boolean category keys SHALL override legacy defaults; absent new Codex categories SHALL default false. Category saves MUST preserve unrelated keys and credentials atomically with mode 600. The canonical `NOTIFY_LEVEL` values SHALL
be `all` and `attention_required`; runtime consumers MUST continue treating the
legacy `notify_only` value as equivalent to `attention_required`.

#### Scenario: 首次安裝寫入 config
- **WHEN** install.sh writes a new Telegram configuration
- **THEN** the file is created with mode 600 and a canonical `NOTIFY_LEVEL` value

#### Scenario: 更新通知等級
- **WHEN** update.sh changes the level to `attention_required`
- **THEN** `NOTIFY_LEVEL=attention_required` is persisted while unrelated keys remain unchanged

#### Scenario: 舊設定仍保持低噪音行為
- **WHEN** the hook reads an existing config containing `NOTIFY_LEVEL=notify_only`
- **THEN** it applies `attention_required` behavior instead of falling back to `all`

---

### Requirement: 共用基礎庫 — registry.sh (idempotent hook 註冊)
`scripts/notify/lib/registry.sh` SHALL register notification hooks
idempotently for Claude Code and detected Codex and Antigravity installations.
It SHALL NOT register new Gemini CLI hooks. Setup, repair, and uninstall flows
SHALL remove only notification-owned legacy Gemini entries from
`~/.gemini/settings.json`. Copilot registration SHALL remain repository-local
and opt-in.

#### Scenario: 首次註冊 Claude Code hook
- **WHEN** registration runs and the owned Claude hooks are absent
- **THEN** one `Stop` and one `Notification` command are added without changing unrelated settings

#### Scenario: 重複註冊 Claude Code hook
- **WHEN** registration runs twice for the same deployed hook
- **THEN** the owned Claude entries are not duplicated

#### Scenario: Gemini CLI 不再註冊
- **WHEN** setup runs on a machine containing the Gemini CLI binary or legacy settings file
- **THEN** no Gemini `AfterAgent` or `Notification` hook is added

#### Scenario: 清除舊 Gemini hook
- **WHEN** setup, repair, or uninstall finds notification-owned commands in legacy `~/.gemini/settings.json`
- **THEN** those owned commands are removed while unrelated Gemini settings and hooks remain unchanged

#### Scenario: unregister_hook 清除全域 hooks
- **WHEN** global notification hooks are unregistered
- **THEN** owned Claude, Codex, Antigravity, and legacy Gemini entries are removed without changing unrelated entries

#### Scenario: 首次註冊 Copilot CLI hook
- **WHEN** `register_hook_copilot <hook_path>` runs and `.github/hooks/hooks.json` does not exist
- **THEN** a version 1 file is created with one `sessionEnd` and one `userPromptSubmitted` command

#### Scenario: 重複註冊 Copilot CLI hook
- **WHEN** Copilot registration runs twice
- **THEN** neither owned command is duplicated

#### Scenario: unregister_hook_copilot 清除
- **WHEN** Copilot hooks are unregistered
- **THEN** owned commands are removed while unrelated repository hooks remain unchanged

### Requirement: registry.sh 在 hook 指令中帶入 tool name
Global and repository-local registrations SHALL pass the canonical host name as
the hook's second argument so the shared hook does not infer host identity from
legacy environment variables.

#### Scenario: Claude registration includes tool name
- **WHEN** the Claude hook is registered
- **THEN** its command invokes the deployed hook with `"Claude Code"` as the second argument

#### Scenario: Codex and Antigravity registrations include tool names
- **WHEN** Codex or Antigravity hooks are registered
- **THEN** their commands invoke the deployed hook with `"Codex"` or `"Antigravity CLI"` respectively

#### Scenario: Copilot registration includes tool name
- **WHEN** Copilot hooks are registered
- **THEN** their commands invoke the deployed hook with `"Copilot CLI"` as the second argument

---

### Requirement: install.sh 互動式安裝精靈
`scripts/notify/telegram/install.sh` SHALL guide the user through credential
setup, a grouped Traditional Chinese category menu with help, cancellation and a save summary; legacy notification-level compatibility, hook deployment, supported-host
registration, safe Antigravity approval observation, optional Copilot
registration, and a test notification. It SHALL NOT offer Gemini CLI
registration or a separate Antigravity approval-notification preference.

#### Scenario: 成功完整安裝
- **WHEN** the user completes setup with a valid Bot Token
- **THEN** config and the deployed hook are created and supported detected hosts are registered

#### Scenario: 選擇 attention_required
- **WHEN** the user chooses `attention_required`
- **THEN** setup persists the canonical value and explains that successful completions are suppressed

#### Scenario: 重複執行 install
- **WHEN** install runs again for an existing installation
- **THEN** configuration remains valid and owned hooks are not duplicated

#### Scenario: Bot Token 無效
- **WHEN** the user provides an invalid Bot Token
- **THEN** setup requests another value and does not continue to registration

#### Scenario: Antigravity approval observer is installed automatically
- **WHEN** Antigravity is detected and no different custom status-line command exists
- **THEN** setup registers the notification-owned approval observer without asking for a separate approval-notification preference

#### Scenario: Existing Antigravity status line is preserved
- **WHEN** Antigravity settings contain a different custom status-line command
- **THEN** setup leaves it unchanged and reports that Antigravity approval observation is unavailable

#### Scenario: 選擇註冊 Copilot CLI hook
- **WHEN** the user opts in to repository-local Copilot hooks
- **THEN** `.github/hooks/hooks.json` contains the owned completion and action-required entries

#### Scenario: 跳過 Copilot CLI hook 註冊
- **WHEN** the user declines Copilot registration
- **THEN** `.github/hooks/hooks.json` is not created or changed

#### Scenario: Category edit cancelled
- **WHEN** category editing is cancelled or input ends before saving
- **THEN** no config or deployment changes are made by that edit

---

### Requirement: hook.sh — 通知腳本
The deployed Telegram hook SHALL normalize recognized provider events into
`completion`, `action_required`, or `failure` before applying explicit category switches, falling back to
`NOTIFY_LEVEL` when category keys are absent. `all` SHALL send all three categories.
`attention_required` and legacy `notify_only` SHALL send
`action_required` and `failure` while suppressing only successful completion.
Native provider control responses SHALL be returned even when delivery is
suppressed or unavailable.

#### Scenario: all sends every category
- **WHEN** `NOTIFY_LEVEL=all` receives a completion, action-required, or failure event
- **THEN** each recognized event produces its corresponding Telegram notification

#### Scenario: attention_required suppresses successful completion
- **WHEN** `NOTIFY_LEVEL=attention_required` receives a successful completion
- **THEN** no Telegram message is sent and the provider's native flow continues

#### Scenario: attention_required sends approval
- **WHEN** `NOTIFY_LEVEL=attention_required` receives a permission or confirmation request
- **THEN** an Action Required message is sent

#### Scenario: attention_required sends failure
- **WHEN** `NOTIFY_LEVEL=attention_required` receives an abnormal terminal event
- **THEN** a Task Stopped message is sent without raw error details

#### Scenario: legacy notify_only uses the new policy
- **WHEN** `NOTIFY_LEVEL=notify_only` receives the same fixtures
- **THEN** its observable filtering matches `attention_required`

#### Scenario: Explicit shared switch controls Codex permissions
- **WHEN** NOTIFY_ACTION_REQUIRED=false and a PermissionRequest arrives
- **THEN** the legacy permission message is suppressed without disabling opt-in inspection

### Requirement: 工具偵測以 CLI 參數為主、環境變數為輔
The hook SHALL use its second argument as the canonical host name. When absent,
it SHALL use `"AI CLI"` rather than infer Gemini CLI from
`GEMINI_PROJECT_DIR`. Project location SHALL prefer documented payload cwd or
workspace fields, then `CLAUDE_PROJECT_DIR`, then `PWD`.

#### Scenario: 第二參數指定 tool name
- **WHEN** the hook is invoked with `"Copilot CLI"` as its second argument
- **THEN** the message identifies Copilot CLI regardless of other provider environment variables

#### Scenario: 未提供 tool name
- **WHEN** no second argument is provided
- **THEN** the message identifies the host as `"AI CLI"`

#### Scenario: Payload 提供 workspace
- **WHEN** a supported host payload contains a documented cwd or workspace path
- **THEN** the project name is derived from that path

#### Scenario: Claude environment fallback
- **WHEN** no payload path exists and `CLAUDE_PROJECT_DIR` is set
- **THEN** the project is derived from `CLAUDE_PROJECT_DIR`

#### Scenario: PWD fallback
- **WHEN** neither payload nor Claude project path is available
- **THEN** the project is derived from `PWD`

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
The hook SHALL map Copilot `sessionEnd` to `completion` and
`userPromptSubmitted` to `action_required`, then apply the same semantic policy
used for every supported host.

#### Scenario: Copilot sessionEnd under all
- **WHEN** `sessionEnd` is received with `NOTIFY_LEVEL=all`
- **THEN** a Task Complete notification identifies Copilot CLI

#### Scenario: Copilot userPromptSubmitted under attention_required
- **WHEN** `userPromptSubmitted` is received with `NOTIFY_LEVEL=attention_required`
- **THEN** an Action Required notification identifies Copilot CLI

#### Scenario: Copilot sessionEnd under attention_required
- **WHEN** `sessionEnd` is received with `NOTIFY_LEVEL=attention_required`
- **THEN** the completion notification is suppressed

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
Codex is detected. It SHALL additionally register a neutral PreToolUse handler for synchronous structured-question inspection and a PostToolUse handler for successfully posted async questions, preserving unrelated handlers. The hooks SHALL preserve unrelated configuration and SHALL
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

#### Scenario: Question registration lifecycle
- **WHEN** registration runs twice and is then removed
- **THEN** each owned question handler exists once and is removed without changing unrelated PreToolUse or PostToolUse hooks

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

### Requirement: Automatic Antigravity approval observer
When Antigravity is detected, global registration SHALL attempt to install the
notification-owned custom status-line observer. It SHALL preserve a different
existing command, deduplicate pending confirmations by conversation, and route
the resulting `action_required` event through the shared notification policy.

#### Scenario: First pending confirmation notifies
- **WHEN** an installed observer sees `tool_confirmation_pending` transition from false to true
- **THEN** one Action Required notification is sent under either supported notification level

#### Scenario: Repeated pending confirmation is deduplicated
- **WHEN** the observer receives repeated true states for the same still-pending conversation
- **THEN** no duplicate notification is sent

#### Scenario: False state resets the conversation
- **WHEN** the observer receives a false state
- **THEN** its pending marker is cleared even when Telegram delivery is disabled

#### Scenario: Observer remains a valid status line
- **WHEN** Antigravity invokes the installed observer
- **THEN** it always returns a compact agent-state value without Telegram delivery details

### Requirement: Cross-provider lifecycle preservation
Setup, repair, status, and uninstall SHALL manage only notification-owned
entries for Claude Code, Codex, Antigravity, Copilot, and legacy Gemini
cleanup. Active provider status SHALL cover Claude Code, Codex, Antigravity
completion, Antigravity approval, and Copilot without listing Gemini CLI as a
supported host or exposing credentials.

#### Scenario: Provider-aware setup
- **WHEN** setup detects Codex or Antigravity
- **THEN** it registers their completion hooks and safely attempts the Antigravity approval observer

#### Scenario: Status reports supported coverage
- **WHEN** notification status is requested
- **THEN** it reports Claude Code, Codex, Antigravity completion, Antigravity approval, and Copilot coverage without a Gemini support row

#### Scenario: Status reports approval conflict
- **WHEN** a different Antigravity status-line command prevents approval observation
- **THEN** status distinguishes unavailable approval observation from an installed observer

#### Scenario: Uninstall preserves unrelated settings
- **WHEN** notification uninstall runs
- **THEN** owned commands and state are removed while unrelated provider settings remain unchanged

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

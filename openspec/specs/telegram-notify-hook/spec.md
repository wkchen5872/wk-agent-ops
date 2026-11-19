# Spec: telegram-notify-hook

## Purpose

提供 Claude Code、Codex、Antigravity CLI 與 Copilot CLI 的 Telegram 通知
hook 整合，讓 AI 任務完成、需要使用者操作或異常停止時自動發送訊息。

## Requirements

### Requirement: 共用基礎庫 — config.sh
`scripts/notify/lib/config.sh` SHALL provide shell functions for reading and
writing `~/.config/ai-notify/config`. Four boolean category keys SHALL exist: `NOTIFY_COMPLETION`, `NOTIFY_AUTHORIZATION`, `NOTIFY_USER_INPUT`, and `NOTIFY_FAILURE`. Category saves MUST preserve unrelated keys and credentials atomically with mode 600. The canonical `NOTIFY_LEVEL` values SHALL
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

#### Scenario: Saving categories writes the four keys
- **WHEN** the category menu is saved
- **THEN** the config holds the four category keys and no longer holds `NOTIFY_ACTION_REQUIRED`, `NOTIFY_CODEX_HUMAN_APPROVAL`, or `NOTIFY_CODEX_USER_INPUT`
---

### Requirement: 共用基礎庫 — registry.sh (idempotent hook 註冊)
`scripts/notify/lib/registry.sh` SHALL register notification hooks
idempotently for Claude Code and detected Codex and Antigravity installations,
and SHALL install the notification-owned Pi extension when Pi is detected.
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
- **THEN** owned Claude, Codex, Antigravity, and legacy Gemini entries and the owned Pi extension file are removed without changing unrelated entries

#### Scenario: 首次註冊 Copilot CLI hook
- **WHEN** `register_hook_copilot <hook_path>` runs and `.github/hooks/hooks.json` does not exist
- **THEN** a version 1 file is created with one `sessionEnd` and one `userPromptSubmitted` command

#### Scenario: 重複註冊 Copilot CLI hook
- **WHEN** Copilot registration runs twice
- **THEN** neither owned command is duplicated

#### Scenario: unregister_hook_copilot 清除
- **WHEN** Copilot hooks are unregistered
- **THEN** owned commands are removed while unrelated repository hooks remain unchanged

#### Scenario: 偵測到 Pi 時安裝 extension
- **WHEN** registration runs on a machine where the `pi` command or Pi agent directory exists
- **THEN** the notification-owned Pi extension is installed once in Pi's global extension directory

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

#### Scenario: Pi extension uses the Pi tool name
- **WHEN** the Pi extension sends an event to the deployed hook
- **THEN** it invokes the hook with `"Pi"` as the second argument

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
`completion`, `authorization`, `user_input`, or `failure` before applying the category switches, falling back to
`NOTIFY_LEVEL` when a category key is absent. `all` SHALL send all four categories.
`attention_required` and legacy `notify_only` SHALL suppress only successful completion.
Authorization events SHALL follow the delayed confirmation of `notify-authorization-wait`; user-input events SHALL be sent immediately.
Native provider control responses SHALL be returned even when delivery is
suppressed or unavailable.

#### Scenario: all sends every category
- **WHEN** `NOTIFY_LEVEL=all` receives a completion, user-input, or failure event
- **THEN** each recognized event produces its corresponding Telegram notification

#### Scenario: attention_required suppresses successful completion
- **WHEN** `NOTIFY_LEVEL=attention_required` receives a successful completion
- **THEN** no Telegram message is sent and the provider's native flow continues

#### Scenario: attention_required sends a waiting question
- **WHEN** `NOTIFY_LEVEL=attention_required` receives a user-input event
- **THEN** the waiting-for-response message is sent immediately

#### Scenario: attention_required sends failure
- **WHEN** `NOTIFY_LEVEL=attention_required` receives an abnormal terminal event
- **THEN** a Task Stopped message is sent without raw error details

#### Scenario: legacy notify_only uses the new policy
- **WHEN** `NOTIFY_LEVEL=notify_only` receives the same fixtures
- **THEN** its observable filtering matches `attention_required`

#### Scenario: attention_required sends approval
- **WHEN** `NOTIFY_LEVEL=attention_required` receives a permission or confirmation request that is still waiting after the authorization delay
- **THEN** one authorization message is sent

#### Scenario: Permission request is not sent immediately
- **WHEN** a Codex PermissionRequest arrives with the authorization category enabled
- **THEN** no message is sent at that moment and the delayed confirmation is started

#### Scenario: Explicit shared switch controls Codex permissions
- **WHEN** `NOTIFY_AUTHORIZATION=false` and a PermissionRequest arrives
- **THEN** no authorization message is sent now or later
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
The installer SHALL register an idempotent named Antigravity `Stop` command
hook in the global Antigravity hook configuration when Antigravity CLI is
detected. The hook SHALL return a non-continue decision, notify only after
`fullyIdle` is true, and match `terminationReason` case-insensitively:
`NO_TOOL_CALL` and legacy `model_stop` are completion, `USER_CANCELED` sends
nothing, and any other reason is a stopped execution with a fixed label.

#### Scenario: Fully idle normal completion
- **WHEN** Antigravity sends `fullyIdle=true` and `terminationReason=NO_TOOL_CALL`
- **THEN** the hook emits a task-complete notification and returns a decision that allows Antigravity to stop

#### Scenario: Fully idle model stop is complete
- **WHEN** Antigravity sends `fullyIdle=true` and the legacy value `terminationReason=model_stop`
- **THEN** the hook emits a task-complete notification and returns a decision that allows Antigravity to stop

#### Scenario: Background work remains active
- **WHEN** Antigravity sends `fullyIdle=false`
- **THEN** the hook emits no Telegram notification and still returns a decision that allows the current stop transition

#### Scenario: User cancelled
- **WHEN** Antigravity sends `fullyIdle=true` and `terminationReason=USER_CANCELED`
- **THEN** no Telegram notification is sent

#### Scenario: Error termination is not reported as success
- **WHEN** Antigravity sends `fullyIdle=true` with `terminationReason=ERROR`, `MAX_INVOCATIONS`, or `MAX_TOKEN_BUDGET_EXCEEDED`
- **THEN** the hook reports a stopped execution with the matching fixed label, without the raw error text and without claiming successful completion

#### Scenario: Unknown termination reason
- **WHEN** Antigravity sends `fullyIdle=true` with a reason the hook does not know
- **THEN** the hook reports a stopped execution with a generic label
### Requirement: Automatic Antigravity approval observer
When Antigravity is detected, global registration SHALL attempt to install the
notification-owned custom status-line observer. It SHALL preserve a different
existing command, track pending confirmations by conversation, and hand a pending confirmation to the delayed confirmation of `notify-authorization-wait` under the authorization category.

#### Scenario: First pending confirmation notifies
- **WHEN** an installed observer sees `tool_confirmation_pending` transition from false to true and it is still true after the authorization delay
- **THEN** one authorization notification is sent under either supported notification level

#### Scenario: Pending confirmation answered quickly
- **WHEN** the observer sees `tool_confirmation_pending` become true and then stop being true (false or absent) before the authorization delay ends
- **THEN** no notification is sent

#### Scenario: Repeated pending confirmation is deduplicated
- **WHEN** the observer receives repeated true states for the same still-pending conversation
- **THEN** no duplicate notification is sent

#### Scenario: False state resets the conversation
- **WHEN** the observer receives a state whose `tool_confirmation_pending` is not true, including a state that omits the field
- **THEN** its pending marker is cleared even when Telegram delivery is disabled

#### Scenario: Observer remains a valid status line
- **WHEN** Antigravity invokes the installed observer
- **THEN** it always returns a compact agent-state value without Telegram delivery details
### Requirement: Cross-provider lifecycle preservation
Setup, repair, status, and uninstall SHALL manage only notification-owned
entries for Claude Code, Codex, Antigravity, Copilot, Pi, and legacy Gemini
cleanup. Active provider status SHALL cover Claude Code, Codex, Antigravity
completion, Antigravity approval, Copilot, and Pi without listing Gemini CLI as a
supported host or exposing credentials.

#### Scenario: Provider-aware setup
- **WHEN** setup detects Codex or Antigravity
- **THEN** it registers their completion hooks and safely attempts the Antigravity approval observer

#### Scenario: Status reports supported coverage
- **WHEN** notification status is requested
- **THEN** it reports Claude Code, Codex, Antigravity completion, Antigravity approval, Copilot, and Pi coverage without a Gemini support row

#### Scenario: Status reports approval conflict
- **WHEN** a different Antigravity status-line command prevents approval observation
- **THEN** status distinguishes unavailable approval observation from an installed observer

#### Scenario: Uninstall preserves unrelated settings
- **WHEN** notification uninstall runs
- **THEN** owned commands and state are removed while unrelated provider settings remain unchanged

#### Scenario: Status reports a Pi conflict
- **WHEN** a Pi extension file of the same name without the ownership marker prevents installation
- **THEN** status reports Pi notifications as unavailable because of the existing file

### Requirement: Notification privacy and bounded failure
Codex, Antigravity, and Pi notifications SHALL include only the CLI name, the
model label, project, session label, event type, and a generic tool or
termination label. They SHALL
exclude raw commands, prompts, transcripts, tool arguments, and raw error text.
Telegram delivery failure SHALL not block the invoking CLI beyond the configured
short timeout.

#### Scenario: Codex approval payload contains a command
- **WHEN** a Codex approval payload includes a raw command or other tool arguments
- **THEN** the Telegram message identifies the requesting tool but does not contain those arguments

#### Scenario: Telegram is unavailable
- **WHEN** Telegram delivery times out or fails
- **THEN** the hook returns the provider's neutral control response and the AI CLI continues its native flow

#### Scenario: Pi failure carries an error message
- **WHEN** a Pi run settles with an error whose message contains a file path and an API response
- **THEN** the Telegram message reports a failure for `Pi` without that text

### Requirement: Codex notification hooks have display names
The notification installer SHALL write a non-empty `statusMessage` on each owned Codex handler. The defaults SHALL be `Telegram 完成通知` for Stop, `Telegram 操作確認與等待檢查` for PermissionRequest, `Telegram 同步問題等待檢查` for question PreToolUse, and `Telegram 非同步問題通知` for async-question PostToolUse. The field SHALL be on the handler alongside `type` and `command`.

#### Scenario: First Codex registration is named
- **WHEN** notification registration runs with no owned Codex handlers present
- **THEN** each of the four owned handlers is registered once with its documented default `statusMessage`
- **AND** existing event names, matchers, commands, timeout values, and neutral runtime behavior remain unchanged

### Requirement: Registration fills missing Codex notification names
Ordinary notification installation and repeated registration SHALL fill absent, null, empty, or whitespace-only `statusMessage` values on matching owned Codex handlers. Registration SHALL preserve non-blank custom names and all other existing fields. It MUST NOT rename unrelated handlers or duplicate existing registrations.

#### Scenario: An existing handler has no usable name
- **WHEN** registration finds an owned handler with absent, null, empty, or whitespace-only `statusMessage`
- **THEN** it fills that handler's documented default name without replacing the handler or its matcher group

#### Scenario: The user already named a handler
- **WHEN** registration finds an owned handler whose `statusMessage` is `我的完成提醒`
- **THEN** the value remains `我的完成提醒` and no duplicate handler is added

#### Scenario: Repeated registration converges
- **WHEN** registration runs twice on a configuration containing unnamed owned handlers, named owned handlers, and unrelated handlers
- **THEN** the second run leaves the JSON configuration semantically unchanged
- **AND** unrelated handlers and top-level configuration remain unchanged on both runs

### Requirement: Explicit notification repair restores default Codex names
The explicit `fix-hooks` repair SHALL recreate owned Codex notification handlers with their documented default names. Its documentation SHALL distinguish this reset from ordinary registration, which preserves custom names. Repair SHALL preserve unrelated hooks and MUST NOT approve, enable, or bypass Codex hook trust.

#### Scenario: Explicit repair rebuilds named handlers
- **WHEN** `fix-hooks` repairs an existing installation with a custom-owned notification name
- **THEN** the recreated handler has its documented default `statusMessage`
- **AND** unrelated hooks remain intact and the user is directed to review Codex hooks

### Requirement: Naming changes preserve other notification providers
Adding Codex display names SHALL leave the existing Claude Code, Antigravity, and Copilot notification registration formats and behavior unchanged. Notification registration MUST NOT add Codex naming fields to another provider's handlers.

#### Scenario: Multiple providers are configured
- **WHEN** notification registration runs with Codex and other supported providers configured
- **THEN** Codex handlers receive names while other providers retain their existing registration fields and behavior

### Requirement: Legacy category keys remain readable
When a new category key is absent from a source, the hook and the settings menu SHALL derive its value from that source's legacy keys: `NOTIFY_AUTHORIZATION` from `NOTIFY_ACTION_REQUIRED` and `NOTIFY_CODEX_HUMAN_APPROVAL`, and `NOTIFY_USER_INPUT` from `NOTIFY_ACTION_REQUIRED` and `NOTIFY_CODEX_USER_INPUT`. The derived value SHALL be enabled when either legacy key is `true`, and disabled when at least one is `false` and none is `true`.

#### Scenario: Existing config with only legacy keys
- **WHEN** the config holds `NOTIFY_ACTION_REQUIRED=true` and none of the new keys
- **THEN** the authorization and user-input categories are both enabled

#### Scenario: One legacy key on and one off
- **WHEN** the config holds `NOTIFY_ACTION_REQUIRED=true` and `NOTIFY_CODEX_HUMAN_APPROVAL=false` and no `NOTIFY_AUTHORIZATION`
- **THEN** the authorization category is enabled, including delayed Codex authorization notices

#### Scenario: Both legacy sources are off
- **WHEN** the config holds `NOTIFY_ACTION_REQUIRED=false` and `NOTIFY_CODEX_USER_INPUT=false` and no `NOTIFY_USER_INPUT`
- **THEN** the user-input category is disabled

#### Scenario: First menu save migrates the values
- **WHEN** a config holding `NOTIFY_ACTION_REQUIRED=true`, `NOTIFY_CODEX_HUMAN_APPROVAL=false`, and `NOTIFY_CODEX_USER_INPUT=true` is saved from the category menu without toggling anything
- **THEN** the config holds `NOTIFY_AUTHORIZATION=true` and `NOTIFY_USER_INPUT=true`, the three legacy keys are gone, and every other key is unchanged

### Requirement: Category values resolve in a fixed order
A category value SHALL be taken from the first source that defines it, in this order: the new key in the environment, the legacy keys in the environment, the new key in the config file, the legacy keys in the config file, then the level default. Only the exact values `true` and `false` SHALL count; any other value, including an empty one, SHALL be treated as not defined in that source.

#### Scenario: New key wins over legacy keys
- **WHEN** the config holds `NOTIFY_AUTHORIZATION=false` and `NOTIFY_ACTION_REQUIRED=true`
- **THEN** the authorization category is disabled

#### Scenario: Legacy environment override still delivers
- **WHEN** a caller sets `NOTIFY_ACTION_REQUIRED=true` in the environment and sends a notification event without a type
- **THEN** the message is delivered even when the config file sets `NOTIFY_USER_INPUT=false`

#### Scenario: New environment key beats legacy environment key
- **WHEN** the environment holds `NOTIFY_USER_INPUT=false` and `NOTIFY_ACTION_REQUIRED=true`
- **THEN** the user-input category is disabled

#### Scenario: Invalid value is ignored
- **WHEN** the config holds `NOTIFY_AUTHORIZATION=yes` and `NOTIFY_ACTION_REQUIRED=false`
- **THEN** the authorization category is disabled, as if `NOTIFY_AUTHORIZATION` were absent

#### Scenario: Nothing defined
- **WHEN** no source defines the authorization category
- **THEN** it is enabled

### Requirement: Claude Code notifications are classified by type
The hook SHALL classify a Claude Code Notification by its `notification_type`: `permission_prompt` as authorization (except for questions, see the next requirement); `idle_prompt`, `agent_needs_input`, `elicitation_dialog`, and `elicitation_url_dialog` as user input; and a notification without a type as user input. Other types SHALL NOT be sent as a request for the user's action.

#### Scenario: Permission prompt
- **WHEN** a Notification with `notification_type=permission_prompt` arrives
- **THEN** it is handled as an authorization event with delayed confirmation

#### Scenario: Waiting for input
- **WHEN** a Notification with `notification_type=idle_prompt` arrives
- **THEN** the waiting-for-response message is sent immediately

#### Scenario: Notification without a type
- **WHEN** a notification event arrives with a message and no `notification_type`
- **THEN** it is sent immediately under the user-input category

#### Scenario: Informational notification
- **WHEN** a Notification with `notification_type=auth_success` arrives
- **THEN** no waiting or authorization message is sent

### Requirement: Claude Code questions are not authorization waits
Claude Code also raises `AskUserQuestion` through a `permission_prompt` Notification. When the pending tool call in the session record is `AskUserQuestion`, the hook SHALL send the waiting-for-response question message at once under the user-input category, without the authorization delay or authorization wording.

#### Scenario: Question raised through a permission prompt
- **WHEN** a Notification with `notification_type=permission_prompt` arrives and the pending tool call in the session record is `AskUserQuestion`
- **THEN** the question message is sent at once under the user-input category and no authorization wait is started

#### Scenario: Questions disabled
- **WHEN** the same question arrives and the user-input category is disabled
- **THEN** no message is sent, even when the authorization category is enabled

### Requirement: Changing the level keeps other switches
Changing `NOTIFY_LEVEL` through the update menu SHALL write only `NOTIFY_LEVEL` and the completion switch that the level defines. It MUST NOT change the authorization, user-input, or failure switches.

#### Scenario: Level changed while authorization is off
- **WHEN** `NOTIFY_AUTHORIZATION=false` and the user changes the level to `attention_required`
- **THEN** `NOTIFY_AUTHORIZATION` is still `false` afterward

### Requirement: Settings menu names the four categories
The category menu SHALL list 工作結束, 授權要求, 等待回應, and 異常停止, each with its on or off state, and SHALL state that 授權要求 notifies only when an agent is still waiting after the configured delay.

#### Scenario: Menu shows the renamed category
- **WHEN** the user opens the category menu
- **THEN** the menu shows 授權要求 and no entry named 既有操作提醒


### Requirement: Handoff events are delivered through the notification hook
The notification hook SHALL accept handoff events from the handoff routing hook, render each kind from its own template, and apply the handoff switches itself. Attention events SHALL be delivered whenever Telegram delivery is enabled, independent of the category switches and of `NOTIFY_LEVEL`. The sender MUST NOT need an environment override to have a handoff event delivered.

#### Scenario: Attention event with other categories off
- **WHEN** every category switch is off, Telegram delivery is enabled, and a handoff attention event arrives
- **THEN** the attention message is sent

#### Scenario: Progress event with its switch off
- **WHEN** `NOTIFY_HANDOFF_FINISH=false` and a handoff finish event arrives
- **THEN** no message is sent

#### Scenario: Attention event without a usable template
- **WHEN** a handoff attention event arrives and its template or table entry is missing
- **THEN** the attention message is still sent with a built-in fallback text

#### Scenario: Handoff event uses its own template
- **WHEN** a handoff review event arrives
- **THEN** the message is rendered from the handoff review template, not from the waiting-for-response template

### Requirement: Settings menu lists the handoff switches
The category menu SHALL list the three handoff switches — 交件單實作完成, 交件單每輪審查, 交件單收尾 — with their on or off state, and SHALL state that notices needing the user are always sent. Saving SHALL write the three keys without changing other keys.

#### Scenario: Handoff switch saved
- **WHEN** the user turns off 交件單實作完成 and saves
- **THEN** the config holds `NOTIFY_HANDOFF_IMPLEMENT=false` and every other key is unchanged

### Requirement: The hook finds the model of the session
The hook SHALL take the model from the payload's `model` string when present.
When the payload has none and the host is Claude Code, it SHALL take the model of
the most recent assistant entry in the session record named by
`transcript_path`, skipping values that start with `<`. The model SHALL be
reduced to a value without a trailing bracketed suffix, made of letters, digits,
and `._:/-`, at most 64 characters; an empty result means no model is known.

#### Scenario: Codex payload names the model
- **WHEN** a Codex Stop payload contains `"model": "gpt-6.1-terra"`
- **THEN** the message's tool line is `🤖 Codex (gpt-6.1-terra)`

#### Scenario: Claude Code model comes from the session record
- **WHEN** a Claude Code Stop payload has no model and the last assistant entry of its session record has model `claude-opus-5-5`
- **THEN** the message's tool line is `🤖 Claude Code (Opus 5.5)`

#### Scenario: Synthetic entries are skipped
- **WHEN** the newest assistant entry of a Claude Code session record has model `<synthetic>` and the one before it has `claude-fable-5-2`
- **THEN** the message's tool line is `🤖 Claude Code (Fable 5.2)`

#### Scenario: Model unknown
- **WHEN** a payload has no model and no model can be read from a session record
- **THEN** the message's tool line is the tool name alone, without empty parentheses

#### Scenario: Context-size suffix and unsafe characters
- **WHEN** a payload's model is `claude-opus-5-5[1m]` or contains backticks or spaces
- **THEN** the suffix is removed, the unsafe characters are dropped, and the message shows `Opus 5.5` for the first case

### Requirement: The tool line shows the model name
A Claude model ID SHALL be shown as its capitalized family name followed by its
version (`claude-opus-5-5` as `Opus 5.5`), and a family-only alias as the family
name alone; any other ID SHALL be shown unchanged. Templates SHALL receive
`model_suffix`, the shown name with its version in parentheses after a space, and
`model_family_suffix`, the same without the version; both SHALL be empty when no
model is known. Built-in templates SHALL show the tool name followed by
`model_suffix`.

#### Scenario: Pi on a GPT model
- **WHEN** a Pi event payload contains `"model": "gpt-6.1-sol"`
- **THEN** the message's tool line is `🤖 Pi (gpt-6.1-sol)`

#### Scenario: Dated and legacy Claude IDs
- **WHEN** the model is `claude-sonnet-4-5-20250929`, `claude-opus-4-20250514`, or `claude-3-5-sonnet-20241022`
- **THEN** the shown name is `Sonnet 4.5`, `Opus 4`, or `Sonnet 3.5` respectively

#### Scenario: User template drops the version
- **WHEN** a user template's tool line is `🤖 {tool}{model_family_suffix}` and the model is `claude-opus-5-5`
- **THEN** the message's tool line is `🤖 Claude Code (Opus)`

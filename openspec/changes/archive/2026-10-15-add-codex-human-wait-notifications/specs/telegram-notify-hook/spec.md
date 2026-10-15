## MODIFIED Requirements

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

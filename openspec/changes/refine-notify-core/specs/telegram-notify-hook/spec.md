# Spec Delta

## MODIFIED Requirements

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

### Requirement: Antigravity completion notifications
The notification installer SHALL register an idempotent named Antigravity
`Stop` command hook in the global Antigravity hook configuration when
Antigravity CLI is detected. The hook SHALL return a non-continue decision and
SHALL notify only after `fullyIdle` is true. It SHALL compare `terminationReason` without regard to letter case, treat `NO_TOOL_CALL` and the legacy `model_stop` as successful completion, send nothing for `USER_CANCELED`, and report every other reason as a stopped execution with a fixed label.

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
- **WHEN** the observer sees `tool_confirmation_pending` become true and then false before the authorization delay ends
- **THEN** no notification is sent

#### Scenario: Repeated pending confirmation is deduplicated
- **WHEN** the observer receives repeated true states for the same still-pending conversation
- **THEN** no duplicate notification is sent

#### Scenario: False state resets the conversation
- **WHEN** the observer receives a false state
- **THEN** its pending marker is cleared even when Telegram delivery is disabled

#### Scenario: Observer remains a valid status line
- **WHEN** Antigravity invokes the installed observer
- **THEN** it always returns a compact agent-state value without Telegram delivery details

## ADDED Requirements

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
The hook SHALL classify a Claude Code Notification by its `notification_type`: `permission_prompt` as authorization; `idle_prompt`, `agent_needs_input`, `elicitation_dialog`, and `elicitation_url_dialog` as user input; and a notification without a type as user input. Other types SHALL NOT be sent as a request for the user's action.

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

# Spec: notify-test-harness

## Purpose

提供自動化測試框架，驗證 hook.sh 在各種情境下的行為正確性，無需真實 Telegram 連線。利用 dry-run 模式捕捉輸出並與期望值比對。

## Requirements

### Requirement: hook.sh dry-run 模式
The hook SHALL support `TELEGRAM_DRY_RUN=true`, skipping Telegram HTTP delivery
while exposing the rendered message for assertions. Dry-run SHALL preserve
semantic event classification, canonical and legacy notification-level
behavior, provider control responses, privacy filtering, and Antigravity state
transitions.

#### Scenario: Dry-run outputs a rendered notification
- **WHEN** dry-run receives an event allowed by the active notification level
- **THEN** the complete rendered message is written without an HTTP request

#### Scenario: Dry-run suppresses completion under attention_required
- **WHEN** dry-run receives a successful completion with `NOTIFY_LEVEL=attention_required`
- **THEN** no Telegram message is rendered

#### Scenario: Dry-run keeps attention events
- **WHEN** dry-run receives an action-required or failure event with `NOTIFY_LEVEL=attention_required`
- **THEN** the corresponding Action Required or Task Stopped message is rendered

---

### Requirement: test.sh — hook 行為測試腳本
`scripts/notify/telegram/test.sh` SHALL 提供自動化測試，利用 `TELEGRAM_DRY_RUN=true` 驗證 hook.sh 在各種情境下的輸出，無需真實 Telegram 連線。測試結果以 PASS / FAIL 顯示，所有 PASS 時 exit 0，有任何 FAIL 時 exit 1。

#### Scenario: 執行所有測試並顯示結果
- **WHEN** `bash scripts/notify/telegram/test.sh` 執行
- **THEN** 每個測試案例顯示 `✓ PASS: <name>` 或 `✗ FAIL: <name>` 及期望 vs 實際內容，最後顯示總結（N passed, M failed）

#### Scenario: 全部通過時 exit 0
- **WHEN** 所有測試案例通過
- **THEN** 腳本 exit 0

#### Scenario: 有失敗時 exit 1
- **WHEN** 至少一個測試案例失敗
- **THEN** 腳本 exit 1（方便 CI 整合）

---

### Requirement: 測試覆蓋已知問題情境
`test.sh` SHALL cover the supported host mappings, semantic notification policy,
legacy level compatibility, session formatting, and previously reported
provider regressions. It SHALL NOT retain active Gemini CLI behavior tests.

#### Scenario: [BUG-01] Copilot sessionEnd is completion
- **WHEN** the harness replays `sessionEnd`
- **THEN** the output contains Task Complete and not a generic AI CLI event

#### Scenario: [BUG-02] Explicit tool name wins
- **WHEN** a hook command supplies Copilot CLI while another provider environment variable is present
- **THEN** the output identifies Copilot CLI only

#### Scenario: [BUG-04] Claude Stop is completion
- **WHEN** the harness replays Claude Stop under `all`
- **THEN** the output contains Task Complete and Claude Code

#### Scenario: [BUG-05] Claude Notification is action required
- **WHEN** the harness replays a Claude Notification
- **THEN** the output contains Action Required and the sanitized message

#### Scenario: [SESSION-01] UUID session is shortened
- **WHEN** a payload contains a UUID session identifier
- **THEN** the title contains a `#` followed by its first eight characters

#### Scenario: [SESSION-02] Missing session has no suffix
- **WHEN** no session information is available
- **THEN** the notification title has no empty session brackets

#### Scenario: [LEVEL-01] attention_required suppresses completion
- **WHEN** each supported completion fixture runs with `NOTIFY_LEVEL=attention_required`
- **THEN** every completion message is suppressed

#### Scenario: [LEVEL-02] attention_required allows action required
- **WHEN** each supported permission or confirmation fixture runs with `NOTIFY_LEVEL=attention_required`
- **THEN** each produces an Action Required message

#### Scenario: [LEVEL-03] attention_required allows failure
- **WHEN** Antigravity error and max-step fixtures run with `NOTIFY_LEVEL=attention_required`
- **THEN** each produces Task Stopped and never Task Complete

#### Scenario: [LEVEL-04] legacy value matches canonical behavior
- **WHEN** the same fixtures run with `notify_only` and `attention_required`
- **THEN** their delivery decisions are identical

---

### Requirement: Codex notification contract tests
The dry-run harness SHALL verify Codex completion and approval messages as well
as native control responses without contacting Telegram.

#### Scenario: Codex Stop dry-run
- **WHEN** the harness replays a Codex `Stop` payload
- **THEN** it verifies the task-complete message, Codex identity, session label, and absence of control-changing output

#### Scenario: Codex PermissionRequest dry-run
- **WHEN** the harness replays a permission payload containing a tool name and raw command
- **THEN** it verifies an action-required message containing the tool name but not the raw command

#### Scenario: Codex native response
- **WHEN** the hook runs outside dry-run with notifications disabled
- **THEN** it returns valid neutral JSON and exits zero for both Codex events

### Requirement: Antigravity notification contract tests
The harness SHALL verify Antigravity completion, failure, native stop output,
automatic approval registration, status-line conflict preservation, approval
transition deduplication, level filtering, and compact status output without a
live Antigravity session.

#### Scenario: Idle and abnormal Stop fixtures
- **WHEN** model-stop, not-idle, error, and max-step payloads are replayed under both levels
- **THEN** successful completion follows the level while abnormal terminal events remain visible

#### Scenario: Native Stop response
- **WHEN** Telegram delivery is disabled
- **THEN** the Stop hook returns a non-continue decision accepted by Antigravity

#### Scenario: Approval transition under both levels
- **WHEN** true, repeated true, false, and true states are replayed under `all` and `attention_required`
- **THEN** each level produces exactly two Action Required messages and every invocation returns a compact status value

#### Scenario: Approval registration conflict
- **WHEN** fixture settings contain a different status-line command
- **THEN** registration leaves that command unchanged and reports approval observation unavailable

### Requirement: Isolated registry lifecycle tests
Registry tests SHALL use an isolated home and repository and SHALL verify
idempotent supported-host registration, automatic Antigravity approval
observation, legacy Gemini cleanup, status coverage, conflict handling, and
ownership-scoped uninstall without changing developer settings.

#### Scenario: Supported hosts register twice
- **WHEN** global registration runs twice against isolated Claude, Codex, and Antigravity fixtures
- **THEN** owned entries are present once and unrelated JSON remains unchanged

#### Scenario: Gemini is cleanup-only
- **WHEN** isolated legacy Gemini settings contain owned and unrelated commands
- **THEN** registration removes owned commands, adds no Gemini commands, and preserves unrelated content

#### Scenario: Status excludes Gemini support
- **WHEN** status runs against registered supported-host fixtures
- **THEN** it reports supported coverage without credentials or a Gemini support row

#### Scenario: Copilot regression
- **WHEN** Copilot registration runs in an isolated repository
- **THEN** completion and action-required entries exist once and uninstall removes both

### Requirement: Notification level migration tests
The harness SHALL verify that setup and update accept only canonical level names
for new input while preserving safe behavior for legacy config.

#### Scenario: New setup writes attention_required
- **WHEN** setup selects the reduced-notification mode
- **THEN** the config contains `NOTIFY_LEVEL=attention_required`

#### Scenario: Legacy default is normalized
- **WHEN** setup or level update loads `NOTIFY_LEVEL=notify_only`
- **THEN** the presented and persisted canonical value is `attention_required`

#### Scenario: Invalid level is rejected
- **WHEN** setup or update receives any value other than `all` or `attention_required`
- **THEN** it requests a valid canonical value without changing the config

### Requirement: Category and on-demand checker regression tests
The harness SHALL verify five category switches, grouped editing, cancellation, legacy migration, independent hook branches and checker lifecycle against isolated HOME directories and fake daemon metadata without sending real notifications.

#### Scenario: Isolated category matrix
- **WHEN** every old and new event runs with its switch enabled and disabled
- **THEN** its own switch determines delivery and legacy fixtures retain behavior

#### Scenario: Checker lifecycle fixtures
- **WHEN** fixtures cover delayed flags, repeated hooks, wait resets, multiple sessions, turn completion and connection failure
- **THEN** tests verify non-blocking startup, deduplication, bounded failure and cleanup

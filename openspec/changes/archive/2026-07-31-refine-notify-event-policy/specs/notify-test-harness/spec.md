## MODIFIED Requirements

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

## ADDED Requirements

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

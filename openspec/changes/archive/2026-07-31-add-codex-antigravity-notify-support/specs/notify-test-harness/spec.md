## ADDED Requirements

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
The harness SHALL verify Antigravity idle completion, abnormal termination,
native stop output, approval transition deduplication, and compact status output
without running a live Antigravity session.

#### Scenario: Antigravity idle and abnormal fixtures
- **WHEN** the harness replays model-stop, not-idle, error, and max-step Stop payloads
- **THEN** only fully idle fixtures notify and abnormal fixtures are not labelled successful

#### Scenario: Antigravity native response
- **WHEN** the Stop hook runs outside dry-run with notifications disabled
- **THEN** stdout contains a non-continue decision accepted by the documented Antigravity contract

#### Scenario: Approval transition fixture
- **WHEN** the harness replays true, repeated true, false, and true status states for one conversation
- **THEN** exactly two action-required notifications are produced and every invocation returns a compact status value

### Requirement: Isolated registry lifecycle tests
Registry tests SHALL use an isolated home and repository, SHALL run without
changing the developer's real CLI settings, and SHALL verify register,
re-register, conflict, status, and unregister behavior for Codex, Antigravity,
and the existing Copilot action-required entry.

#### Scenario: Register and re-register
- **WHEN** provider registry functions run twice against fixture JSON containing unrelated hooks
- **THEN** owned entries are not duplicated and unrelated JSON remains unchanged

#### Scenario: Status-line conflict
- **WHEN** fixture Antigravity settings contain a different custom status-line command
- **THEN** the test verifies registration fails safely without modifying that command

#### Scenario: Copilot action-required regression
- **WHEN** Copilot registration runs against an isolated repository
- **THEN** both `sessionEnd` and `userPromptSubmitted` owned entries exist once and uninstall removes both


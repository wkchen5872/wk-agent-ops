# Spec: codex-human-wait-notifications

## Purpose

Provide opt-in notifications for observed human approval and structured-input waiting in existing Codex daemon sessions, without a login service or any change to the agent's permission decisions.

## Requirements

### Requirement: Independent hook-triggered inspection
Codex permission and synchronous structured-question hooks SHALL start non-blocking inspection only when a human-wait category is enabled. Async questions SHALL use the native successful-result path instead. Legacy action-required delivery SHALL be independently selectable. Hooks MUST return neutral success even when inspection cannot run.

#### Scenario: Legacy notification disabled
- **WHEN** shared action-required delivery is disabled and a Codex human-wait category is enabled
- **THEN** a permission hook starts inspection without sending the legacy message

#### Scenario: New categories disabled
- **WHEN** both human-wait categories are disabled
- **THEN** neither permission nor question hooks start a checker or connect to the daemon

#### Scenario: Structured question entrypoint
- **WHEN** a supported synchronous structured-question tool begins
- **THEN** its hook starts the same inspection path without waiting for the user to answer

### Requirement: On-demand lifecycle and coalescing
Inspection SHALL observe only the triggering session and turn, with at most one checker per daemon/session. It SHALL exit when the turn ends or changes, the thread unloads, both categories are disabled, or bounded connection recovery fails. It MUST NOT install a login service or start/resume Codex.

#### Scenario: Repeated permission hooks
- **WHEN** many hooks arrive during the same active turn
- **THEN** at most one checker runs for that session

#### Scenario: Work finishes
- **WHEN** the triggering turn is completed or cancelled
- **THEN** the checker exits and a later turn can start another checker

#### Scenario: Daemon unavailable
- **WHEN** connection or schema checks fail
- **THEN** inspection exits after bounded recovery without blocking native work or inventing a waiting notification

### Requirement: Explicit human-wait transitions
Inspection SHALL use runtime waiting flags for human approvals and synchronous structured questions, separately deduplicated per session and kind. It SHALL notify once per observed continuous wait and re-arm after explicit resolution. For request_user_input_async, a successful PostToolUse accepted=true result SHALL instead trigger the user-input notification without daemon inspection; it means the question was posted, not that generation is blocked. Automatic review without a human-wait flag, general text questions and elapsed quiet time MUST NOT produce human-wait messages.

#### Scenario: Async question successfully posted
- **WHEN** request_user_input_async returns accepted=true in PostToolUse
- **THEN** the enabled user-input category sends a sanitized question notification without requiring a daemon wait flag

#### Scenario: Async question was not accepted
- **WHEN** the async result is missing, malformed, rejected, or belongs to another tool
- **THEN** no question notification is sent and the hook returns neutral success

#### Scenario: Answer then ask again
- **WHEN** a question wait appears, repeats, clears, then appears again
- **THEN** two question-wait messages are attempted

#### Scenario: Automatic review
- **WHEN** the reviewer handles an action without a pending human flag
- **THEN** no human-wait notification is sent

#### Scenario: Multiple sessions and categories
- **WHEN** independent sessions or waiting kinds become pending
- **THEN** their notification state is tracked independently

### Requirement: Metadata privacy and support status
Inspection SHALL read only runtime metadata, never grant permissions or answer requests, and never send raw commands, questions or transcripts. Status SHALL distinguish disabled, on-demand ready, unavailable and unverified coverage. New message titles SHALL distinguish waiting for approval from waiting for an answer.

#### Scenario: Sensitive payload
- **WHEN** a triggering hook includes raw tool input or a transcript path
- **THEN** these fields are excluded from checker inputs, persisted state and Telegram messages

#### Scenario: Checker currently inactive
- **WHEN** the checker is installed but no qualifying hook has fired
- **THEN** status identifies on-demand behavior rather than a failed service

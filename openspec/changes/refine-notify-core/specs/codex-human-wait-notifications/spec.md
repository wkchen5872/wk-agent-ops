# Spec Delta

## MODIFIED Requirements

### Requirement: Independent hook-triggered inspection
Codex permission and synchronous structured-question hooks SHALL start non-blocking inspection only when the category they serve is enabled: authorization for permission hooks, user input for question hooks. Async questions SHALL use the native successful-result path instead. A permission hook MUST NOT send a message at the moment the request is raised. Hooks MUST return neutral success even when inspection cannot run.

#### Scenario: Legacy notification disabled
- **WHEN** the authorization category is enabled and a permission hook arrives
- **THEN** inspection starts and no message is sent at the moment the request is raised

#### Scenario: New categories disabled
- **WHEN** both the authorization and user-input categories are disabled
- **THEN** neither permission nor question hooks start a checker or connect to the daemon

#### Scenario: Structured question entrypoint
- **WHEN** a supported synchronous structured-question tool begins
- **THEN** its hook starts the same inspection path without waiting for the user to answer

### Requirement: On-demand lifecycle and coalescing
Inspection SHALL observe only the triggering session and turn, with at most one checker per daemon/session. It SHALL exit when the turn ends or changes, the thread unloads after it was seen active, both categories are disabled, or bounded connection recovery fails and no authorization request is pending. A session that the daemon reports as not loaded on the first query SHALL be handled as a runtime that cannot be queried. It MUST NOT install a login service or start/resume Codex.

#### Scenario: Repeated permission hooks
- **WHEN** many hooks arrive during the same active turn
- **THEN** at most one checker runs for that session

#### Scenario: Work finishes
- **WHEN** the triggering turn is completed or cancelled
- **THEN** the checker exits and a later turn can start another checker

#### Scenario: Daemon unavailable
- **WHEN** connection or schema checks fail and only a synchronous question is being observed
- **THEN** inspection exits after bounded recovery without blocking native work or inventing a waiting notification

#### Scenario: Daemon unavailable with a pending authorization request
- **WHEN** connection or schema checks fail while an authorization request is pending
- **THEN** inspection keeps the pending request, and after the authorization delay sends the unconfirmed notification if the session record still shows no result, without blocking native work

#### Scenario: Session not loaded by the daemon
- **WHEN** the daemon answers but reports the triggering session as not loaded on the first query, while an authorization request is pending
- **THEN** the runtime is treated as unable to be queried: the pending request is kept, and after the authorization delay the unconfirmed notification is sent if the session record still shows no result

#### Scenario: Session unloads after it was active
- **WHEN** the daemon reported the session as active and later reports it as not loaded
- **THEN** the turn is treated as finished and inspection exits without a notification

### Requirement: Explicit human-wait transitions
Inspection SHALL send a confirmed approval notification only when the runtime waiting flag lasts longer than the authorization delay. When the runtime cannot be queried and the session record still shows the request without a result after the delay, it SHALL send the unconfirmed notification of `notify-authorization-wait` instead. Synchronous structured questions SHALL notify as soon as their waiting flag is observed. Each kind SHALL be deduplicated per session, notify once per continuous wait, and re-arm after resolution. For request_user_input_async, a successful PostToolUse accepted=true result SHALL trigger the user-input notification without daemon inspection. Automatic review that resolves within the delay, general text questions, and quiet time without an unresolved authorization request MUST NOT produce human-wait messages.

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
- **WHEN** the reviewer approves or denies an action before the authorization delay ends
- **THEN** no human-wait notification is sent

#### Scenario: Approval still waiting after the delay
- **WHEN** the waiting-for-approval flag stays set past the authorization delay
- **THEN** one authorization notification is sent for that wait

#### Scenario: Quiet turn without a request
- **WHEN** a turn is silent for longer than the delay and no authorization request is pending
- **THEN** no human-wait notification is sent

#### Scenario: Multiple sessions and categories
- **WHEN** independent sessions or waiting kinds become pending
- **THEN** their notification state is tracked independently

## ADDED Requirements

### Requirement: Stale inspection state is pruned
Starting an inspection SHALL remove notification-owned Codex state files that are older than seven days and whose checker is not running. It MUST NOT remove the state of a running checker, files newer than seven days, or files that do not match the notification-owned naming pattern.

#### Scenario: Old state of a finished session
- **WHEN** a state file set is ten days old and no checker holds its lock
- **THEN** the lock, state, and request files of that session are removed

#### Scenario: Running checker
- **WHEN** a state file set is ten days old and its checker still holds the lock
- **THEN** none of its files are removed

#### Scenario: Recent state
- **WHEN** a state file set is one day old
- **THEN** it is kept

#### Scenario: Unrelated file in the state directory
- **WHEN** the state directory holds a file that does not match the notification-owned pattern
- **THEN** that file is kept

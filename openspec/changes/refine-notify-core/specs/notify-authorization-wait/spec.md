# Spec Delta

## Purpose

Tell the user when an agent is really stopped waiting for their authorization, instead of every time an authorization request is raised. A request that an automatic reviewer or the user resolves quickly produces no notification.

## ADDED Requirements

### Requirement: Authorization notices are confirmed after a delay
When a supported tool signals a possible authorization wait, the hook SHALL return at once and SHALL NOT notify immediately. It SHALL send one authorization notification only when the wait is still unresolved after `NOTIFY_AUTHORIZATION_DELAY_SECONDS` seconds, default 30. A value of 0 SHALL notify immediately. A non-numeric or negative value SHALL be treated as the default.

#### Scenario: Request resolved within the delay
- **WHEN** an authorization request is raised and resolved 6 seconds later with the default delay
- **THEN** no authorization notification is sent

#### Scenario: Request still waiting after the delay
- **WHEN** an authorization request is still unresolved 30 seconds after it was raised
- **THEN** exactly one authorization notification is sent for that wait

#### Scenario: Delay set to zero
- **WHEN** `NOTIFY_AUTHORIZATION_DELAY_SECONDS=0` and an authorization request is raised
- **THEN** the authorization notification is sent without waiting

#### Scenario: Category disabled
- **WHEN** the authorization category is disabled
- **THEN** no delayed check is started and no authorization notification is sent

### Requirement: Each tool has a start signal and still-waiting evidence
The start signal SHALL be the `permission_prompt` Notification for Claude Code, the PermissionRequest hook for Codex, and a `tool_confirmation_pending` status of true for Antigravity. Still-waiting evidence SHALL be: for Claude Code, the session record shows the requested tool call without a result; for Codex, the runtime waiting-for-approval flag, or the session record when the runtime cannot be queried; for Antigravity, a pending confirmation that has not been cleared.

#### Scenario: Claude Code permission prompt answered
- **WHEN** Claude Code raises a `permission_prompt` and the session record shows the tool result before the delay ends
- **THEN** no authorization notification is sent

#### Scenario: Codex automatic review approves
- **WHEN** Codex raises a PermissionRequest and its automatic reviewer approves it before the delay ends
- **THEN** no authorization notification is sent

#### Scenario: Codex runtime cannot be queried
- **WHEN** the Codex runtime cannot be queried and the session record still shows the request without a result after the delay
- **THEN** one authorization notification is sent

#### Scenario: Antigravity confirmation cleared
- **WHEN** Antigravity reports `tool_confirmation_pending` false before the delay ends
- **THEN** the pending wait is cleared and no authorization notification is sent

### Requirement: One notification per continuous wait
The hook SHALL send at most one authorization notification for one continuous wait of a session, however many signals arrive during it. After the wait is resolved, a later wait of the same session SHALL be able to notify again. Waits of different sessions SHALL be tracked independently.

#### Scenario: Repeated signals during one wait
- **WHEN** the same pending authorization is signalled several times before it is resolved
- **THEN** at most one authorization notification is sent

#### Scenario: Second wait after resolution
- **WHEN** a wait is resolved and the same session later waits again past the delay
- **THEN** a second authorization notification is sent

#### Scenario: Two sessions wait at once
- **WHEN** two sessions each wait past the delay
- **THEN** each session produces its own notification

### Requirement: Unverifiable waits are reported, not dropped
When the delay has passed and no still-waiting evidence can be read for the session, the hook SHALL send the authorization notification. A missed real wait is worse than a rare extra notice.

#### Scenario: Session record is unreadable
- **WHEN** the delay has passed and neither the runtime nor the session record can be read
- **THEN** the authorization notification is sent

### Requirement: Authorization notices stay within the privacy boundary
An authorization notification SHALL contain only the tool name, project, session label, time, and a generic label of the requesting tool. It MUST NOT contain the command, tool arguments, prompt text, or transcript content read while checking the wait.

#### Scenario: Request carries a command
- **WHEN** the pending request is a shell command with arguments
- **THEN** the notification names the requesting tool and does not contain the command or its arguments

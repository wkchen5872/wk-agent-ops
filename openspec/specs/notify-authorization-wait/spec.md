# notify-authorization-wait Specification

## Purpose

Tell the user when an agent is really stopped waiting for their authorization, instead of every time an authorization request is raised. A request that an automatic reviewer or the user resolves quickly produces no notification.

## Requirements

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

### Requirement: Each tool has a start signal and confirming evidence
The start signal SHALL be the `permission_prompt` Notification for Claude Code, the PermissionRequest hook for Codex, and a `tool_confirmation_pending` status of true for Antigravity. Confirming evidence SHALL be: for Claude Code, the session record shows the requested tool call without a result; for Codex, the runtime waiting-for-approval flag; for Antigravity, a pending confirmation that has not been cleared.

#### Scenario: Claude Code permission prompt answered
- **WHEN** Claude Code raises a `permission_prompt` and the session record shows the tool result before the delay ends
- **THEN** no authorization notification is sent

#### Scenario: Codex automatic review approves
- **WHEN** the Codex runtime can be queried, Codex raises a PermissionRequest, and its automatic reviewer approves it before the delay ends
- **THEN** no authorization notification is sent, however long the approved command then runs

#### Scenario: Codex waits for the user
- **WHEN** the Codex runtime reports the waiting-for-approval flag continuously past the delay
- **THEN** one confirmed authorization notification is sent

#### Scenario: Codex request finishes while the runtime is unavailable
- **WHEN** the Codex runtime cannot be queried and the session record shows the request's result before the delay ends
- **THEN** no authorization notification is sent

#### Scenario: Antigravity confirmation cleared
- **WHEN** Antigravity stops reporting `tool_confirmation_pending` as true (false, or the field is absent) before the delay ends
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

### Requirement: A Codex session record alone does not confirm a wait
A Codex session record that shows no result for a request SHALL NOT be treated as confirming evidence, because it cannot tell an approved command that is still running from a request that waits for approval. A recorded result SHALL still count as resolution.

#### Scenario: Record without a result and no runtime
- **WHEN** only the session record is available and it shows the request without a result after the delay
- **THEN** the wait is handled as unconfirmed, not as confirmed

### Requirement: Waits that cannot be confirmed are reported as unconfirmed
When the delay has passed, the wait has not been shown to be resolved, and no confirming evidence can be read, the hook SHALL send one notification that says the agent may be waiting for authorization and that this could not be confirmed. It MUST NOT use the wording of a confirmed wait. This is the accepted exception to notifying only on confirmed waits: a missed real wait is worse than a rare extra notice.

#### Scenario: Real wait while the Codex runtime is unavailable
- **WHEN** the Codex runtime cannot be queried, the user has not approved, and the session record shows no result after the delay
- **THEN** one unconfirmed authorization notification is sent

#### Scenario: Approved command still running while the runtime is unavailable
- **WHEN** the Codex runtime cannot be queried, the request was approved after 6 seconds, and its command is still running after the delay
- **THEN** one unconfirmed authorization notification is sent, and it does not claim the agent is waiting

#### Scenario: Session record is unreadable
- **WHEN** the delay has passed and neither the runtime nor the session record can be read
- **THEN** one unconfirmed authorization notification is sent

#### Scenario: Confirmed wait keeps the confirmed wording
- **WHEN** confirming evidence shows the wait is still pending after the delay
- **THEN** the confirmed authorization notification is sent, not the unconfirmed one

### Requirement: A delayed check acts only on the wait that started it
Each wait SHALL have its own identity: the request identifier when the tool exposes one, otherwise an identity created when a start signal arrives and the session has no wait on record. A delayed check SHALL send or clear only the wait it was started for, and SHALL compare the identity and act as one step that a concurrent start signal cannot interleave. It MUST NOT notify early for a later wait or clear a later wait.

#### Scenario: Notified, resolved, then waiting again
- **WHEN** a wait was notified, the user answered it, and the same session raises a new authorization request
- **THEN** the new request starts its own delay and is notified if it is still waiting after that delay

#### Scenario: Second wait starts before the first timer ends
- **WHEN** a first wait is resolved after 5 seconds, a second wait starts after 10 seconds, and the delay is 30 seconds
- **THEN** nothing is sent at 30 seconds, and the second wait is notified at 40 seconds if it is still waiting

#### Scenario: Earlier check does not clear a later wait
- **WHEN** the delayed check of a resolved first wait runs while a second wait is pending
- **THEN** the second wait's pending state is unchanged

#### Scenario: Same request signalled again
- **WHEN** a start signal arrives for a request that is already pending
- **THEN** the pending wait keeps its identity and its original start time

#### Scenario: Wait replaced while its check is deciding
- **WHEN** a start signal with a different request identifier arrives at the moment an earlier wait's check has matched its identity
- **THEN** either the check finishes for the earlier wait before the replacement, or it sees the replacement and does nothing; the new wait is never notified or cleared by it

### Requirement: Waits without a request identifier are merged until cleared
When the tool exposes no request identifier, a start signal that arrives while the session has a wait on record SHALL be treated as the same wait: it MUST NOT change the identity, restart the delay, or cause another notification. Such a wait SHALL be cleared by evidence of resolution or by the end of the turn. A wait that has not been notified MUST NOT be cleared or restarted because of its age.

#### Scenario: Repeated signal does not postpone the notice
- **WHEN** start signals without an identifier arrive at 0 and 10 seconds with no resolution between them and the delay is 30 seconds
- **THEN** one notification is sent at 30 seconds, not at 40

#### Scenario: Signals keep repeating
- **WHEN** start signals without an identifier arrive every 10 seconds for two minutes with no resolution
- **THEN** exactly one notification is sent, at 30 seconds

#### Scenario: Second wait without a resolution signal
- **WHEN** a wait without an identifier was notified, no resolution evidence arrives, and a start signal arrives 60 seconds later
- **THEN** no second notification is sent

#### Scenario: Pending wait is never aged out
- **WHEN** a wait without an identifier has not been notified and start signals keep arriving
- **THEN** its identity and start time stay the same until its delayed check runs

#### Scenario: Resolution evidence re-arms at once
- **WHEN** a wait without an identifier is cleared by evidence of resolution and a start signal arrives 5 seconds later
- **THEN** a new wait begins with its own delay

### Requirement: A notified wait without an identifier re-arms after an interval
For a wait without a request identifier that has already been notified, a start signal that arrives at least `NOTIFY_AUTHORIZATION_REARM_SECONDS` after that notification, default 600, SHALL begin a new wait with its own delay. The interval SHALL be counted from the notification, never from the start of the wait, and SHALL apply only to notified waits. A non-numeric or negative value SHALL be treated as the default; no relation to the delay is required.

#### Scenario: Re-arm after the interval
- **WHEN** a wait was notified 600 seconds ago with the default interval and a start signal arrives
- **THEN** a new wait begins and is notified if it is still waiting after its own delay

#### Scenario: Signal before the interval ends
- **WHEN** a wait was notified 599 seconds ago with the default interval and a start signal arrives
- **THEN** it is merged into the notified wait and nothing is sent

#### Scenario: Interval shorter than the delay
- **WHEN** the delay is 30 seconds, the interval is 10 seconds, and start signals arrive every 11 seconds with no resolution
- **THEN** the first notification is sent at 30 seconds and none is sent before it

#### Scenario: Interval equal to the delay
- **WHEN** the delay and the interval are both 30 seconds and start signals arrive every 10 seconds with no resolution
- **THEN** the first notification is sent at 30 seconds

#### Scenario: Delay longer than the default interval
- **WHEN** the delay is 900 seconds, the interval is the default 600, and start signals keep arriving with no resolution
- **THEN** the first notification is sent at 900 seconds

#### Scenario: Reminder after re-arming
- **WHEN** the delay is 30 seconds, the interval is 10 seconds, a wait was notified at 30 seconds, and the next start signal arrives at 44 seconds with no resolution
- **THEN** a new wait begins at 44 seconds and is notified at 74 seconds

#### Scenario: Invalid interval
- **WHEN** `NOTIFY_AUTHORIZATION_REARM_SECONDS` is `abc` or `-5`
- **THEN** the default of 600 seconds is used

### Requirement: Waits are cleared by evidence of resolution
A pending wait SHALL be cleared when its request has a recorded result, when the tool reports that the confirmation is no longer pending, or when the session's turn ends. A wait that was already notified SHALL be cleared the same way, so the next wait of that session can notify.

#### Scenario: Claude Code prompt answered without a later signal
- **WHEN** a notified Claude Code wait is answered and the session later stops
- **THEN** the wait is cleared and a later permission prompt of that session can notify

#### Scenario: Codex turn ends
- **WHEN** the Codex turn that raised the request completes or is cancelled
- **THEN** its pending wait is cleared without a notification

#### Scenario: Antigravity conversation stops
- **WHEN** an Antigravity conversation with a pending confirmation stops
- **THEN** its pending wait is cleared

### Requirement: Authorization notices stay within the privacy boundary
An authorization notification SHALL contain only the tool name, project, session label, time, and a generic label of the requesting tool. It MUST NOT contain the command, tool arguments, prompt text, or transcript content read while checking the wait.

#### Scenario: Request carries a command
- **WHEN** the pending request is a shell command with arguments
- **THEN** the notification names the requesting tool and does not contain the command or its arguments

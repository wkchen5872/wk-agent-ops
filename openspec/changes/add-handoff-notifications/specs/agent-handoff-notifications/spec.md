# Spec Delta

## Purpose

Let the user follow a handoff loop from their notifications: which step just finished, which agent did it, what happens next, and when the loop is waiting for them.

## ADDED Requirements

### Requirement: Each handoff step produces a notification kind
When the routing hook processes a handoff record, it SHALL notify the user with one of four kinds: implementation handed over, review result, finish completed, or attention needed. An `implement`/`done` record SHALL produce the first, a `review`/`done` record with `changes-required` or `pass` the second, and a `finish`/`done` record the third. Each record SHALL produce at most one progress notification and at most one attention notification, however many times the hook runs for it.

#### Scenario: Implementer hands over
- **WHEN** an `implement`/`done` record is routed to the reviewer
- **THEN** the user receives an implementation notification naming the change and the round

#### Scenario: Review asks for changes
- **WHEN** a `changes-required` review is routed to the implementer
- **THEN** the user receives a review notification saying round N needs changes

#### Scenario: Finish completes
- **WHEN** a `finish`/`done` record is processed
- **THEN** the user receives a finish notification

#### Scenario: Record processed twice
- **WHEN** an agent stops again without writing a new record
- **THEN** no second notification is sent for the already processed record

#### Scenario: Pass that waits for the user, hook runs twice
- **WHEN** a passing review with the finish trigger `ask` has been notified and the hook runs again for the same record
- **THEN** no second notification is sent

#### Scenario: Blocked record, hook runs twice
- **WHEN** a `blocked` record has been notified and the hook runs again for the same record
- **THEN** no second notification is sent

### Requirement: Progress notifications have switches
`NOTIFY_HANDOFF_IMPLEMENT`, `NOTIFY_HANDOFF_REVIEW`, and `NOTIFY_HANDOFF_FINISH` SHALL enable or disable the implementation, review, and finish notifications. A missing key SHALL count as enabled. Disabling a switch MUST NOT change routing between agents.

#### Scenario: Review notifications turned off
- **WHEN** `NOTIFY_HANDOFF_REVIEW=false` and a `changes-required` review is routed
- **THEN** the implementer is still asked to fix and the user receives no review notification

#### Scenario: Keys absent
- **WHEN** the config holds none of the three keys
- **THEN** implementation, review, and finish notifications are all sent

#### Scenario: Other switches unaffected
- **WHEN** only `NOTIFY_HANDOFF_IMPLEMENT=false`
- **THEN** review and finish notifications are still sent

### Requirement: Notices that need the user cannot be switched off
The hook SHALL send an attention notification, whatever the three switches say, when the loop cannot continue without the user: a `blocked` status or verdict, the round limit, a worktree that is not clean or not at the recorded head, a reviewer or review worktree that cannot be opened or moved, a handoff message that could not be delivered, an unreadable record, a refused or stopped finish, and a passing review that waits for the user to run `handoff-finish`.

#### Scenario: Pass waits for the user
- **WHEN** a review passes, the finish trigger is `ask`, and `NOTIFY_HANDOFF_REVIEW=false`
- **THEN** the user still receives a notification telling them to run `handoff-finish <change-id>`

#### Scenario: Review is blocked
- **WHEN** a review record has `status: blocked` and all three switches are off
- **THEN** the user receives an attention notification with the record's note

#### Scenario: Round limit reached
- **WHEN** the review that reaches `max_rounds` returns `changes-required`
- **THEN** the user receives an attention notification and the implementer receives no message

#### Scenario: Pass with automatic finish
- **WHEN** a review passes, the finish trigger is `auto`, and `NOTIFY_HANDOFF_REVIEW=false`
- **THEN** the finish session is opened and no review notification is sent

### Requirement: An undelivered handoff is not announced as progress
A progress notification SHALL be sent only after the routing action for the record succeeded. When the message to the reviewer or the implementer could not be delivered, the hook SHALL send no implementation or review notification for that record and SHALL send one attention notification that names the agent that could not be reached and how to retry. It SHALL send that attention notification at most once per record, however many retries fail.

#### Scenario: Reviewer cannot be messaged
- **WHEN** an `implement`/`done` record is processed and the message to the existing reviewer fails
- **THEN** no implementation notification is sent and the user receives an attention notification saying the reviewer was not reached

#### Scenario: Implementer cannot be messaged
- **WHEN** a `changes-required` review is processed and the message to the implementer fails
- **THEN** no review notification is sent and the user receives an attention notification saying the implementer was not reached

#### Scenario: Retry fails again
- **WHEN** a later hook run retries the same record and delivery fails again
- **THEN** no second attention notification is sent for that record

#### Scenario: Retry succeeds
- **WHEN** a later hook run retries the record and the message is delivered
- **THEN** the progress notification for that record is sent once

### Requirement: Notices reach the user during a mixed deployment
The handoff hook SHALL send handoff events only when the notification hook that will actually run declares support for them. It SHALL decide this from that hook itself, not from other deployed files. Otherwise it SHALL send attention notices through the previous generic notification path, so they are still delivered, and SHALL skip progress notices. Either installer MAY be deployed or rolled back first.

#### Scenario: New handoff hook with an older notification hook
- **WHEN** the notification hook does not support handoff events and a review passes with the finish trigger `ask`
- **THEN** the user receives the notice to run `handoff-finish <change-id>` through the generic notification path

#### Scenario: Blocked record with an older notification hook
- **WHEN** the notification hook does not support handoff events and a record is `blocked`
- **THEN** the user receives the blocked notice through the generic notification path

#### Scenario: Progress with an older notification hook
- **WHEN** the notification hook does not support handoff events and an `implement`/`done` record is routed
- **THEN** routing happens as usual and no progress notice is sent

#### Scenario: Notification hook rolled back
- **WHEN** the notification hook is rolled back to a version without handoff events while the new handoff hook stays installed
- **THEN** attention notices are still delivered through the generic notification path

#### Scenario: Rollback leaves newer data files behind
- **WHEN** the notification hook is rolled back by an older installer that leaves the newer event table and templates in place, and a review passes with the finish trigger `ask`
- **THEN** the handoff hook uses the generic notification path and the user receives the notice

#### Scenario: Blocked record after such a rollback
- **WHEN** the same rolled-back state holds and a record is `blocked`
- **THEN** the user receives the blocked notice through the generic notification path

### Requirement: Notifications name the agent that wrote the record
A handoff notification SHALL show the tool, model, and effort of the session that wrote the record, as Xirp reports them when the record is processed, in the form `Agent Handoff (<tool> / <model> / <effort>)`. A part that Xirp does not report SHALL be omitted, and with no part known the label SHALL be `Agent Handoff`.

#### Scenario: All parts known
- **WHEN** the record was written by a Claude Code session running `claude-opus-5-5` at effort `high`
- **THEN** the notification shows `Agent Handoff (Claude / claude-opus-5-5 / high)`

#### Scenario: Effort unknown
- **WHEN** Xirp reports the tool and model but no effort
- **THEN** the notification shows `Agent Handoff (Codex / gpt-6.1-sol)`

#### Scenario: Model changed during the session
- **WHEN** the user switched the session's model before it stopped
- **THEN** the notification shows the model in use when the record was processed

#### Scenario: Agent values contain formatting characters
- **WHEN** the reported model or effort contains `_` or `*`
- **THEN** the notification shows those characters literally

### Requirement: Notifications say what happened and what comes next
A handoff notification SHALL have a title for its kind, the change, the round, the commit shortened to seven characters when the record has one, and one line saying what happens next or what the user must do. Its title SHALL carry the same session label as that session's ordinary notifications.

#### Scenario: Implementation handed over
- **WHEN** round 2 of `add-export` is handed to the reviewer at commit `3f2a91c0d4e5`
- **THEN** the notification shows the change, round 2, commit `3f2a91c`, and that the reviewer was asked to review

#### Scenario: Pass waits for the user
- **WHEN** a review passes with the finish trigger `ask`
- **THEN** the next-step line is the command `handoff-finish <change-id>`

#### Scenario: Finish stopped
- **WHEN** a `finish`/`blocked` record is processed
- **THEN** the notification shows the record's note and that `handoff-finish <change-id>` retries after the cause is fixed

### Requirement: Handoff notifications never disturb routing
Handoff notifications SHALL be sent after the routing action for the record, SHALL add no polling or model call, and MUST NOT write to GitHub. A failure to read agent information or to deliver the notification SHALL NOT change routing or the hook's success status. Ordinary completion notifications of the same session SHALL remain unchanged.

#### Scenario: Xirp cannot report the session
- **WHEN** agent information cannot be read
- **THEN** the record is routed as usual and the notification is sent without the agent parts

#### Scenario: Telegram is disabled
- **WHEN** Telegram delivery is disabled
- **THEN** routing happens exactly as before and the hook exits successfully

#### Scenario: Completion notice still sent
- **WHEN** an implementer stops after writing its record and both completion and implementation notifications are enabled
- **THEN** the user receives the ordinary completion notification and the implementation notification

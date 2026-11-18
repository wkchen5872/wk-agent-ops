# Spec Delta

## Purpose

Let the user follow a handoff loop from their notifications: which step just finished, which agent did it, what happens next, and when the loop is waiting for them.

## ADDED Requirements

### Requirement: Each handoff step produces a notification kind
When the routing hook processes a handoff record, it SHALL notify the user with one of four kinds: implementation handed over, review result, finish completed, or attention needed. An `implement`/`done` record SHALL produce the first, a `review`/`done` record with `changes-required` or `pass` the second, and a `finish`/`done` record the third. Each record SHALL produce at most one notification.

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
The hook SHALL send an attention notification, whatever the three switches say, when the loop cannot continue without the user: a `blocked` status or verdict, the round limit, a worktree that is not clean or not at the recorded head, a reviewer or review worktree that cannot be opened or moved, an unreadable record, a refused or stopped finish, and a passing review that waits for the user to run `handoff-finish`.

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

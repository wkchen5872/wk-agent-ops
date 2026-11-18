# Spec Delta

## ADDED Requirements

### Requirement: An undelivered handoff stays unprocessed
When the hook cannot deliver the message that hands a record to the reviewer or the implementer, it SHALL NOT mark the record as processed and SHALL NOT report the handoff as delivered in the routing log. A later hook run in that worktree, or a manual foreground run of the hook, SHALL retry the delivery. The hook SHALL still exit successfully.

#### Scenario: Message to the reviewer fails
- **WHEN** an `implement`/`done` record is processed and Xirp fails to deliver the message to the existing reviewer
- **THEN** the record is not marked as processed, the routing log records a failed delivery, and the hook exits successfully

#### Scenario: Message to the implementer fails
- **WHEN** a `changes-required` review is processed and Xirp fails to deliver the message to the implementer
- **THEN** the record is not marked as processed and the implementer is not reported as asked

#### Scenario: Later run retries
- **WHEN** the hook runs again for a record whose delivery failed and Xirp now delivers the message
- **THEN** the message is sent once and the record is marked as processed

#### Scenario: Manual retry
- **WHEN** the user runs the hook in the foreground from the worktree that holds the undelivered record
- **THEN** the delivery is retried without waiting for an agent to stop

### Requirement: A record that stops for the user is processed once
A record whose outcome is a stop for the user — a `blocked` status or verdict, the round limit, any `finish` record, a passing review that waits for `handoff-finish`, a worktree that is not clean or not at the recorded head, or an unreadable record — SHALL be marked as processed after the user was notified. Later hook runs MUST NOT notify or route it again. Only a failed delivery or a failed attempt to open a session or prepare the review worktree SHALL leave a record unprocessed for retry.

#### Scenario: Pass that waits for the user
- **WHEN** a passing review with the finish trigger `ask` is processed and the agent later stops again without a new record
- **THEN** the record is already marked as processed and nothing is sent

#### Scenario: Blocked record
- **WHEN** a `blocked` record is processed twice
- **THEN** the second run does nothing

#### Scenario: Reviewer session cannot be opened
- **WHEN** the first review session cannot be opened for an `implement`/`done` record
- **THEN** the record stays unprocessed and a later run tries to open the reviewer again


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

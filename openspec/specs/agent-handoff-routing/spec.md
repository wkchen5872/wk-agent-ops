# agent-handoff-routing Specification

## Purpose

Route work between the implementer, reviewer, and finish agents when an agent stops, using handoff records and the loop configuration, without polling, without a model, and without writing to GitHub.

## Requirements

### Requirement: Routing runs when an agent stops
A Stop hook SHALL run when a Claude Code or Codex agent stops. It SHALL act only on the newest handoff record in the stopping agent's worktree that it has not processed, and SHALL exit without any action when there is no such record or no `loop.yaml` for that change.

#### Scenario: Agent stops after an ordinary question
- **WHEN** an agent stops after answering a question and wrote no new handoff record
- **THEN** the hook sends nothing and exits successfully

#### Scenario: Agent stops after recording a handoff
- **WHEN** an agent stops and a new handoff record exists for a change with a `loop.yaml`
- **THEN** the hook routes that record exactly once

### Requirement: Records are routed by role, status, and verdict
The hook SHALL route an `implement`/`done` record to the reviewer, a `review`/`done`/`changes-required` record within the round limit to the implementer, a `review`/`done`/`pass` record according to the finish trigger, and every `finish` record to the user. Any `blocked` status or verdict SHALL be sent to the user only, whatever the technical verdict.

#### Scenario: Implementation is handed to review
- **WHEN** the newest record is `role: implement`, `status: done`
- **THEN** the reviewer is asked to review the recorded `head`

#### Scenario: Review asks for changes
- **WHEN** the newest record is `verdict: changes-required` and the round limit is not exceeded
- **THEN** the implementer is asked to fix according to the record's `report` path

#### Scenario: Work is blocked
- **WHEN** the newest record has `status: blocked` or `verdict: blocked`
- **THEN** the user is notified and no agent is asked to continue

#### Scenario: Blocked publication keeps the technical verdict from routing
- **WHEN** the newest record is `role: review`, `status: blocked`, `verdict: changes-required`
- **THEN** only the user is notified and the implementer receives no message

#### Scenario: Finish records only inform the user
- **WHEN** the newest record is `role: finish` with `status: done` or `status: blocked`
- **THEN** the user is notified of the outcome and no session is started or messaged

### Requirement: Messages point to evidence instead of restating it
Messages sent to an agent SHALL identify the change, the round, the commit to act on, and the absolute path of the report when one exists, and MUST NOT copy or paraphrase the review report's content.

#### Scenario: Repair request carries only references
- **WHEN** the hook asks the implementer to fix a `changes-required` review
- **THEN** the message names the change, round, reviewed `head`, and report path, and contains no summary of the findings

### Requirement: The round limit stops automatic repair
When a `changes-required` review would start a round beyond `max_rounds` in `loop.yaml` (default 3), the hook SHALL notify the user instead of asking the implementer to continue.

#### Scenario: Fourth repair round is not started automatically
- **WHEN** the third review in a loop with `max_rounds: 3` returns `changes-required`
- **THEN** the user is notified that the round limit was reached and the implementer receives no message

### Requirement: Handoffs require a clean worktree at the recorded head
Before routing, the hook SHALL check that the `HEAD` of the worktree holding the record equals the record's `head` and that this worktree has no uncommitted changes to tracked or untracked non-ignored files. If either check fails, it SHALL notify the user and MUST NOT route the record.

#### Scenario: Implementer left changes uncommitted
- **WHEN** an implement record names `head` X but the worktree has uncommitted changes
- **THEN** the user is notified of the unclean handoff and the reviewer is not asked to review

#### Scenario: Reviewer modified files
- **WHEN** a review record is written but the shared worktree has new uncommitted changes
- **THEN** the user is notified and the implementer is not asked to continue

### Requirement: The first review opens the reviewer
On the first `implement`/`done` record of a loop, the hook SHALL start the reviewer session from the recorded review template, unless an existing reviewer session is recorded, and SHALL record the reviewer in `loop.yaml`. With `worktree: shared` the reviewer works in the implementer's worktree; with `worktree: new` the hook first creates a detached review worktree at the recorded `head`. Later rounds SHALL message the same reviewer.

#### Scenario: Separate review worktree is prepared
- **WHEN** the review template sets `worktree: new` and the implementer hands over commit X
- **THEN** a review worktree is created detached at X, both copies of `loop.yaml` list it, and the reviewer session opens there

#### Scenario: Reviewer session is created once
- **WHEN** the implementer hands over round 1 and no reviewer is recorded
- **THEN** one reviewer session is started from the review template and recorded in `loop.yaml`
- **AND** the next implement handoff is sent to that same session

### Requirement: A separate review worktree is moved to each new handoff
In a loop with a separate review worktree, before asking the reviewer to review a later implement record, the hook SHALL confirm that the review worktree has no uncommitted non-ignored changes and then check it out detached at the record's `head`. If the review worktree is not clean, the hook SHALL notify the user and MUST NOT move it or message the reviewer.

#### Scenario: Two rounds across two worktrees
- **WHEN** the implementer in A hands over X, the reviewer in B returns `changes-required` with a report saved under B, the implementer reads that report by its absolute path, commits Y in A, and hands over again
- **THEN** B is moved to Y before the reviewer is messaged, the second review is bound to Y, the records are numbered 01 to 04 across A and B, and a final `pass` in B lets `handoff-finish` run from A

#### Scenario: Reviewer left changes in its worktree
- **WHEN** a new implement record arrives and the review worktree has uncommitted changes
- **THEN** the user is notified and the review worktree is not moved

### Requirement: Finish follows the configured trigger
On a `review`/`pass` record, the hook SHALL start the finish session from the finish template when `finish.trigger` is `auto`, and SHALL only notify the user that the review passed when it is `ask`. The default SHALL be `ask`.

#### Scenario: Default waits for the user
- **WHEN** a review passes in a loop with the default finish trigger
- **THEN** the user is notified and no finish session is started

#### Scenario: Automatic finish
- **WHEN** a review passes in a loop with `finish.trigger: auto`
- **THEN** a finish session is started from the finish template

### Requirement: Routing never writes to GitHub
The hook MUST NOT create, edit, reply to, or close any GitHub Issue or pull request, and MUST NOT push. GitHub writes remain inside the skills that own them.

#### Scenario: A PR exists for the change
- **WHEN** a review record is routed for a change that has an open pull request
- **THEN** the hook makes no GitHub API call

### Requirement: Routing is idempotent and fails silently
The hook SHALL record which handoff records it has processed and MUST NOT send a second message for the same record. Any error SHALL end the hook with success status and without affecting the agent. When Xirp is unavailable, the hook SHALL do nothing.

#### Scenario: Agent stops twice after one record
- **WHEN** an agent stops again without writing a new record
- **THEN** no message is sent for the already processed record

#### Scenario: Xirp is not installed
- **WHEN** the hook runs on a machine without the `xirp` command
- **THEN** it exits successfully without sending anything

### Requirement: Each routing step records the session's actual model
When the hook processes a record, it SHALL append to a routing log in the change directory the record file, the action taken, and the stopping session's identifiers and model as reported by Xirp at that moment.

#### Scenario: Model changed during the session
- **WHEN** the user switched the implementer to another model before it stopped
- **THEN** the routing log shows the model in use when that record was processed

### Requirement: The hook is installed for supported providers
An installer SHALL register the Stop hook for Claude Code and Codex idempotently, and SHALL tell the user that Codex requires trusting the new hook once. It MUST NOT mark the hook as trusted on the user's behalf.

#### Scenario: Installer runs twice
- **WHEN** the installer is run a second time
- **THEN** each provider has exactly one registration of the Stop hook

#### Scenario: Codex trust is left to the user
- **WHEN** the installer registers the Codex hook
- **THEN** it prints that the hook must be trusted in Codex and does not edit Codex trust state

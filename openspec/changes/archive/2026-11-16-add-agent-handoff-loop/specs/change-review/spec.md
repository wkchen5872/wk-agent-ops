# Spec Delta

## ADDED Requirements

### Requirement: Loop reviews are pinned to the handed-over commit
When the review target has an active handoff loop and the review is an implementation-round review, the review SHALL be bound to the `head` of the newest implement record. Before reviewing, the workflow SHALL confirm that the worktree's `HEAD` equals that commit and that the worktree has no uncommitted non-ignored changes; otherwise the result SHALL be `blocked` with the mismatch as evidence.

#### Scenario: Review starts on the handed-over commit
- **WHEN** the newest implement record names commit X and the shared worktree is clean at X
- **THEN** the review records X as the reviewed version without computing a file snapshot

#### Scenario: Worktree moved after the handoff
- **WHEN** the worktree's `HEAD` differs from the implement record's `head`
- **THEN** the review result is `blocked` and states both commits

### Requirement: Loop reviews end with a handoff record
At the end of an implementation-round review in an active loop, the workflow SHALL record the result with `handoff-write` as a `review` record carrying the verdict, the reviewed `head`, and the saved report path, after the report is saved and, when a PR is confirmed, after its publication state is known.

#### Scenario: Changes required with a PR
- **WHEN** a loop review on a confirmed PR returns `changes-required`
- **THEN** the report is posted and read back through the PR reply entry before the review record is written
- **AND** the record's `report` points to the saved local report

### Requirement: Unconfirmed publication blocks routing
In an active loop on a confirmed PR, if posting the report is denied, times out, or its readback does not match, the review record SHALL have `status: blocked`, keep the technical verdict, and state the publication state in `note`. The workflow MUST NOT resend blindly or turn the failure into a local handoff.

#### Scenario: Reply times out
- **WHEN** a loop review's technical verdict is `changes-required` and the PR reply times out without a matching readback
- **THEN** the review record is `status: blocked`, `verdict: changes-required`, and its note says publication is unconfirmed

#### Scenario: Reply is denied
- **WHEN** posting the reply is denied
- **THEN** the review record is `status: blocked` and no second posting tool is tried

### Requirement: Loop routing honours local-only and notification exclusions
Starting a loop SHALL NOT override a round's explicit instruction. A review marked local-only, or with notification excluded, SHALL save the report locally and write `status: blocked` with the reason in `note`. Local-only combined with a handoff request SHALL be treated the same until the user resolves the conflict. Only an explicit instruction to skip GitHub but hand the result to the implementer SHALL write `status: done` with the local report path.

#### Scenario: Local-only review in a loop
- **WHEN** a loop is running and the user asks for a local-only review that returns `changes-required`
- **THEN** nothing is posted, the record is `status: blocked` with local-only in its note, and the implementer receives no message

#### Scenario: Local-only with an unresolved handoff request
- **WHEN** the user asks for a local-only review and also asks to hand it over without saying whether local handoff is allowed
- **THEN** the conflict is reported, the record is `status: blocked`, and the implementer receives no message

#### Scenario: Skip GitHub but hand over locally
- **WHEN** the user explicitly says not to post to GitHub but to hand the result to the implementer
- **THEN** nothing is posted, the record is `status: done`, and its `report` is the local report path

#### Scenario: Notification excluded
- **WHEN** the user tells the reviewer not to notify anyone for this review
- **THEN** the record is `status: blocked` and its note states that notification was excluded

### Requirement: Final-version review is bound to the delivered head
A final-version review invoked by the completion workflow during PR delivery SHALL be bound to the delivered head supplied by the caller, SHALL NOT apply the implement-record pin, and SHALL NOT write a handoff record; its verdict and evidence SHALL be returned to the caller.

#### Scenario: Final review of the archive commit
- **WHEN** X passed its loop review and completion produced and pushed commit Y
- **THEN** the final-version review reviews Y without being blocked by the implement record's head X
- **AND** no `review` record is written, so the hook cannot treat it as a new pass

### Requirement: An active loop replaces direct implementer notification
When a handoff loop is active for the reviewed Change, the workflow SHALL NOT discover, verify, or message the implementer itself; routing to the implementer is performed by the handoff hook from the review record. Without an active loop, existing implementer notification requirements remain unchanged.

#### Scenario: Failed review inside a loop
- **WHEN** a review with an active loop returns `changes-required` and the PR reply is confirmed
- **THEN** the workflow writes the review record and sends no session message itself

#### Scenario: Failed review without a loop
- **WHEN** no `loop.yaml` exists for the Change
- **THEN** the workflow follows the existing confirmed-PR-feedback and local-handoff requirements

### Requirement: PR publication may be delegated to the PR agent
The workflow SHALL be allowed to delegate its PR reply to the dedicated PR agent within the same review run, passing the full repository and PR target, the report path, the review ID, the reviewed version, and the reviewer's own identity. Publication evidence and readback requirements SHALL apply unchanged.

#### Scenario: Delegated reply keeps the reviewer as Author
- **WHEN** the reviewer delegates the reply to the PR agent
- **THEN** the posted reply's Author identifies the reviewer session and model, not the PR agent's model

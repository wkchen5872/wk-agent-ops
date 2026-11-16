# Spec Delta

## ADDED Requirements

### Requirement: Loop completion ends with a finish record
When the Change has an active handoff loop, the completion workflow SHALL record a `finish` handoff with `handoff-write` after its final stage outcome is known, with `status: done` when the requested delivery completed and `status: blocked` with the stopping stage otherwise. The record's `head` SHALL be the resulting local commit, or the current `HEAD` when no commit was made.

#### Scenario: Local completion succeeds
- **WHEN** archive, documentation, and commit succeed for a loop with `finish.delivery: local`
- **THEN** a `finish` record with `status: done` and the new commit as `head` is written

#### Scenario: Completion stops early
- **WHEN** the commit gate fails during completion of a loop Change
- **THEN** a `finish` record with `status: blocked` names the failed stage

### Requirement: Loop delivery follows the configured delivery setting
For a Change with an active loop, the completion workflow SHALL treat `finish.delivery: pr` in `loop.yaml` as the request for PR delivery and `local` as local completion only. Remote steps SHALL keep their existing authorization, readback, and final-version review requirements.

#### Scenario: Default delivery stays local
- **WHEN** a loop Change completes with `finish.delivery: local`
- **THEN** no push, PR update, or Closure is attempted

### Requirement: Loop PR delivery requires a passing final-version review of the delivered head
For a loop Change with `finish.delivery: pr`, the Closure SHALL be posted only after the final-version review of the delivered head returns `pass`. The loop review that passed the earlier implement head MUST NOT substitute for it. A final-version result other than `pass` SHALL stop before the Closure and produce a `finish` record with `status: blocked` naming the final-version review.

#### Scenario: Final version passes
- **WHEN** X passed its loop review, completion pushes Y, and the final-version review of Y passes
- **THEN** the Closure is posted and read back, and the finish record is `status: done` with `head: Y`

#### Scenario: Final version needs changes
- **WHEN** the final-version review of Y returns `changes-required` or `blocked`
- **THEN** no Closure is posted and the finish record is `status: blocked` naming the final-version review

### Requirement: PR delivery writes may be delegated to the PR agent
During authorized PR delivery, the completion workflow SHALL be allowed to delegate `github-pr update` and the Closure reply to the dedicated PR agent, passing the target, the delivered head, and the caller's own identity; readback and final-head rules SHALL apply unchanged.

#### Scenario: Delegated Closure keeps the caller as Author
- **WHEN** the finish session delegates the Closure reply
- **THEN** the Closure's Author identifies the finish session and its model

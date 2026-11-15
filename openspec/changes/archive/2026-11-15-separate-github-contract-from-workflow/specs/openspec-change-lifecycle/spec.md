# Spec Delta

## Purpose

Define when an OpenSpec Change may move to its next stage: which user instructions authorize implementation, which stages need their own evidence and authorization, and what happens when approved acceptance criteria change. These rules apply whether or not a GitHub Issue or pull request exists.

## ADDED Requirements

### Requirement: An explicit user instruction authorizes Apply
Apply SHALL require an explicit user instruction that covers the selected Change and its current design, given in the current session or through a traceable handoff. A PR event, a separate approval phrase, a human GitHub account, or a recorder allowlist MUST NOT be required when such an instruction is available. Planning or review requests and technical verdicts MUST NOT authorize Apply. Permission to implement SHALL NOT include permission to publish to GitHub.

#### Scenario: New session starts implementation
- **WHEN** a new session considers applying a Change
- **THEN** it evaluates the available explicit user instruction or traceable handoff against the selected scope and design revision
- **AND** absent, conflicting, scope-incomplete, or superseded authorization is clarified without demanding a PR event when the current instruction is sufficient

#### Scenario: Explicit implementation instruction has no PR event
- **WHEN** the user clearly requests implementation and verification of an identified Change whose design is available and unchanged
- **THEN** the agent continues within that scope without demanding a separate design-approval phrase, human account confirmation, or PR approval comment
- **AND** it does not publish an approval record unless remote publication is separately requested

#### Scenario: Only planning or a technical verdict exists
- **WHEN** the user requested only a Change, a discussion, or a review, or the only evidence is an agent's technical pass
- **THEN** Apply remains unauthorized until there is an explicit user instruction covering implementation

#### Scenario: Design or authorization changes materially
- **WHEN** acceptance criteria or design decisions materially differ from the approved version, or a newer explicit user instruction pauses or withdraws authorization
- **THEN** the affected implementation stops for the changed decision and does not reuse the stale approval
- **AND** work that the change does not affect continues under its existing authorization

### Requirement: Lifecycle stages retain their own evidence and authority
The workflow SHALL distinguish design review, human design approval, implementation review, archive, commit, merge, deployment, real-data acceptance, and Issue closure. It MUST NOT infer a later stage from an earlier one. A review that does not pass SHALL return the work to revision instead of advancing it. Archive MUST NOT be brought forward to close work whose required data acceptance is incomplete.

#### Scenario: Design passes
- **WHEN** a design review reports pass
- **THEN** implementation still requires an explicit user instruction covering it
- **AND** the design result is not represented as implementation acceptance

#### Scenario: Review does not pass
- **WHEN** a design or implementation review reports changes-required or blocked
- **THEN** the work returns to specification revision or repair
- **AND** it does not proceed to the next stage on the implementer's statement alone

#### Scenario: Design pull request is merged
- **WHEN** a pull request containing only the design is merged
- **THEN** the later implementation still needs its own review and acceptance

#### Scenario: Acceptance waits for real data
- **WHEN** required acceptance depends on data that becomes available after a future interval
- **THEN** delivery status and acceptance status are reported separately
- **AND** a review pass, a merge, or the date arriving does not mark acceptance complete, close the Issue, or justify an early archive

### Requirement: Changed acceptance criteria return to OpenSpec
When implementation feedback requires changing approved acceptance criteria, the change SHALL be made in the OpenSpec artifacts and SHALL obtain renewed user direction for the changed decisions before the affected implementation continues. Editing an Issue or pull request alone MUST NOT approve the new criteria.

#### Scenario: Acceptance criteria need changing
- **WHEN** implementation shows that an approved acceptance criterion must change
- **THEN** the OpenSpec artifacts are revised and the user's direction for the new version is obtained before the affected implementation continues
- **AND** text edited only in an Issue or pull request is not treated as approval of the new criterion

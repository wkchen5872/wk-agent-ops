# Spec Delta

## ADDED Requirements

### Requirement: Issue entry holds its own format and write checks
The github-issue skill and its own references SHALL contain everything needed to create, update, and close an Issue: the content frame, Author rules, association and duplicate checks, target and authorization checks before writing, explicit account restrictions, readback, and the reading of legacy formats. Completing an authorized operation MUST NOT require reading the workflow handoff document or another skill's files.

#### Scenario: Only the Issue skill is available
- **WHEN** an agent has the github-issue skill and its references but not the workflow handoff document
- **THEN** it can complete an authorized create, update, or close with the same frame, Author, checks, and readback as before
- **AND** it does not stop to look for an external format document

#### Scenario: A special case needs a complete example
- **WHEN** the post involves a human author, missing Agent metadata, a relayed report, or a legacy format
- **THEN** the skill states that its examples reference is to be read for that case
- **AND** the reference is one of the skill's own files

#### Scenario: Legacy Issue is updated
- **WHEN** an Issue written in an earlier format is updated
- **THEN** the skill's own rules keep the earlier fields readable and append a comment without rewriting the body

## MODIFIED Requirements

### Requirement: Issue-specific rules coexist with shared PR and Review contracts
The github-issue skill SHALL hold Issue bodies, progress, Checkpoint and Closure templates. Issue close SHALL own Issue state changes while PR close SHALL own its PR target. Native safeguards and lifecycle evidence SHALL remain applicable. Formal requirements SHALL stay in OpenSpec, with Issue summaries linking published artifacts and retaining unresolved acceptance work.

#### Scenario: PR description is updated
- **WHEN** github-pr updates its description after this capability is installed
- **THEN** its shared content frame and human or Agent attribution remain in effect

#### Scenario: Acceptance still waits for real data
- **WHEN** the work requires future data for acceptance
- **THEN** the work explanation or update identifies the necessary window, evidence, owner, and next step as relevant
- **AND** a date arriving, a review pass, or a merge does not imply acceptance or close the Issue

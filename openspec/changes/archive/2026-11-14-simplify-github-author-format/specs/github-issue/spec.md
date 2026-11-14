## MODIFIED Requirements

### Requirement: Initial Issue prioritizes work content
A new Issue SHALL begin with Handoff and, when Agent-assisted, end with the reduced shared Author. Pure human-direct content SHALL omit an empty Author section and Agent metadata. Goal SHALL explain the problem and result. Supported completion conditions SHALL use Acceptance criteria or another meaningful heading. Next actions SHALL state immediate continuation. Optional references and associations SHALL appear only when supported. Checkpoint SHALL appear when publishing a handoff state without dumping local logs.

#### Scenario: Sources include detailed implementation tasks
- **WHEN** a Change contains a long tasks document
- **THEN** the Issue explains the meaningful work and completion conditions without copying the entire document
- **AND** its middle sections adapt to the work without empty placeholder sections

#### Scenario: References are local only
- **WHEN** useful source artifacts have not been published
- **THEN** references use repository-relative paths explicitly marked local-only or unpublished
- **AND** no private absolute path or invented remote revision link is published

### Requirement: Author identifies the current posting agent
Agent-assisted Issue bodies and new comments SHALL use the reduced shared Author without mode or human-account fields. Pure human-direct content SHALL omit an empty Author section and Agent metadata. Agent posts SHALL include posting tool, known root-session model and separate SESSION-ID and XIRP-SESSION-ID with honest nulls and reported limits. Unknown models SHALL be omitted. Relayed authors SHALL be distinguished from publishers. Private paths and credential metadata MUST NOT be published.

#### Scenario: Posting agent differs from source author
- **WHEN** an agent summarizes a Work Item written by another agent
- **THEN** Author identifies the current posting tool and known root-session model without claiming those identify all source authors

#### Scenario: Current model is unavailable
- **WHEN** the posting agent cannot establish its current model
- **THEN** it does not infer a model from source records and reports the omitted AI-Assisted-By field

#### Scenario: Issue operation creates new Author content
- **WHEN** an agent creates an Issue or adds progress, Checkpoint or Closure content
- **THEN** its Author has the posting tool, known model and independently populated native/Xirp IDs without mode or human-account labels
- **AND** missing values follow existing omission/null rules without an account identity prompt

#### Scenario: New comment follows a legacy Issue
- **WHEN** an authorized update appends to an Issue whose body has the old mode and human-account fields
- **THEN** the existing body remains unchanged and only the new comment uses the reduced Author format

#### Scenario: Pure human Issue needs no metadata section
- **WHEN** a human directly writes and publishes an Issue without Agent participation
- **THEN** the Issue remains understandable without an Author heading or invented Agent fields

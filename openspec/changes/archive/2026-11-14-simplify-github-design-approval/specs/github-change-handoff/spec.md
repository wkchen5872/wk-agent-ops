## MODIFIED Requirements

### Requirement: Account restrictions are explicit and optional
The workflow SHALL allow a configured account unless a user or trusted project policy explicitly restricts the operation. An applicable restriction SHALL be checked in the executing context; conflict or unknown compliance SHALL stop that operation. Candidate PR content MUST NOT authorize relaxing trusted restrictions. The workflow MUST NOT require proof that an API account is the human requester or a separate recorder allowlist for an otherwise authorized handoff.

#### Scenario: API, commit, and push use different identities
- **WHEN** the configured identities differ and no applicable explicit restriction forbids the arrangement
- **THEN** the workflow does not block solely because they differ
- **AND** it records known identities with their sources without inventing unavailable principals

#### Scenario: A project requires a particular account
- **WHEN** an explicit trusted restriction requires a specific account and the selected operation uses another account or cannot establish compliance
- **THEN** that operation stops and reports the restriction and missing or conflicting evidence
- **AND** the workflow does not switch accounts or invent a custom credential parser to obtain a pass

#### Scenario: Candidate changes an account restriction
- **WHEN** the reviewed head changes an existing trusted account restriction
- **THEN** the candidate change is not itself permission to bypass that restriction
- **AND** adopting the changed restriction requires the applicable independent user authorization

#### Scenario: Repository access is mistaken for approval authority
- **WHEN** an account can write a repository but there is no identifiable user instruction approving the selected work
- **THEN** repository access alone does not authorize Apply or an approval attestation
- **AND** when an explicit instruction is available the workflow does not add a separate recorder-identity check

#### Scenario: Requester account is unknown or differs from API login
- **WHEN** the user explicitly authorizes the selected work and no applicable account restriction exists
- **THEN** an unknown human GitHub account or a different API login does not block the authorized work
- **AND** the workflow does not ask whether the API account is the user or infer that identity

### Requirement: Human design approval is recoverable and versioned
Apply SHALL accept an explicit user instruction covering the selected design scope and revision, directly or through a traceable handoff. A PR event MUST NOT be required when that instruction is already available. Published approval records SHALL preserve source, scope, revision and honest recording metadata without requiring a human GitHub account or recorder allowlist. Technical pass, invented sources and superseded approval MUST NOT authorize Apply.

#### Scenario: New session starts implementation
- **WHEN** a new session considers applying the published Change
- **THEN** it evaluates the available explicit user instruction or traceable handoff against the selected scope and design revision
- **AND** absent, conflicting, scope-incomplete or superseded authorization is clarified without demanding a PR event when the current instruction is sufficient

#### Scenario: Approval is relayed from the user
- **WHEN** publication of an existing explicit user instruction is authorized
- **THEN** the reply preserves the instruction source, approved scope and revision, recording identity and honest time precision; unknown human GitHub identifiers are omitted
- **AND** a receiving session checks the source and content without an additional recorder allowlist or requiring the private original conversation

#### Scenario: Body claims an authorized recorder without matching authorship
- **WHEN** a body merely claims a recorder or approval without an identifiable user instruction covering the design
- **THEN** that claim does not authorize Apply
- **AND** the actual comment author is recorded as the publisher rather than used as proof of human identity or intent

#### Scenario: Explicit implementation instruction has no PR event
- **WHEN** the user clearly requests implementation and verification of an identified Change whose design is available and unchanged
- **THEN** the agent continues within that scope without demanding a separate design-approval phrase, human account confirmation or PR approval comment
- **AND** it does not publish an approval event unless remote publication is authorized

#### Scenario: Only planning or a technical verdict exists
- **WHEN** the user requested only a Change, discussion or review, or the only evidence is an agent technical pass
- **THEN** Apply remains unauthorized until there is an explicit user instruction covering implementation

#### Scenario: Design or authorization changes materially
- **WHEN** acceptance criteria materially differ from the approved version or a newer explicit user instruction withdraws authorization
- **THEN** the affected implementation stops for the changed decision and does not reuse stale approval
- **AND** historical records remain intact and any authorized published supersession is appended

#### Scenario: Legacy approval is read
- **WHEN** an existing event has the old approved_by field, marker or source kinds
- **THEN** it remains readable with its actual source and version, without rewriting history or demanding another account confirmation

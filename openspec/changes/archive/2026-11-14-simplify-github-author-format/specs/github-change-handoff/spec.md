## MODIFIED Requirements

### Requirement: Provenance records known event participants safely
Agent posts SHALL retain current tool, known root-session model and separate native/Xirp IDs, without Author mode or human-account fields or synonymous replacements. Unknown values SHALL remain honest. Pure human-direct posts SHALL omit empty Author sections and Agent metadata. Relayed substantive reports SHALL identify original author and source separately from the posting Agent. Legacy records SHALL remain readable without rewriting history.

#### Scenario: Model or session is unavailable
- **WHEN** the current model or native Session ID is unknown or not approved for disclosure
- **THEN** the workflow reports the omission, uses null for unavailable Session IDs and keeps aliases separate
- **AND** it does not infer a model from history or mislabel an alias as a native ID

#### Scenario: Machine information is recorded
- **WHEN** a record includes machine context
- **THEN** it uses a user-controlled neutral machine alias
- **AND** it does not publish raw hostname, private absolute Work Item paths, credentials, or an invented provider email

#### Scenario: Default remote provenance disclosure
- **WHEN** an Agent-assisted Issue, PR, or Review record is published without a stricter explicit project or user restriction
- **THEN** it retains the executing tool, known model, and known native session ID in dedicated fields
- **AND** unknown values are not guessed and routine posts do not require machine metadata

#### Scenario: Agent posts with reduced Author fields
- **WHEN** an agent creates or updates an Issue or PR body or publishes a review, repair, Checkpoint or Closure reply
- **THEN** Author retains Co-Authored-By, known AI-Assisted-By and both SESSION-ID and XIRP-SESSION-ID
- **AND** it omits the mode and human-account fields without adding synonymous labels or treating the API account as the requester

#### Scenario: A human directly publishes without an agent
- **WHEN** the content is written and published directly by a human without Agent assistance
- **THEN** it has no empty Author section or fabricated Agent fields and retains meaningful work content and Next actions

#### Scenario: Agent publishes on behalf of a human
- **WHEN** a human asks an agent to prepare or publish content
- **THEN** the new content retains that posting Agent's metadata rather than using the human-direct exception

#### Scenario: A substantive report is relayed
- **WHEN** the posting agent relays another author's Review or implementation report
- **THEN** it preserves the original author and verified source separately from its own metadata without requiring a mode label
- **AND** unknown original identity is not invented and a verified publisher alone does not become the implementer

#### Scenario: Old Author contains removed fields
- **WHEN** a consumer reads an existing record containing mode, human-account or old relay markers
- **THEN** it can recover the known source and Session namespaces without rewriting that record or copying removed fields into new output

### Requirement: Team publication uses one shared content frame
The shared contract SHALL own Issue and PR templates for bodies, progress, reviews, fixes, checkpoints and closure. New posts SHALL start with Handoff, explain their purpose and include concise Next actions. Agent-assisted posts SHALL end with the reduced shared Author; pure human-direct posts SHALL omit empty Author sections and Agent metadata. Unknown optional associations and empty optional sections SHALL be omitted. PR bodies SHALL identify the verified head branch. Next actions SHALL state genuine continuation, waiting or no remaining action.

#### Scenario: Human opens unplanned work
- **WHEN** a human publishes a concrete request without a Change or branch
- **THEN** the post has a readable goal, supported completion conditions, Next actions without an empty Author section, Agent metadata or manufactured tracking records

#### Scenario: Agent publishes linked work
- **WHEN** an agent posts with confirmed Change, branch and related Issue or PR
- **THEN** Handoff includes relevant associations and marks a local Work Item local-only

#### Scenario: Next step is unknown
- **WHEN** the sources establish no owner or actionable next step
- **THEN** the post states what needs confirmation without inventing an assignee or deadline

### Requirement: Closure preserves outcome evidence before state mutation
Closing an Issue or PR SHALL first publish and confirm a Handoff, Closure and Next actions summary, with the shared reduced Author for Agent-assisted content and no empty Author for pure human-direct content. Closure SHALL explain intended outcome, delivered or cancelled scope, verification, remaining work and references. Only then SHALL the authorized state change run and be read back. Summaries SHALL NOT attest unperformed close or merge actions. Partial results and retries SHALL be reconciled independently.

#### Scenario: Summary succeeded but close failed
- **WHEN** Closure was confirmed but the state operation failed
- **THEN** the result preserves the summary URL and actual state, and retry reuses unchanged valid evidence

#### Scenario: Summary result is uncertain
- **WHEN** the closure comment times out or cannot be verified
- **THEN** the skill reconciles the comment before closing or posting again

#### Scenario: New work arrives before closing
- **WHEN** the target changes after summary preparation
- **THEN** the skill reconciles scope or version and publishes new closure evidence when needed

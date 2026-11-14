## MODIFIED Requirements

### Requirement: PR formatting uses a minimal frame with optional associations
PR bodies and replies SHALL begin with Handoff and include concise Next actions. Agent-assisted content SHALL end with the reduced shared Author; pure human-direct content SHALL omit empty Author sections and Agent metadata. Handoff SHALL identify the verified head branch. Confirmed work and dependency links SHALL be optional and Work Items marked local-only. Bodies SHALL explain purpose, published changes and actual verification. Review, repair, Checkpoint and Closure replies SHALL use corresponding shared content.

#### Scenario: PR begins without local identifiers
- **WHEN** a published branch has no associated Work Item, Change, or Issue
- **THEN** Handoff contains its verified branch and no empty association fields
- **AND** the body still explains the work without relying on identifiers

#### Scenario: Associations are supplied later
- **WHEN** a later update confirms a Change, Work Item, or directly corresponding Issue
- **THEN** the description can add those associations without creating another PR
- **AND** dependency links remain distinguishable from Issues whose work this PR addresses

#### Scenario: Description follows a newer published version
- **WHEN** an authorized update describes a newer remote head
- **THEN** changes, verification and Next actions match that published version while unrelated human notes and historical reports are preserved

### Requirement: PR Author includes native and Xirp session identifiers independently
Agent-assisted bodies and replies SHALL end with the reduced shared Author without mode or human-account labels. Agent posts SHALL retain tool, known root-session model, SESSION-ID and XIRP-SESSION-ID. Unavailable IDs SHALL independently be null with reasons reported and unknown models omitted. Pure human-direct posts SHALL omit empty Author sections and fabricated Agent metadata. Relayed substantive reports SHALL preserve source authorship separately.

#### Scenario: Both identifiers are available
- **WHEN** the current posting session has verified native and Xirp identifiers
- **THEN** Author publishes both in their dedicated fields without choosing one instead of the other
- **AND** the identifiers refer to the posting session rather than a source record's author

#### Scenario: Only one identifier is available
- **WHEN** the native or Xirp ID cannot be obtained after the applicable lookup
- **THEN** Author retains the known ID and uses null only for the unavailable field
- **AND** the workflow explains the missing value and completes the remaining authorized operation without asking the user to supply an optional ID

#### Scenario: Session metadata is wholly unavailable
- **WHEN** neither identifier is available from the posting runtime or applicable local metadata
- **THEN** both fields are null and the report explains the actual lookup limits
- **AND** no ID is invented and PR creation is not blocked solely by that absence

#### Scenario: Each PR operation writes reduced metadata
- **WHEN** an agent creates or updates a description, or replies with Review, repair, Checkpoint or Closure content
- **THEN** new Author content retains tool, known model and both Session namespaces without mode, human-account or synonymous labels
- **AND** the operation retains its existing target, authorization, Git side-effect and readback boundaries

#### Scenario: Relayed report has only the new source markers
- **WHEN** an implementation or repair report identifies its original author and source without a mode field
- **THEN** the consumer distinguishes the original implementer from the posting agent before any authorized session handoff
- **AND** if only the publisher can be verified the consumer does not notify that publisher as the implementer

#### Scenario: Legacy relay marker is still readable
- **WHEN** an existing implementation record uses the old agent-relay mode marker
- **THEN** consumers preserve source interpretation and existing session verification without rewriting that record
- **AND** any new authorized reply uses the reduced format

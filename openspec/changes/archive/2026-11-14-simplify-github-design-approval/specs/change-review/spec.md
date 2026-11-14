## MODIFIED Requirements

### Requirement: Design review checks implementability and acceptance
Design review SHALL assess requirements, scope, interfaces, dependencies, feasibility, material risks, and executable acceptance criteria. It MUST NOT fail solely because implementation tasks are not yet complete. A technical design pass SHALL remain distinct from human design approval and implementation acceptance.

#### Scenario: Spec-only Draft PR
- **WHEN** a PR contains complete proposed artifacts but no implementation
- **THEN** design review evaluates the proposal and testability without treating unimplemented tasks as implementation failures
- **AND** pass does not authorize Apply without applicable human design approval

#### Scenario: Material acceptance gap
- **WHEN** a required external-data acceptance condition has no defined observation window or pass criterion
- **THEN** design review identifies the concrete acceptance gap with the affected requirement
- **AND** it requests a specification correction rather than inventing a runtime test result

#### Scenario: Approval has date-only precision
- **WHEN** the human approval date is known but its time is not
- **THEN** the reviewer follows the shared contract and preserves YYYY-MM-DD without fabricating a time or replacing it with recorded_at
- **AND** an honestly dated instruction is not rejected for lacking an exact time or a human GitHub account; unknown optional identifiers are omitted

#### Scenario: Approval recorder has access but lacks authorization
- **WHEN** a comment author can write the repository but the content provides no identifiable user instruction authorizing the selected design
- **THEN** repository access and a self-declared recorder name do not authorize Apply
- **AND** review and separately authorized report publication remain possible without introducing a recorder allowlist

#### Scenario: Explicit user instruction already covers implementation
- **WHEN** the current user or a traceable handoff explicitly requests implementation of the identified unchanged design
- **THEN** the workflow recognizes that instruction without requiring another approval phrase, human-account match or PR event
- **AND** it keeps the technical review verdict distinct from the instruction authorizing implementation

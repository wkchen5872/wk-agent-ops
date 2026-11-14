## MODIFIED Requirements

### Requirement: Shared review and approval integrations retain their meaning
The shared handoff contract SHALL own the simplified PR and reply templates, and change-review SHALL use compatible presentation without changing its review criteria. Version binding, finding identity, technical verdicts, and human approval SHALL retain their evidence and authority. Authorized approval replies SHALL be independently discoverable. An available explicit user instruction SHALL NOT require a PR event, human GitHub identifier or separate recorder qualification to authorize its stated work.

#### Scenario: Local record policy is independent of GitHub publication
- **WHEN** GitHub skills read a Work Item as source material
- **THEN** the Work Item policy remains usable without GitHub workflow rules, contract links, or publication fields
- **AND** the GitHub contract defines its own remote review schema and finding states without importing the local record policy

#### Scenario: change-review publishes a new round
- **WHEN** an authorized change-review round posts to a PR
- **THEN** it can publish the simplified reply with the required reviewed version and findings while preserving earlier rounds
- **AND** it does not invoke create, update the PR body, close work, or perform Git writes

#### Scenario: A recorded design approval is needed
- **WHEN** OpenSpec work requires human design approval
- **THEN** the workflow checks the available instruction or published event for its actual source, approved scope and revision without a separate recorder-account qualification
- **AND** technical pass, body edits, and the absence of a mandatory approval block do not confer approval

#### Scenario: Approval reply is requested with an unknown human account
- **WHEN** the user authorizes recording an explicit instruction but their GitHub account is unknown
- **THEN** reply records source, scope, revision and posting metadata without asking whether the API login is the user
- **AND** it omits the unknown human identifier, reads back the result and preserves earlier events

#### Scenario: Apply is requested without publication
- **WHEN** the current user explicitly requests implementation but has not requested a GitHub approval reply
- **THEN** the workflow does not force a reply or block the authorized local work for a missing PR event
- **AND** permission to implement does not implicitly authorize platform writes

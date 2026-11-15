# Spec Delta

## ADDED Requirements

### Requirement: PR entry holds its own format and write checks
The github-pr skill and its own references SHALL contain everything needed to create, update, reply to, and close a pull request, including the description and reply layouts and the review identity rules those replies use. Completing an authorized operation MUST NOT require reading the workflow handoff document or another skill's files.

#### Scenario: Only the PR skill is available
- **WHEN** an agent has the github-pr skill and its references but not the workflow handoff document
- **THEN** it can complete an authorized create, update, reply, or close with the same frame, Author, checks, and readback as before
- **AND** association with existing pull requests, base and head checks, explicit account restrictions, description update rules, and legacy formats come from the skill's own files
- **AND** it does not stop to look for an external format document

#### Scenario: First-round review reply with only the PR skill
- **WHEN** the github-pr skill alone is used to post a first-round review reply with findings
- **THEN** the reply carries the reviewed head, a review ID assigned before publication, the verdict, the phase when it is a design review, and each finding under an `<origin-review-id>/F-NN` ID
- **AND** the agent does not read the review skill or the workflow handoff document to find those rules

#### Scenario: Re-review and fix replies keep finding identity
- **WHEN** a later reply reports fixes or a re-review of earlier findings
- **THEN** each finding keeps its original ID and the stated status follows the Open, Accepted, Rejected, and Resolved meanings
- **AND** an implementer's fix reply does not mark a finding Resolved

#### Scenario: An approval record is recorded or read
- **WHEN** a reply records a design approval or a published approval is looked up
- **THEN** the skill states that its approval-record reference is to be read for that operation
- **AND** other operations do not need that reference

#### Scenario: Another skill publishes through this entry
- **WHEN** a review or completion workflow publishes a reply, an update, or a Closure
- **THEN** it invokes this entry, which supplies the reply frame and write checks
- **AND** the calling skill does not carry a second copy of the reply layout

## MODIFIED Requirements

### Requirement: Shared review and approval integrations retain their meaning
The github-pr skill SHALL hold the PR description and reply templates, including approval records, and change-review SHALL use compatible presentation without changing its review criteria. Version binding, finding identity, technical verdicts, and human approval SHALL retain their evidence and authority. Authorized approval replies SHALL be independently discoverable. Recording or reading an approval SHALL NOT require a human GitHub identifier or separate recorder qualification. Whether work is authorized SHALL be decided by the workflow that owns the lifecycle, not by this capability.

#### Scenario: Local record policy is independent of GitHub publication
- **WHEN** GitHub skills read a Work Item as source material
- **THEN** the Work Item policy remains usable without GitHub workflow rules, contract links, or publication fields
- **AND** the GitHub entries define their own remote review schema and finding states without importing the local record policy

#### Scenario: change-review publishes a new round
- **WHEN** an authorized change-review round posts to a PR
- **THEN** it can publish the simplified reply with the required reviewed version and findings while preserving earlier rounds
- **AND** it does not invoke create, update the PR body, close work, or perform Git writes

#### Scenario: A recorded design approval is needed
- **WHEN** a workflow asks whether the PR carries a published design approval
- **THEN** the lookup reads the PR's approval events for their actual source, approved scope and revision without a separate recorder-account qualification
- **AND** a technical pass, a body edit, and the absence of a mandatory approval block are not reported as an approval record

#### Scenario: Approval reply is requested with an unknown human account
- **WHEN** the user authorizes recording an explicit instruction but their GitHub account is unknown
- **THEN** reply records source, scope, revision and posting metadata without asking whether the API login is the user
- **AND** it omits the unknown human identifier, reads back the result and preserves earlier events

#### Scenario: Apply is requested without publication
- **WHEN** the current user explicitly requests implementation but has not requested a GitHub approval reply
- **THEN** no approval reply is posted and the missing PR event is not reported as a blocker
- **AND** permission to implement does not implicitly authorize platform writes

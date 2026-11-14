# Spec Delta

## MODIFIED Requirements

### Requirement: Review works with or without a PR
A PR SHALL NOT be required to review a resolved Change. Without a corresponding PR, the workflow SHALL review the selected local content and return its findings and limits directly. A confirmed no-PR result SHALL be distinguished from unavailable PR discovery. Review MUST NOT create an Issue, PR or Work Item to satisfy its entry conditions.

#### Scenario: No corresponding PR exists
- **WHEN** discovery confirms the selected Change has no PR
- **THEN** the workflow reviews and tests the local target and returns a report without GitHub publication or default implementer notification; only an explicitly requested local handoff can notify under the local-handoff requirement
- **AND** the report identifies the local version and relevant uncommitted differences

#### Scenario: PR discovery is unavailable
- **WHEN** the workflow cannot determine whether a PR exists
- **THEN** it reports discovery as unknown and can perform supported local checks with that limit stated
- **AND** it does not equate failed lookup with no PR or claim a full remote-version verification

### Requirement: Confirmed PR feedback precedes local implementer notification
After confirming a failed PR review, the workflow SHALL notify the verified local implementer through an available session tool, unless explicitly excluded. The message SHALL include review results, confirmed report URL, PR number and URL, reviewed version and required next action. If no verified local target or usable channel exists, the workflow SHALL return a transferable message and report delivery honestly. For a PR review, this publication prerequisite SHALL remain mandatory. An explicitly requested no-PR local handoff SHALL follow its separate requirement and MUST NOT be used to bypass failed or unconfirmed PR publication.

#### Scenario: Local implementer is reachable
- **WHEN** the report is confirmed and an available tool verifies the implementation session belongs to the local project context
- **THEN** the workflow sends the repair message to that session without requiring the user to repeat the target
- **AND** it records sent separately from read, repair started or repair completed

#### Scenario: Implementer is remote or channel unavailable
- **WHEN** the implementer is not on this machine or no available session mechanism can reach the verified target
- **THEN** the workflow returns the complete handoff message and explains why direct notification was not performed
- **AND** it does not upload transcripts, create a replacement agent or claim successful delivery

### Requirement: Review execution is bounded and preserves scope
One invocation SHALL perform one review round and report the result and next action. Repeated repair rounds SHALL resume explicitly after new evidence or revision is available. Repeated disagreement without new evidence, requirement conflict, missing environment, or required future data SHALL stop progression as blocked with an owner and next action. Review SHALL not silently expand scope, poll, or merge, deploy, archive, or close work.

#### Scenario: Same disagreement has no new evidence
- **WHEN** a re-review finds the same unresolved dispute without a changed revision or new evidence
- **THEN** it records the dispute as blocked for human resolution
- **AND** it does not keep repeating automatic requests or invent additional requirements

#### Scenario: Repair passes the selected scope
- **WHEN** the reviewed revision satisfies the selected review scope with sufficient evidence
- **THEN** the reviewer reports pass for that purpose and revision, publishing it for an authorized confirmed PR unless excluded, and otherwise returning the local result
- **AND** any remaining human approval, deployment, acceptance, or closure action remains explicit

## ADDED Requirements

### Requirement: Review announces its execution mode and report destination
Before substantive checks, the workflow SHALL announce the selected Change, purpose, reviewed version, PR discovery state and intended report destination. Confirmed no PR and unknown discovery SHALL stay distinct. An informative announcement MUST NOT add an approval gate when the target and authorization are already clear.

#### Scenario: Review starts without a PR
- **WHEN** discovery confirms no corresponding PR
- **THEN** the reviewer states that this round checks local content and will return or save a local report before starting required checks

#### Scenario: Lookup is unknown
- **WHEN** the PR lookup is unavailable
- **THEN** the announcement states unknown discovery and the supported local scope without implying that no PR exists

### Requirement: Local reports preserve recoverable content evidence
Local Review reports SHALL follow existing Work Item ownership and storage rules without requiring a pre-existing Work Item or a new permanent tracker. Uncommitted content SHALL have an included-path inventory, comparison baseline, fingerprint and algorithm sufficient to verify the reviewed content. Exclusions and source-skill identity SHALL remain separate and explicit.

#### Scenario: Existing Work Item and dirty checkout
- **WHEN** the same work has a Work Item in this directory and the review includes uncommitted files
- **THEN** the report is saved under the existing local convention with staged, unstaged and untracked inclusion, baseline and content fingerprints
- **AND** another agent's report is not overwritten

#### Scenario: No local history exists
- **WHEN** no applicable Work Item exists in this checkout
- **THEN** review continues using the accessible formal artifacts and current evidence, with recording handled under existing local rules
- **AND** it does not restore records from another worktree or create a permanent registry

#### Scenario: Content moves during the round
- **WHEN** included local content changes after the reviewed snapshot is fixed
- **THEN** the report identifies its actual snapshot and the change in scope instead of declaring the new content passed

### Requirement: Explicit local repair handoff does not require a PR
For a no-PR review, an explicit user request SHALL permit sending a saved local repair report to a verified implementer. The message SHALL identify the local report, reviewed snapshot, stable findings and next action without a fabricated PR URL. Default no-PR review SHALL NOT notify. Explicit notification exclusions SHALL remain binding, and PR publication failures MUST NOT enter this exception.

#### Scenario: User requests a local handoff
- **WHEN** the user explicitly asks to return local findings to an implementer and the report and local session mapping can be verified
- **THEN** the workflow sends one local handoff with the report path and reviewed content evidence, recording sent separately from read or repair started

#### Scenario: No notification request or unverified author
- **WHEN** no explicit handoff is requested, or the original implementer cannot be verified even though a publisher can
- **THEN** the workflow sends no session message and returns the report or a transferable message as applicable

#### Scenario: Restrictions or failed publication prevent sending
- **WHEN** notification is excluded or an identified PR report is denied, times out or remains unconfirmed
- **THEN** the workflow does not send a local repair handoff as a workaround

### Requirement: Deferred PR publication reconciles original review evidence
A later request to post a local report SHALL verify the selected PR and compare its published content with the original review evidence before claiming coverage. It SHALL preserve the original report identity, provenance and baseline. Unverified differences MUST NOT inherit an earlier pass. Publication SHALL use existing github-pr reply and readback; creating a PR MUST NOT trigger automatic report publication.

#### Scenario: Published content matches the local evidence
- **WHEN** an authorized later publication can prove the PR head matches the reviewed scope and content
- **THEN** the reply preserves the local baseline and report identity and explains the verified mapping to the published head

#### Scenario: Published content differs
- **WHEN** the current PR includes changes not covered by the saved report
- **THEN** the workflow identifies the difference and requires a new review for a current-head verdict
- **AND** an explicitly requested historical report remains labeled with its original scope rather than becoming a pass for the new head

#### Scenario: Comparison evidence is missing
- **WHEN** the original reviewed content cannot be reconstructed or matched
- **THEN** the workflow reports the limitation and does not attest current-head acceptance from the old report

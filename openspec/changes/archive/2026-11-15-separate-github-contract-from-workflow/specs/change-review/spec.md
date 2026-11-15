# Spec Delta

## ADDED Requirements

### Requirement: Final-version review narrows only with diff evidence
A review of a head produced after an earlier pass by archive, spec synchronization, or documentation updates SHALL narrow its scope only when the difference from the reviewed head is shown to be limited to moves, spec synchronization, and the matching documentation. Any semantic change in that difference SHALL receive the necessary broader verification. The report SHALL bind to the new head and leave the earlier report attributed to its own head.

#### Scenario: Difference is limited to finalization
- **WHEN** the difference between the previously reviewed head and the new head contains only archive moves, spec synchronization, and documentation updates
- **THEN** the reviewer may review the narrowed scope and reports the evidence that the difference is limited to finalization
- **AND** the earlier pass is not claimed to cover the new head

#### Scenario: Finalization includes a semantic change
- **WHEN** the same difference also changes the behavior of code or scripts
- **THEN** the reviewer runs the necessary tests and a full review of that change and lists the checks actually rerun
- **AND** it neither narrows the scope as archive-only nor reuses the earlier head's test results

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
- **THEN** the reviewer follows the approval record format and preserves YYYY-MM-DD without fabricating a time or replacing it with recorded_at
- **AND** an honestly dated instruction is not rejected for lacking an exact time or a human GitHub account; unknown optional identifiers are omitted

#### Scenario: Approval recorder has access but lacks authorization
- **WHEN** a comment author can write the repository but the content provides no identifiable user instruction authorizing the selected design
- **THEN** repository access and a self-declared recorder name do not authorize Apply
- **AND** review and separately authorized report publication remain possible without introducing a recorder allowlist

#### Scenario: Explicit user instruction already covers implementation
- **WHEN** the current user or a traceable handoff explicitly requests implementation of the identified unchanged design
- **THEN** the workflow recognizes that instruction without requiring another approval phrase, human-account match or PR event
- **AND** it keeps the technical review verdict distinct from the instruction authorizing implementation

### Requirement: Integration separates dependency readiness from acceptance
Integration SHALL require an obtainable version of the pull request reply entry the skill publishes through, not a prior final pass from the Skill being introduced. Reviewing the upstream PR MAY serve as a real integration case. The upstream verdict and the Review Skill's own acceptance SHALL remain separate; neither an automatic pass nor an artificial defect is required to exercise the workflow.

#### Scenario: Upstream final review is deferred to the new Skill
- **WHEN** the upstream reply entry is delivered and its final review is the selected integration case
- **THEN** the Skill can be implemented and tested without pretending that upstream review has already passed
- **AND** a report about the upstream target does not certify the Review Skill's own implementation

#### Scenario: The real target has no demonstrated defect
- **WHEN** the live integration target satisfies the selected review scope
- **THEN** its report reflects that evidence without inventing a finding or changing the target to force a repair round
- **AND** deterministic repair-loop coverage uses fixtures or a separately authorized disposable target, with any untested live branch disclosed

### Requirement: Reports use the review format and the PR reply entry
Review reports SHALL follow the review format held by the review skill and SHALL be published through the pull request reply entry, which supplies the reply frame, native-tool operation checks, optional account restrictions, provenance, and ownership rules. An available configured gh or GitHub MCP SHALL perform PR operations without a custom identity script or blob. Each round SHALL record phase, revision, scope, verdict, checks, limits, findings, Next actions, shared Author and verified publication results. The reviewer MUST NOT overwrite others' records or invoke PR create or publish.

#### Scenario: Publishing feedback
- **WHEN** review feedback is ready and remote publication is authorized
- **THEN** the reviewer uses the selected available tool after confirming the target, authorization, required capability, and any applicable explicit account restriction
- **AND** it does not stage, commit, push, change product code, or call the PR create or publish path

#### Scenario: Blocked review can still be reported
- **WHEN** necessary verification is blocked but the PR is identified and report publication is authorized and available
- **THEN** the reviewer publishes the blocked verdict with the known revision, missing evidence, owner, and next action
- **AND** an inability to complete verification is not silently treated as an inability to publish a report

#### Scenario: Remote publication fails
- **WHEN** a completed report cannot be posted because of tool, identity, or permission failure
- **THEN** the reviewer preserves an authorized local draft or returns the report and records publication as incomplete
- **AND** it does not fabricate a report URL or announce that remote handoff completed

#### Scenario: gh is unavailable but MCP can publish
- **WHEN** gh is unavailable but a configured MCP can perform the authorized review publication
- **THEN** the reviewer may use that MCP after its own target and operation checks
- **AND** the absence of a custom identity script or account policy does not block publication

#### Scenario: Required capability or explicit account compliance is unavailable
- **WHEN** no configured tool can publish, the write is explicitly denied, or a mandatory account restriction cannot be satisfied
- **THEN** the report remains unpublished with the concrete limitation recorded
- **AND** a different tool's login is not substituted for evidence about the selected connection

#### Scenario: Publication times out and another channel is available
- **WHEN** the first write has an unknown result
- **THEN** the reviewer reconciles the actual PR report state before retrying through any channel
- **AND** it does not duplicate the report or invent a successful URL

#### Scenario: Write reports success but readback cannot confirm it
- **WHEN** a tool returns success and a report URL but readback fails or the stored target, review ID, phase, head, or content differs
- **THEN** publication is recorded as possibly completed but unconfirmed, separately from the technical verdict
- **AND** the reviewer reconciles state before retrying and does not announce verified remote handoff

#### Scenario: A complete report is written
- **WHEN** the reviewer writes a full report, with or without a pull request
- **THEN** the complete report examples it follows are among the review skill's own references
- **AND** it does not depend on acceptance cases or on a separate format document for the report layout

## RENAMED Requirements

- FROM: `### Requirement: Reports use the shared handoff contract`
- TO: `### Requirement: Reports use the review format and the PR reply entry`

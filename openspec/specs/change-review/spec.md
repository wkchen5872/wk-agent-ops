# change-review Specification

## Purpose

Let an agent review a published OpenSpec change from a PR, produce attributable evidence for the selected design or implementation phase, and hand findings to an implementer for a version-aware repair and re-review cycle.

## Requirements

### Requirement: Review resolves an explicit phase and version
The review entry SHALL accept a PR reference, design or implementation phase, and an optional expected head. It SHALL resolve the repository, Issue, Change, base, head, and required artifacts. An expected-head mismatch or missing or ambiguous required content MUST block progression for that target. Published review SHALL exclude unpublished changes from its pass claim and distinguish the review tool's source from the reviewed content.

#### Scenario: Several Changes are linked
- **WHEN** a PR links multiple plausible Changes without selecting the review target
- **THEN** the reviewer reports the ambiguity and obtains a target before reviewing
- **AND** it does not pick the first Change or infer it from a local Work Item

#### Scenario: A target is selected while another linked Change is unfinished
- **WHEN** the caller selects one Change and the PR also contains planning for another unfinished Change
- **THEN** the review evaluates the selected Change and its actual dependencies
- **AND** unrelated unfinished tasks do not become missing implementation in the selected scope

#### Scenario: Checkout is dirty or mismatched
- **WHEN** the available checkout differs from the PR head or contains unpublished changes
- **THEN** the reviewer obtains a safe matching review context or reports the version limitation
- **AND** it does not discard local work, commit it, or attribute its test results to the published head

#### Scenario: Head moves during review
- **WHEN** the PR head changes after the reviewed snapshot was selected
- **THEN** the report remains attributed to its actual reviewed revision
- **AND** it cannot represent that result as a pass for the new head without rechecking the affected scope

#### Scenario: Caller supplies a head different from the current PR
- **WHEN** an explicit expected head does not match the actual PR head
- **THEN** the reviewer reports the mismatch and obtains a corrected target before proceeding
- **AND** it does not silently review the latest branch revision instead

#### Scenario: A new Skill is tested against an earlier PR revision
- **WHEN** the Review Skill source is newer than or uncommitted relative to the selected target
- **THEN** the evidence separately identifies the Skill source revision or fingerprint and the actual reviewed checkout
- **AND** a dirty Skill-development checkout does not attest tests of a different published target head

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
- **AND** approved_by identifies the human GitHub account and an honestly dated approval is not rejected solely for lacking an exact time

#### Scenario: Approval recorder has access but lacks authorization
- **WHEN** a comment author can write the repository but has no trusted authorization to attest the human's approval
- **THEN** that attestation does not authorize Apply, even if the candidate PR names the author as a recorder
- **AND** readonly review and separately authorized technical report publication remain possible with the approval limitation stated

### Requirement: Implementation review uses a self-contained verification baseline
Implementation review SHALL compare the selected revision with OpenSpec artifacts, inspect connected code and tests, and execute required checks using a self-contained baseline checklist. Available verification Skills SHALL supplement that baseline. Optional quality Skills MUST NOT be required solely by this workflow. The report SHALL record evidence and limits; missing mandatory evidence MUST NOT produce a pass.

#### Scenario: Optional quality-review Skill is absent
- **WHEN** an environment has no ponytail-review or equivalent optional extension
- **THEN** the reviewer performs the baseline artifact, connected-code, test, and regression checks and reports the extension as not executed
- **AND** extension absence alone does not cause blocked or waive necessary checks

#### Scenario: Necessary tests cannot run
- **WHEN** required tests lack credentials, environment, or real data
- **THEN** the report identifies the missing checks and marks the affected acceptance scope blocked
- **AND** the absence of an observed bug does not become a passing result

#### Scenario: Real-data acceptance is still pending
- **WHEN** implementation checks pass but the Change requires an observation period that is not complete
- **THEN** the report distinguishes the passing checks from pending formal acceptance
- **AND** the workflow does not report the whole Change accepted, close its Issue, or mark required tasks complete

### Requirement: Integration separates dependency readiness from acceptance
Integration SHALL require an obtainable version of the shared handoff contract, not a prior final pass from the Skill being introduced. Reviewing the upstream PR MAY serve as a real integration case. The upstream verdict and the Review Skill's own acceptance SHALL remain separate; neither an automatic pass nor an artificial defect is required to exercise the workflow.

#### Scenario: Upstream final review is deferred to the new Skill
- **WHEN** the upstream contract is delivered and its final review is the selected integration case
- **THEN** the Skill can be implemented and tested without pretending that upstream review has already passed
- **AND** a report about the upstream target does not certify the Review Skill's own implementation

#### Scenario: The real target has no demonstrated defect
- **WHEN** the live integration target satisfies the selected review scope
- **THEN** its report reflects that evidence without inventing a finding or changing the target to force a repair round
- **AND** deterministic repair-loop coverage uses fixtures or a separately authorized disposable target, with any untested live branch disclosed

### Requirement: Findings require evidence and stable identity
Every finding SHALL identify a concrete impact, requirement or location, evidence, severity, stable ID, and status. Blocking findings SHALL concern demonstrated defects, security or data risks, unmet requirements, or required verification gaps. Style preferences and out-of-scope extensions MUST remain nonblocking. Repeated rounds SHALL preserve finding identity and the evidence for status changes.

#### Scenario: Optional stylistic suggestion
- **WHEN** a reviewer prefers a different naming or layout but identifies no relevant defect or requirement gap
- **THEN** the suggestion does not require changes or prevent acceptance

#### Scenario: Implementer claims a fix
- **WHEN** an implementer replies that a finding has been fixed
- **THEN** the finding remains unresolved until the reviewer verifies the correction or a supported rejection
- **AND** the reviewer records the fixing revision and validation evidence when resolving it

### Requirement: Reports use the shared handoff contract
Review reports SHALL follow the shared schema, native-tool operation checks, optional account restrictions, provenance, and ownership rules. An available configured gh or GitHub MCP SHALL perform PR operations without a custom identity script or blob. Each round SHALL record phase, revision, scope, verdict, checks, limits, findings, and verified publication results. The reviewer MUST NOT overwrite others' records or invoke PR create or publish.

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

### Requirement: Agent verdicts do not impersonate platform approval
The report SHALL distinguish pass, changes-required, and blocked from GitHub review events and repository merge rules. When an account cannot submit a valid native approval or request-changes review, the reviewer SHALL use an available authorized comment form and state its limitations. Multiple agents sharing one account MUST NOT be described as separate platform approvers.

#### Scenario: Default report publication
- **WHEN** an authorized reviewer publishes a report without a separate request for platform approval or request changes
- **THEN** it uses a COMMENT review anchored to the reviewed commit when supported, or a clearly versioned conversation comment
- **AND** the Agent verdict remains in the report and does not imply a required platform approval

#### Scenario: Reviewer uses the PR author's account
- **WHEN** the selected GitHub actor is the PR author
- **THEN** the agent publishes a report using an allowed form without claiming an independent platform approval
- **AND** a technical pass is not reported as satisfying required-review rules

### Requirement: Repair handoff persists the report before notification
For changes-required, the workflow SHALL persist the report before handoff with PR and report references, reviewed head, and finding IDs. The default SHALL be a human-transferable message; direct notification SHALL require an identified available and authorized session tool. Unknown delivery or unavailable sessions MUST remain incomplete rather than be treated as receipt or execution.

#### Scenario: Original session is available
- **WHEN** a failed review is published and the original implementer is reachable through an authorized mechanism
- **THEN** the workflow sends the report reference and reviewed revision to that session
- **AND** it records notification separately from repair completion

#### Scenario: Original session is gone
- **WHEN** the original implementer session cannot be reached
- **THEN** the PR retains all necessary repair context for a replacement agent
- **AND** the reviewer returns an explicit handoff action without claiming it woke a new agent

### Requirement: Re-review verifies the new version and affected behavior
Re-review SHALL use the implementer's per-finding replies, fixing commits, test evidence, and the new PR head. The reviewer SHALL verify fixes and affected behavior before updating findings and publishing a new conclusion. A previous pass MUST NOT automatically apply to changed scope; prior rounds SHALL remain traceable.

#### Scenario: New head includes a repair and a related regression
- **WHEN** a new revision fixes a reported line but changes connected behavior
- **THEN** the reviewer checks the affected behavior and records any evidenced regression
- **AND** it does not resolve the original handoff solely from the implementer's statement

### Requirement: Review execution is bounded and preserves scope
One invocation SHALL perform one review round and report the result and next action. Repeated repair rounds SHALL resume explicitly after new evidence or revision is available. Repeated disagreement without new evidence, requirement conflict, missing environment, or required future data SHALL stop progression as blocked with an owner and next action. Review SHALL not silently expand scope or merge, deploy, archive, or close work.

#### Scenario: Same disagreement has no new evidence
- **WHEN** a re-review finds the same unresolved dispute without a changed revision or new evidence
- **THEN** it records the dispute as blocked for human resolution
- **AND** it does not keep repeating automatic requests or invent additional requirements

#### Scenario: Repair passes the selected scope
- **WHEN** the reviewed revision satisfies the selected review scope with sufficient evidence
- **THEN** the reviewer publishes pass for that phase and revision
- **AND** any remaining human approval, deployment, acceptance, or closure action remains explicit

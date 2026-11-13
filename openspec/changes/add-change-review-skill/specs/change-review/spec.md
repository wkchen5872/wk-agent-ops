# Spec Delta

## Purpose

Let an agent review a published OpenSpec change from a PR, produce attributable evidence for the selected design or implementation phase, and hand findings to an implementer for a version-aware repair and re-review cycle.

## ADDED Requirements

### Requirement: Review resolves an explicit phase and version
The review entry SHALL accept a PR reference and explicit design or implementation phase, resolve the associated repository, Issue, Change, base, and head, and obtain the corresponding artifacts. Ambiguity or unavailable required content MUST block a verdict for that scope. Published PR review SHALL exclude unpublished local changes from its pass claim.

#### Scenario: Several Changes are linked
- **WHEN** a PR links multiple plausible Changes without selecting the review target
- **THEN** the reviewer reports the ambiguity and obtains a target before reviewing
- **AND** it does not pick the first Change or infer it from a local Work Item

#### Scenario: Checkout is dirty or mismatched
- **WHEN** the available checkout differs from the PR head or contains unpublished changes
- **THEN** the reviewer obtains a safe matching review context or reports the version limitation
- **AND** it does not discard local work, commit it, or attribute its test results to the published head

#### Scenario: Head moves during review
- **WHEN** the PR head changes after the reviewed snapshot was selected
- **THEN** the report remains attributed to its actual reviewed revision
- **AND** it cannot represent that result as a pass for the new head without rechecking the affected scope

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
Review reports SHALL use the shared handoff schema, identity-check script, provenance, and body-ownership rules. PR reads and report writes SHALL use gh; writes SHALL require a passing api preflight. Each round SHALL state phase, revision, scope, result, checks, limits, and finding status. The reviewer MUST NOT switch to GitHub MCP, overwrite another author's record, or invoke PR create or publish operations.

#### Scenario: Publishing feedback
- **WHEN** review feedback is ready and remote publication is authorized
- **THEN** the reviewer uses gh to submit the Review or comment after the shared script verifies the actual API actor
- **AND** it does not stage, commit, push, change product code, or call the PR create or publish path

#### Scenario: Blocked review can still be reported
- **WHEN** necessary verification is blocked but the PR is identified and report publication is authorized and available
- **THEN** the reviewer publishes the blocked verdict with the known revision, missing evidence, owner, and next action
- **AND** an inability to complete verification is not silently treated as an inability to publish a report

#### Scenario: Remote publication fails
- **WHEN** a completed report cannot be posted because of tool, identity, or permission failure
- **THEN** the reviewer preserves an authorized local draft or returns the report and records publication as incomplete
- **AND** it does not fabricate a report URL or announce that remote handoff completed

#### Scenario: CLI or preflight prerequisite is missing
- **WHEN** gh or the shared identity script is unavailable, or its api result is not pass
- **THEN** the report remains unpublished with the concrete missing prerequisite or mismatch recorded
- **AND** the reviewer does not fall back to GitHub MCP or another unverified account

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

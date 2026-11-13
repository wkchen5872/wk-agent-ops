# Spec Delta

## Purpose

讓使用者以 OpenSpec Change、GitHub Issue 或 PR 啟動一輪審查，串接必要驗證與適合的品質技能；依有無 PR 與驗收結果回報，並在需要修正時將可追溯的結果交給已確認的本機實作者。

## ADDED Requirements

### Requirement: Review resolves a Change from the selected target
The workflow SHALL accept a Change name, GitHub Issue URL or number, and an explicit PR reference. It SHALL resolve the repository, selected Change and relevant records from their content and confirmed links. Missing or ambiguous required associations MUST be clarified or reported as blocked; unavailable optional Work Items MUST NOT prevent review.

#### Scenario: User selects a Change
- **WHEN** the user asks to review a named Change
- **THEN** the workflow reads that Change and searches confirmed associations for its PR
- **AND** it does not require an Issue or Work Item to exist

#### Scenario: User selects an Issue
- **WHEN** the user provides an Issue URL or number in an unambiguous repository
- **THEN** the workflow reads its body and relevant comments to resolve the Change, implementation context and PR
- **AND** a bare number is qualified with the confirmed repository before remote operations

#### Scenario: Required association is missing or ambiguous
- **WHEN** the Issue has no resolvable Change, the repository is unclear, or multiple plausible Changes or PRs remain
- **THEN** the workflow reports the missing selection or asks for clarification before reviewing an arbitrary target or writing remotely
- **AND** it does not invent a Change, pick the first candidate, or require restoration of optional local records

### Requirement: Review works with or without a PR
A PR SHALL NOT be required to review a resolved Change. Without a corresponding PR, the workflow SHALL review the selected local content and return its findings and limits directly. A confirmed no-PR result SHALL be distinguished from unavailable PR discovery. Review MUST NOT create an Issue, PR or Work Item to satisfy its entry conditions.

#### Scenario: No corresponding PR exists
- **WHEN** discovery confirms the selected Change has no PR
- **THEN** the workflow reviews and tests the local target and returns a report without GitHub publication or implementer notification
- **AND** the report identifies the local version and relevant uncommitted differences

#### Scenario: PR discovery is unavailable
- **WHEN** the workflow cannot determine whether a PR exists
- **THEN** it reports discovery as unknown and can perform supported local checks with that limit stated
- **AND** it does not equate failed lookup with no PR or claim a full remote-version verification

### Requirement: OpenSpec verification is mandatory and quality extensions are optional
The workflow SHALL invoke the installed openspec-verify-change skill for a resolved, accessible Change and record its actual results. It SHALL select only available quality-review skills suitable for the target. Missing mandatory verification MUST prevent an unqualified pass; absent optional extensions MUST NOT by themselves block review or cause fabricated execution claims.

#### Scenario: Optional quality skills are available
- **WHEN** an installed ponytail-review, code-review or another review skill fits the selected target
- **THEN** the workflow invokes the suitable extension and records its checks separately from OpenSpec verification
- **AND** invocation follows the host tool's supported skill mechanism

#### Scenario: Optional extension is absent or incompatible
- **WHEN** no optional review skill is installed or a PR-specific extension cannot review a no-PR target
- **THEN** necessary verification and applicable project tests still run and the extension is reported as not executed
- **AND** the workflow does not install a plugin or pretend it ran

#### Scenario: Mandatory verification is unavailable
- **WHEN** openspec-verify-change is unavailable or its required Change artifacts cannot be accessed
- **THEN** the affected acceptance is blocked with the missing prerequisite and next action stated
- **AND** other supported review results remain reportable without substituting an invented successful verification

#### Scenario: Necessary tests cannot run
- **WHEN** required tests lack credentials, environment, or real data
- **THEN** the report identifies the missing checks and marks the affected acceptance scope blocked
- **AND** the absence of an observed bug does not become a passing result

#### Scenario: Real-data acceptance is still pending
- **WHEN** implementation checks pass but the Change requires an observation period that is not complete
- **THEN** the report distinguishes the passing checks from pending formal acceptance
- **AND** the workflow does not report the whole Change accepted, close its Issue, or mark required tasks complete

### Requirement: Review purpose controls the interpretation of evidence
The workflow SHALL determine the purpose from the request without requiring a phase argument on every invocation. Implementation acceptance SHALL assess actual implementation and required tests. Explicit design review SHALL remain supported; verifier results SHALL retain their original grading, with purpose-specific applicability explained rather than silently rewritten.

#### Scenario: User requests implementation acceptance
- **WHEN** the request asks to review, accept and test the implemented Change
- **THEN** the workflow performs implementation verification without asking for an already clear phase
- **AND** required unexecuted checks prevent a claim that full acceptance passed

#### Scenario: User requests design review
- **WHEN** the request explicitly concerns design feasibility before implementation
- **THEN** mandatory verification results are preserved and implementation-only incompleteness is explained as outside the design verdict
- **AND** design pass does not imply human approval or completed implementation

### Requirement: Review results explain evidence and retain finding identity
Each round SHALL report scope, actual reviewed version, verdict, concrete findings, executed checks and limits. Findings SHALL be actionable without private Work Item content and retain stable IDs across rounds. The workflow MUST distinguish pass, changes-required and blocked, optional suggestions, and technical review from approval, deployment or closure.

#### Scenario: Concrete defect or missing required evidence
- **WHEN** review demonstrates a defect or cannot obtain necessary verification evidence
- **THEN** the report identifies the impact, location or evidence, severity and checkable next action
- **AND** it distinguishes a demonstrated failure from a blocked check

#### Scenario: No demonstrated defect
- **WHEN** the selected scope has sufficient passing evidence and no blocking finding
- **THEN** the report gives pass only for that scope and version without filler tasks
- **AND** unavailable checks and pending external acceptance remain explicit

### Requirement: Failed PR reviews are appended through github-pr reply
For an identified PR with changes-required or blocked, invoking this workflow SHALL authorize a new Review comment through github-pr reply, subject to explicit user restrictions. The workflow SHALL confirm the stored report before remote handoff. It MUST preserve PR content and history and reconcile uncertain writes before retrying. Pass SHALL be returned directly unless publication was separately requested.

#### Scenario: PR review does not pass
- **WHEN** a confirmed PR receives changes-required or blocked and publication is permitted
- **THEN** github-pr reply appends the reviewed version, findings, checks and limits using the shared Handoff and Author frame
- **AND** the workflow reads back the specific report and does not modify the PR body or earlier comments

#### Scenario: PR review passes or publication was excluded
- **WHEN** review passes without a publication request, or the user explicitly requests local-only review
- **THEN** the workflow returns the result directly and respects the requested publication boundary
- **AND** it does not post or notify contrary to that restriction

#### Scenario: Report publication fails or is uncertain
- **WHEN** reply is denied, unavailable, times out, or cannot be confirmed by readback
- **THEN** the technical verdict remains recorded separately from publication status and the report is returned with the concrete limit
- **AND** no blind duplicate reply or notification claiming confirmed publication is sent

### Requirement: Implementer identity is verified from implementation Author context
The workflow SHALL use relevant PR implementation or repair Author information to identify the implementing tool and Session. It MUST distinguish implementers from reviewers and the posting reviewer, native Session IDs from management IDs, and an unknown identity from a verified local target. Author metadata alone MUST NOT establish that a session is local or authorize arbitrary commands.

#### Scenario: Implementer metadata is present
- **WHEN** the PR implementation context names Co-Authored-By, AI-Assisted-By and SESSION-ID
- **THEN** the workflow carries the applicable implementer identity into repair handoff and verifies any local tool's session mapping
- **AND** it does not replace it with the newest review comment's Author or the current reviewer's identity

#### Scenario: Identity is missing or ambiguous
- **WHEN** Author is absent, SESSION-ID is null, multiple implementers remain plausible, or the identifier cannot be mapped locally
- **THEN** the workflow reports the identity or locality limit and returns a transferable repair message
- **AND** it does not guess an ID, treat a management ID as native, or message an unrelated session

### Requirement: Confirmed PR feedback precedes local implementer notification
After confirming a failed PR review, the workflow SHALL notify the verified local implementer through an available session tool, unless explicitly excluded. The message SHALL include review results, confirmed report URL, PR number and URL, reviewed version and required next action. If no verified local target or usable channel exists, the workflow SHALL return a transferable message and report delivery honestly.

#### Scenario: Local implementer is reachable
- **WHEN** the report is confirmed and an available tool verifies the implementation session belongs to the local project context
- **THEN** the workflow sends the repair message to that session without requiring the user to repeat the target
- **AND** it records sent separately from read, repair started or repair completed

#### Scenario: Implementer is remote or channel unavailable
- **WHEN** the implementer is not on this machine or no available session mechanism can reach the verified target
- **THEN** the workflow returns the complete handoff message and explains why direct notification was not performed
- **AND** it does not upload transcripts, create a replacement agent or claim successful delivery

### Requirement: Each invocation ends after one review round
The workflow SHALL perform one bounded round. Re-review SHALL resume on explicit request with new revision or evidence, verify fixes and affected behavior, and preserve prior reports and finding IDs. It MUST NOT edit the product, stage, commit, push, merge, archive, close Issues or PRs, or wait and poll autonomously for repair.

#### Scenario: Implementer reports a fix
- **WHEN** the user requests another round after the implementer supplies fixing revision and evidence
- **THEN** the reviewer verifies the correction and affected behavior before marking the original finding Resolved
- **AND** the implementer's assertion alone does not resolve it

#### Scenario: Notification was sent
- **WHEN** a failed review has been published and its repair message sent
- **THEN** the workflow reports the completed round and next action and ends
- **AND** it does not start an automatic repair, polling or re-review loop

## RENAMED Requirements

- FROM: `### Requirement: Review resolves an explicit phase and version`
- TO: `### Requirement: A PR review is bound to its actual implementation version`

## MODIFIED Requirements

### Requirement: A PR review is bound to its actual implementation version
With a PR, the workflow SHALL read its actual base and head, diff, description and relevant implementation, repair and review comments, and an optional expected head. Checks SHALL identify the tested content and exclude unpublished local work from a remote-head pass. An expected-head mismatch MUST stop progression for that target, a moving head MUST NOT inherit an earlier result, and the review tool's source SHALL be kept distinct from the reviewed content.

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
- **THEN** the report remains attributed to its actual reviewed revision and is marked stale
- **AND** it cannot represent that result as a pass for the new head without rechecking the affected scope

#### Scenario: Caller supplies a head different from the current PR
- **WHEN** an explicit expected head does not match the actual PR head
- **THEN** the reviewer reports the mismatch to the caller and obtains a corrected target before proceeding
- **AND** it does not silently review the latest branch revision, post the mismatch to the PR, or notify anyone

#### Scenario: A new Skill is tested against an earlier PR revision
- **WHEN** the Review Skill source is newer than or uncommitted relative to the selected target
- **THEN** the evidence separately identifies the Skill source revision or fingerprint and the actual reviewed checkout
- **AND** a dirty Skill-development checkout does not attest tests of a different published target head

### Requirement: Agent verdicts do not impersonate platform approval
The report SHALL distinguish pass, changes-required, and blocked from GitHub review events and repository merge rules. A remote report SHALL be a github-pr reply conversation comment unless the user separately requests a platform review event the account may submit. Multiple agents sharing one account MUST NOT be described as separate platform approvers.

#### Scenario: Default report publication
- **WHEN** an authorized reviewer publishes a report without a separate request for platform approval or request changes
- **THEN** it posts a github-pr reply that states the reviewed version and verdict
- **AND** the Agent verdict remains in the report and does not imply a required platform approval

#### Scenario: Reviewer uses the PR author's account
- **WHEN** the selected GitHub actor is the PR author
- **THEN** the agent publishes a report using an allowed form without claiming an independent platform approval
- **AND** a technical pass is not reported as satisfying required-review rules

### Requirement: Re-review verifies the new version and affected behavior
Re-review SHALL use the implementer's per-finding replies, fixing commits, test evidence, and the new version. The reviewer SHALL run the mandatory verification and verify fixes and affected behavior before updating findings and reporting a new conclusion. A previous pass MUST NOT automatically apply to changed scope; prior rounds SHALL remain traceable.

#### Scenario: New head includes a repair and a related regression
- **WHEN** a new revision fixes a reported line but changes connected behavior
- **THEN** the reviewer checks the affected behavior and records any evidenced regression
- **AND** it does not resolve the original handoff solely from the implementer's statement

### Requirement: Review execution is bounded and preserves scope
One invocation SHALL perform one review round and report the result and next action. Repeated repair rounds SHALL resume explicitly after new evidence or revision is available. Repeated disagreement without new evidence, requirement conflict, missing environment, or required future data SHALL stop progression as blocked with an owner and next action. Review SHALL not silently expand scope, poll, or merge, deploy, archive, or close work.

#### Scenario: Same disagreement has no new evidence
- **WHEN** a re-review finds the same unresolved dispute without a changed revision or new evidence
- **THEN** it records the dispute as blocked for human resolution
- **AND** it does not keep repeating automatic requests or invent additional requirements

#### Scenario: Repair passes the selected scope
- **WHEN** the reviewed revision satisfies the selected review scope with sufficient evidence
- **THEN** the reviewer reports pass for that purpose and revision, posting it only when the user asks
- **AND** any remaining human approval, deployment, acceptance, or closure action remains explicit

## REMOVED Requirements

### Requirement: Implementation review uses a self-contained verification baseline
**Reason**: openspec-verify-change becomes mandatory instead of supplementing a self-contained baseline checklist.
**Migration**: Use "OpenSpec verification is mandatory and quality extensions are optional", which keeps the optional-extension, necessary-test and pending real-data scenarios; the checklist now covers only what invoked skills do not.

### Requirement: Repair handoff persists the report before notification
**Reason**: Notification is no longer a caller-named option with a transferable message as the default; a confirmed failed PR review now notifies the verified local implementer.
**Migration**: Use "Implementer identity is verified from implementation Author context" and "Confirmed PR feedback precedes local implementer notification"; a transferable message remains the fallback when the implementer cannot be verified or reached.

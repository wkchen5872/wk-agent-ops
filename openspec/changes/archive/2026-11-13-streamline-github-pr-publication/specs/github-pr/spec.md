# Spec Delta

## Purpose

讓建立 PR 的要求一次涵蓋必要的提交、分支發布與回讀，不因可自行完成的準備工作再次索取授權；PR 正文及回覆同時記錄貼文者的原生 Session 與 Xirp 管理 Session，供跨工具交接而不混淆身分。

## ADDED Requirements

### Requirement: Creating a PR includes necessary Git publication without repeated approval
A request to create a PR SHALL authorize the necessary checks, scoped commit, normal push, Draft PR creation and readback for the selected work. The workflow MUST NOT request separate approval solely because work is uncommitted, unpushed or its head branch is absent remotely. It SHALL resolve routine target and base choices from repository and session evidence and proceed when permitted.

#### Scenario: Work is uncommitted and the branch is unpublished
- **WHEN** the user requests a PR for identifiable local work with usable repository access
- **THEN** the workflow checks the work, commits the relevant changes, publishes the required branch and creates a Draft PR without another permission question
- **AND** it verifies the stored PR before reporting completion

#### Scenario: Commit exists but has not been pushed
- **WHEN** selected work is already committed but the intended head is not published
- **THEN** the workflow publishes the existing commit and creates the PR without creating a redundant commit or asking whether to push

#### Scenario: Target and base can be determined
- **WHEN** remotes, branch ancestry, existing PRs or the conversation identify the repository, head and appropriate base
- **THEN** the workflow verifies those choices and proceeds without requiring the user to repeat them
- **AND** it does not silently publish to a conflicting target

### Requirement: Necessary publication preserves unrelated work and existing Git controls
Git preparation SHALL commit only the selected PR work and preserve unrelated tracked, untracked and staged content. It SHALL use normal project checks, hooks and attribution and verify the actual push repository and ref. PR creation MUST NOT force-push, discard work, bypass hooks, manufacture empty differences or merge work as an implicit prerequisite.

#### Scenario: Checkout contains unrelated changes
- **WHEN** the intended PR files coexist with unrelated dirty or staged files
- **THEN** only identified PR changes enter the commit and unrelated file content and staging state remain intact
- **AND** a whole-worktree commit helper is not invoked blindly

#### Scenario: Required checks fail or push cannot proceed normally
- **WHEN** a necessary test or hook fails, or publication encounters a non-fast-forward conflict
- **THEN** the workflow reports the failed step and any completed stages with the real cause
- **AND** it does not bypass the check, force-push, or claim the PR was created

#### Scenario: Selected work has no real difference
- **WHEN** the selected head has no actual changes relative to the verified base
- **THEN** the workflow reports that no meaningful PR can be created
- **AND** it does not add an empty commit or placeholder file to produce one

### Requirement: Publication and PR results are verified before completion claims
The workflow SHALL verify remote base and head repositories, refs, published SHA and a nonempty comparison after necessary publication. It SHALL compose the final PR from that published content and read back its returned identifier, target, head and body. Local plans or checks MUST NOT attest unrelated remote content; design-only PRs MUST remain described as design.

#### Scenario: Publication succeeds and creation follows
- **WHEN** a selected commit is pushed successfully
- **THEN** the workflow verifies the remote SHA and actual base-to-head difference before finalizing the PR description
- **AND** the created PR readback matches the selected base, head owner, head repository, SHA and body

#### Scenario: Base is an unpublished predecessor branch
- **WHEN** a verified predecessor base is needed to isolate the selected work from unrelated earlier changes
- **THEN** the create workflow can publish that existing base ref as necessary preparation and verifies both refs
- **AND** it reports the resulting base without manufacturing new predecessor changes or requesting approval merely for the missing ref

#### Scenario: Only planning artifacts are published
- **WHEN** the selected difference contains proposal, design, specs, tasks or diagrams but no implementation
- **THEN** the PR explains the proposed behavior and actual planning checks without claiming implementation acceptance

### Requirement: Existing targets and partial results are reconciled without duplicate publication
Create SHALL return one verified existing open PR without duplicate creation or an implicit description update. Before retrying a partial or uncertain execution, it SHALL reconcile local commits, remote refs and actual PR state, reuse completed stages and report uncertainty. Authentication or permission denial SHALL stop the affected action without credential changes or blind retries through another tool.

#### Scenario: A matching PR already exists
- **WHEN** initial discovery finds one open PR matching the selected base and full head identity
- **THEN** create returns its URL without creating a duplicate, committing additional dirty work or rewriting the body

#### Scenario: Push succeeded but PR creation failed
- **WHEN** a previous attempt published the selected SHA but PR creation failed or timed out
- **THEN** a retry checks the remote ref and existing PRs and performs only the remaining operation
- **AND** it does not create a second commit or duplicate PR to repeat the attempt

#### Scenario: Actual authentication or permission failure
- **WHEN** commit, push or PR creation cannot proceed because the configured environment denies the operation or lacks usable authentication
- **THEN** the workflow reports the specific failed operation, completed stages and remaining work
- **AND** it does not keep asking for approval already given, alter authentication or claim that granting conversational permission repairs the credentials

### Requirement: PR Author includes native and Xirp session identifiers independently
Every newly created PR body or reply SHALL end with Author containing the executing tool, known root-session model, SESSION-ID for the native session and XIRP-SESSION-ID for its Xirp management session. Both session fields SHALL be present; unavailable values SHALL independently be null with reasons reported. Unknown session metadata MUST NOT block the authorized PR operation or be fabricated.

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

### Requirement: Session discovery actively checks the current runtime before falling back
Before posting Author, the workflow SHALL inspect the current tool's available runtime session metadata and applicable local Xirp metadata. It MUST NOT declare identifiers unknown without checking available sources, infer the current model from environment or records, substitute management IDs for native IDs, or expose unrelated environment, credentials or transcript content during discovery.

#### Scenario: Runtime already provides IDs
- **WHEN** available runtime metadata exposes the current native and management identifiers
- **THEN** the workflow reads the relevant fields and uses those verified values instead of prematurely filling null
- **AND** it does not dump the full environment or session history

#### Scenario: Identifiers conflict or belong to another context
- **WHEN** source metadata cannot establish that an ID belongs to the current posting session
- **THEN** the workflow reconciles the relevant local metadata if available or reports that field as unverified and null
- **AND** it does not copy another agent's ID or relabel one namespace as the other

### Requirement: Consumers preserve session namespaces and legacy Author compatibility
Shared examples and review handoff consumers SHALL recognize SESSION-ID and XIRP-SESSION-ID as distinct namespaces. A verified Xirp ID SHALL be usable as a local session lookup hint without replacing the native ID. Existing Author records containing only a native ID or an explicitly qualified management ID SHALL remain readable; new-schema adoption MUST NOT rewrite historical records.

#### Scenario: Review locates an implementer from dual fields
- **WHEN** implementation Author contains both native and Xirp IDs
- **THEN** the consumer verifies the management ID through an available local session tool while preserving the native ID as identity evidence
- **AND** metadata alone does not prove locality, correct project association or successful notification

#### Scenario: Review reads legacy single-field Author
- **WHEN** an existing PR or earlier reply has only SESSION-ID or an explicitly qualified legacy management value
- **THEN** the consumer retains the known namespace and verifies any needed mapping rather than treating the record as invalid solely for missing the new field
- **AND** it does not rewrite that historical Author to simulate dual-field provenance

### Requirement: Metadata operations do not inherit create publication side effects
Update, reply and close SHALL retain their existing operation scope and MUST NOT stage, commit or push merely because create can publish Git. They SHALL use dual session Author fields when writing applicable current content, preserve unrelated text and history, and retain existing readback and close-scope guarantees. The removed publish operation SHALL remain removed.

#### Scenario: Reviewer posts a reply from a dirty checkout
- **WHEN** github-pr reply is requested while local code changes exist
- **THEN** it appends the requested comment with both Author session fields and no Git publication
- **AND** the current posting identity remains distinct from the implementer referenced in the report

#### Scenario: Description update or close is requested
- **WHEN** the user requests only PR description changes or closure
- **THEN** the operation preserves its existing authorized scope without creating commits or pushing
- **AND** close still excludes dependencies, preserves branches and verifies evidence-based Issue closure reasons

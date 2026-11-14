# github-pr Specification

## Purpose

讓 Agent 將 Work Item、OpenSpec Change、分支差異與相關對話整理成人類能理解的 PR，並用精簡回覆交接審查或修正。提供涵蓋必要發布的 create 操作，以及不變動 Git 的 update、reply、close 操作，保留正確目標、真實版本、歷史內容與逐項結果查核。

## Requirements

### Requirement: PR sources combine selected records with relevant discussion
The skill SHALL read explicitly selected Work Items, Changes, or both; otherwise it SHALL identify the current branch and related records. It SHALL always merge relevant current-session discussion and confirmed newer decisions. Missing explicit sources and ambiguous associations MUST be reported before writing, without silently substituting another source.

#### Scenario: Work Item or Change is explicitly selected
- **WHEN** the user selects a Work Item, a Change, or both
- **THEN** the skill reads the selected content and relevant discussion without borrowing unrelated branch records
- **AND** a later confirmed session decision replaces a superseded recorded value

#### Scenario: Only branch and session content exists
- **WHEN** no local tracking record is available
- **THEN** the skill can compose a PR from the actual branch changes and relevant discussion without creating a Work Item, Change, or Issue

#### Scenario: Source selection is missing or ambiguous
- **WHEN** an explicitly selected source is unreadable or several plausible records cannot be uniquely associated
- **THEN** the skill asks for the missing selection or correction before any remote write

### Requirement: PR descriptions distinguish published changes from plans
The skill SHALL inspect the actual selected PR or published base-to-head changes before describing implementation. Source documents and local discussion SHALL explain purpose but MUST NOT prove unpublished implementation, tests, deployment, or acceptance. A PR with design-only changes SHALL be describable without claiming implementation completion.

#### Scenario: Local work is newer than the PR
- **WHEN** local changes or discussion describe a fix absent from the selected remote head
- **THEN** the PR describes it as pending or unpublished, not delivered
- **AND** tests of that local work are not attributed to the published head

#### Scenario: Source contains a detailed internal work log
- **WHEN** records contain Sessions, coordinator fields, decision IDs, or grouped implementation tasks
- **THEN** the PR explains the problem, scope, design or actual changes, checkable results, and relevant open questions in its own words
- **AND** it does not paste or merely shorten the internal record layout

### Requirement: PR formatting uses a minimal frame with optional associations
PR bodies and replies SHALL begin with Handoff, include concise Next actions and end with shared Author. Handoff SHALL identify the verified head branch. Confirmed work and dependency links SHALL be optional and Work Items marked local-only. Bodies SHALL explain purpose, published changes and actual verification. Review, repair, Checkpoint and Closure replies SHALL use corresponding shared content.

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

#### Scenario: Forks contain identically named branches
- **WHEN** PR candidates have the same branch name in different head repositories
- **THEN** discovery and creation verify head owner and repository as well as base and refs before selecting a PR

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
Bodies and replies SHALL end with shared human or agent-assisted Author. Agent posts SHALL retain tool, known root-session model, SESSION-ID and XIRP-SESSION-ID. Unavailable IDs SHALL independently be null with reasons reported and unknown models omitted. Human-direct posts SHALL identify the human without fabricated Agent metadata. Relayed substantive reports SHALL preserve source authorship separately.

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
- **AND** close affects only its PR, preserves branches and leaves linked Issue states unchanged

### Requirement: Update preserves unrelated content and historical records
Update SHALL read the latest description and change authorized content or confirmed associations while preserving unrelated human text, earlier replies, and approval evidence. Managed markers SHALL NOT be required for new PRs. Legacy managed content SHALL remain readable, and unclear section ownership or concurrent summary writers MUST be resolved before replacement.

#### Scenario: Plain or legacy PR contains human notes
- **WHEN** an update targets a description with human notes, with or without legacy markers
- **THEN** the authorized sections are updated and unrelated text and previous comments remain intact
- **AND** uncertain boundaries cause clarification rather than whole-body replacement

#### Scenario: Two writers claim the same summary
- **WHEN** another known writer is concurrently updating the same PR description
- **THEN** the skill obtains a single writer before modifying that shared content

### Requirement: Reply adds actionable review or fix evidence
Reply SHALL append one shared-frame Review, Changes, Checkpoint or Closure comment with Next actions. Reviews SHALL identify actual version, verdict, findings, checks and limits. Repair replies SHALL map changes to stable Finding IDs and fixing evidence. Only Reviewer verification SHALL resolve findings. Prior comments SHALL remain intact. Checkpoint and closure content SHALL retain their distinct evidence requirements.

#### Scenario: Reviewer reports a defect
- **WHEN** an agent posts a changes-required review
- **THEN** its reply identifies the actual reviewed head and actionable items with impact, evidence or location, and a way to check the fix
- **AND** a todo list is understandable without opening the local Work Item

#### Scenario: Implementer reports fixes
- **WHEN** an implementer posts a repair reply
- **THEN** it maps each addressed finding to what changed, a fixing revision, test results, or an evidenced disagreement
- **AND** pending items remain explicit and no tests are invented

#### Scenario: Review has no findings or cannot finish
- **WHEN** review finds no demonstrated defect or required verification is unavailable
- **THEN** the reply reports pass for the checked scope or blocked with concrete limits, without manufacturing tasks or platform approval

### Requirement: Closing a PR affects only confirmed corresponding Issues
Close SHALL use the shared Closure-before-state-change sequence and close only the selected PR without merging. Direct Issue links SHALL convey work association without closure authority. Linked Issues, dependencies, other PRs and branches SHALL remain unchanged. Already closed or merged PRs SHALL report actual state and receive only missing explicitly authorized summary work.

#### Scenario: PR links both task and dependency Issues
- **WHEN** close targets a PR directly addressing Issue A and depending on Issue B or another PR
- **THEN** only the selected PR is closed after its Closure summary is verified
- **AND** Issues A and B and the dependency PR remain unchanged

#### Scenario: No corresponding Issue or ambiguous relationships
- **WHEN** no corresponding Issue exists
- **THEN** close can close only the PR without creating an Issue
- **AND** uncertain optional Issue links are disclosed and remain untouched

#### Scenario: PR closure fails or Issue closure partially succeeds
- **WHEN** the summary or PR closure cannot be confirmed
- **THEN** no Issue is mutated and summary publication and PR state are reported separately
- **AND** a later invocation reconciles state and attempts only the remaining authorized work

#### Scenario: Target is already closed or merged
- **WHEN** close is requested for an already closed or merged PR
- **THEN** the skill reports its actual existing state without reopening, merging, or repeating a completed closure
- **AND** Issue closure requires its own explicit operation and authorization

### Requirement: Every operation verifies stored results and uncertain writes
The skill SHALL use configured gh or GitHub MCP with explicit host, owner, repository, target, and authorized operation. Each write SHALL be read back by its returned identifier and checked for target and content or state. Uncertain writes SHALL be reconciled before retrying, and known denial SHALL stop the affected action without credential changes or probe writes.

#### Scenario: Reply returns a URL
- **WHEN** comment creation reports success
- **THEN** the skill reads that specific comment and verifies its parent PR, repository, and stored content

#### Scenario: A create, update, reply, or close response is uncertain
- **WHEN** a write times out or readback fails
- **THEN** the skill checks the target's actual content, recent records, or state before any retry
- **AND** it reports unresolved uncertainty instead of resending through either channel

### Requirement: Shared review and approval integrations retain their meaning
The shared handoff contract SHALL own the simplified PR and reply templates, and change-review SHALL use compatible presentation without changing its review criteria. Version binding, finding identity, technical verdicts, and human approval SHALL retain their evidence and authority. Approval events SHALL be independently discoverable without requiring an approval block in every PR body.

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
- **THEN** the workflow validates the independent approval event's source, scope, revision, and recording authority
- **AND** technical pass, body edits, and the absence of a mandatory approval block do not confer approval

### Requirement: PR closure summary distinguishes merged and abandoned changes
PR Closure SHALL state published or reviewed revision, intended or existing outcome, delivered changes, verification, unresolved findings and follow-up references. Successful implementation handoff SHALL distinguish ready-to-merge from merged. Close MUST NOT merge. A replaced or abandoned PR SHALL explain its replacement or cancellation without treating its underlying Issue as finished.

#### Scenario: Implementation awaits merge
- **WHEN** the reviewed head passes but no merge occurred
- **THEN** Closure says ready for authorized merge without claiming merged or closing the PR as a substitute

#### Scenario: Replaced proposal
- **WHEN** PR A is replaced by PR B while its Issue remains necessary
- **THEN** Closure links PR B, closes only authorized PR A and leaves the Issue open

#### Scenario: Already merged target
- **WHEN** a summary is explicitly requested after merge
- **THEN** the reply records actual merge evidence without another close or invented acceptance

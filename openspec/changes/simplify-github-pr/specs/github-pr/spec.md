# Spec Delta

## Purpose

讓 Agent 將 Work Item、OpenSpec Change、分支差異與相關對話整理成人類能理解的 PR，並用精簡回覆交接審查或修正。提供不混入 Git 發布的 create、update、reply、close 操作，保留正確目標、真實版本、歷史內容與逐項結果查核。

## ADDED Requirements

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
PR bodies and replies SHALL begin with Handoff and end with Author. Handoff SHALL use branch, not brach, for the verified target head branch. Confirmed Change, Work Item, Issue, and dependency links SHALL be included when available and omitted otherwise. Purpose, design, implementation, review, and fix content SHALL use appropriate headings without mandatory empty sections.

#### Scenario: PR begins without local identifiers
- **WHEN** a published branch has no associated Work Item, Change, or Issue
- **THEN** Handoff contains its verified branch and no empty association fields
- **AND** the body still explains the work without relying on identifiers

#### Scenario: Associations are supplied later
- **WHEN** a later update confirms a Change, Work Item, or directly corresponding Issue
- **THEN** the description can add those associations without creating another PR
- **AND** dependency links remain distinguishable from Issues whose work this PR addresses

### Requirement: Author identifies the current posting session truthfully
Author SHALL identify the current executing tool, known root-session model, and SESSION-ID. An unavailable or withheld session ID SHALL be null with the reason reported; an unknown model SHALL be omitted and reported. Source authors and other agents MUST NOT supply inferred current attribution, and a management session ID MUST NOT be mislabeled as a native ID.

#### Scenario: Records were written by another agent
- **WHEN** the current agent publishes content derived from another agent's records
- **THEN** Author identifies the posting agent and its own known model and Session ID

#### Scenario: Session identity is unavailable or uses another namespace
- **WHEN** no publishable native Session ID is known or the user explicitly chooses a management Session ID
- **THEN** an unavailable value is null, or the selected management ID is explicitly qualified by its namespace
- **AND** no alias is invented and presented as a native ID

### Requirement: Create verifies a real published branch and avoids duplicate PRs
Create SHALL verify the full base and head repositories and refs, an obtainable nonempty remote comparison, and existing PR associations. It SHALL create a Draft PR by default or return one confirmed existing open PR without rewriting it. Similar branch names, titles, or null identifiers MUST NOT establish identity; ambiguity SHALL stop creation.

#### Scenario: Forks contain identically named branches
- **WHEN** PR candidates have the same branch name in different head repositories
- **THEN** discovery and creation verify head owner and repository as well as base and refs before selecting a PR

#### Scenario: The branch is absent remotely or has no changes
- **WHEN** no usable published base-to-head difference exists
- **THEN** the skill reports the missing prerequisite and can return proposed text without claiming PR creation
- **AND** it does not create an empty commit, branch, or placeholder file to manufacture a PR

#### Scenario: One matching PR is already open
- **WHEN** create finds one verified open PR for the selected head and base
- **THEN** it returns that PR without creating another or silently performing update

### Requirement: PR operations do not publish Git changes
Create, update, reply, and close SHALL NOT stage, commit, push, merge, change base, or delete a branch. Publishing Git content SHALL remain a separately authorized operation. The removed publish operation SHALL report the new boundary rather than silently invoke Git or reinterpret itself as update.

#### Scenario: A PR update is requested with a dirty checkout
- **WHEN** local uncommitted work exists while PR description changes are requested
- **THEN** update edits only authorized PR content and leaves all Git work unchanged
- **AND** unpublished work is not described as part of the remote implementation

#### Scenario: An old caller requests publish
- **WHEN** github-pr publish is requested
- **THEN** the skill explains that Git publication must be performed separately and issues no Git write

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
Reply SHALL append a top-level comment using Handoff, an appropriate Review, Report, Fix, or Changes body, and Author. Review content SHALL identify the reviewed revision, verdict, concrete findings, checks, and limits. Fix replies SHALL map fixes or disagreements to findings with revision and validation evidence. Existing comments MUST NOT be rewritten and an implementer's claim MUST NOT resolve a finding without reviewer verification.

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
Close SHALL establish the exact PR and directly corresponding Issues before mutation, close the PR without merging, verify its closed state, then close and verify the confirmed Issues. References, dependencies, and other PRs MUST NOT be closed as corresponding work. Closing SHALL NOT assert implementation acceptance, deployment, or merge.

#### Scenario: PR links both task and dependency Issues
- **WHEN** close targets a PR directly addressing Issue A and depending on Issue B or another PR
- **THEN** only the selected PR and Issue A are closed after target verification
- **AND** Issue B and the dependency PR remain unchanged

#### Scenario: No corresponding Issue or ambiguous relationships
- **WHEN** no corresponding Issue exists
- **THEN** close can close only the PR without creating an Issue
- **AND** if plausible corresponding Issues exist but cannot be classified, the skill asks before any closure

#### Scenario: PR closure fails or Issue closure partially succeeds
- **WHEN** the PR cannot be confirmed closed or one corresponding Issue fails to close
- **THEN** no Issue is closed before confirmed PR closure, and the result reports each completed, failed, or uncertain target separately
- **AND** a later invocation reconciles state and attempts only the remaining authorized work

#### Scenario: Target is already closed or merged
- **WHEN** close is requested for an already closed or merged PR
- **THEN** the skill reports its actual existing state without reopening, merging, or repeating a completed closure
- **AND** it can finish closing explicitly confirmed corresponding Issues within the close request

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

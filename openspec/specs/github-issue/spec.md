# github-issue Specification

## Purpose

讓使用者把指定 Work Item、OpenSpec Change 或目前 Session 的工作內容整理成清楚的 GitHub Issue，並用新增留言保存後續變化。此能力定義 Issue 專屬的來源、格式、關聯與更新行為，同時保留目標核對、授權及結果查核要求。

## Requirements

### Requirement: Source selection follows explicit input before branch context
The skill SHALL use explicitly selected Work Items and/or Changes before branch context, inspect their actual contents, and incorporate relevant current-session discussion. Without explicit selection it SHALL inspect the current branch and related local records. It MUST NOT select the newest or first candidate as a substitute for a verified association.

#### Scenario: Explicit Work Item without Change
- **WHEN** the user selects an existing Work Item without an associated Change
- **THEN** the skill summarizes that Work Item and relevant discussion and omits unavailable optional associations while retaining legacy null compatibility
- **AND** it does not substitute the current branch's unrelated Change

#### Scenario: Explicit Change or combined sources
- **WHEN** the user selects a Change, or a Work Item and Change for the same work
- **THEN** the skill reads the selected artifacts and summarizes their applicable goal, work, decisions, and limitations

#### Scenario: Branch supplies an unambiguous association
- **WHEN** no source is specified and the current branch uniquely corresponds to a Change and related Work Item
- **THEN** the skill reads those records and uses their confirmed identifiers

#### Scenario: Multiple or conflicting source candidates
- **WHEN** source discovery finds multiple plausible candidates or selected sources materially conflict
- **THEN** the skill reports the relevant ambiguity and asks for selection or clarification before writing remotely

#### Scenario: Explicit source does not exist
- **WHEN** an explicitly selected local source cannot be found or read
- **THEN** the skill reports the unavailable source rather than silently switching to session-only creation

### Requirement: Session-only work does not require local tracking artifacts
The skill SHALL allow creation from relevant session discussion without local tracking artifacts. New Handoff SHALL include only confirmed relevant associations and remain readable without associations. Legacy null fields SHALL remain supported. The skill MUST NOT create Work Items, Changes, branches or PRs to fill metadata. Unconfirmed ideas SHALL remain open questions.

#### Scenario: No local association exists
- **WHEN** no source is specified and branch discovery finds no related Work Item or Change
- **THEN** the skill composes the Issue from relevant current-session content without manufacturing Change or Work Item identifiers
- **AND** a PR reference is included only when verified

#### Scenario: Session lacks a concrete subject
- **WHEN** no local source exists and the current discussion does not identify the work to register
- **THEN** the skill asks for the missing subject before creating an Issue

### Requirement: Initial Issue prioritizes work content
A new Issue SHALL begin with Handoff and, when Agent-assisted, end with the reduced shared Author. Pure human-direct content SHALL omit an empty Author section and Agent metadata. Goal SHALL explain the problem and result. Supported completion conditions SHALL use Acceptance criteria or another meaningful heading. Next actions SHALL state immediate continuation. Optional references and associations SHALL appear only when supported. Checkpoint SHALL appear when publishing a handoff state without dumping local logs.

#### Scenario: Sources include detailed implementation tasks
- **WHEN** a Change contains a long tasks document
- **THEN** the Issue explains the meaningful work and completion conditions without copying the entire document
- **AND** its middle sections adapt to the work without empty placeholder sections

#### Scenario: References are local only
- **WHEN** useful source artifacts have not been published
- **THEN** references use repository-relative paths explicitly marked local-only or unpublished
- **AND** no private absolute path or invented remote revision link is published

### Requirement: Current-session decisions are merged with selected records
The skill SHALL merge relevant current-session discussion with whichever records are selected. A decision the user confirmed in the session after a record was written SHALL replace the recorded value. The skill SHALL ask only when it cannot determine which statement is current, and unconfirmed suggestions SHALL remain open questions.

#### Scenario: Session confirms a newer decision than the record
- **WHEN** a selected Work Item records "retry at most 5 times" and the user has since confirmed "at most 3 times" in the current session
- **THEN** the Issue states 3 retries as the current decision without presenting 5 as current
- **AND** the skill does not stop to ask, because the newer confirmation is unambiguous

### Requirement: Issue content is a rewritten handoff-ready task
The skill SHALL rewrite its sources into one task a reader without them can act on, covering problem, impact, scope, work, completion conditions, and open questions as far as the material supports. These are content standards, not mandatory headings. Content MUST NOT keep a record's layout, paste a shortened internal list, substitute identifiers for explanation, or invent decisions, numbers, owners, or dates.

#### Scenario: Sources are rewritten into a handoff-ready task
- **WHEN** a Work Item contains Sessions, coordinator, decision IDs, and per-agent next actions, or a Change contains a grouped implementation task list
- **THEN** the Issue explains the problem, impact, scope, completion conditions, and open questions in its own words
- **AND** it contains no record-only metadata, no task-list numbering or groups copied from the source, and no decision the material does not contain

### Requirement: Author identifies the current posting agent
Agent-assisted Issue bodies and new comments SHALL use the reduced shared Author without mode or human-account fields. Pure human-direct content SHALL omit an empty Author section and Agent metadata. Agent posts SHALL include posting tool, known root-session model and separate SESSION-ID and XIRP-SESSION-ID with honest nulls and reported limits. Unknown models SHALL be omitted. Relayed authors SHALL be distinguished from publishers. Private paths and credential metadata MUST NOT be published.

#### Scenario: Posting agent differs from source author
- **WHEN** an agent summarizes a Work Item written by another agent
- **THEN** Author identifies the current posting tool and known root-session model without claiming those identify all source authors

#### Scenario: Current model is unavailable
- **WHEN** the posting agent cannot establish its current model
- **THEN** it does not infer a model from source records and reports the omitted AI-Assisted-By field

#### Scenario: Issue operation creates new Author content
- **WHEN** an agent creates an Issue or adds progress, Checkpoint or Closure content
- **THEN** its Author has the posting tool, known model and independently populated native/Xirp IDs without mode or human-account labels
- **AND** missing values follow existing omission/null rules without an account identity prompt

#### Scenario: New comment follows a legacy Issue
- **WHEN** an authorized update appends to an Issue whose body has the old mode and human-account fields
- **THEN** the existing body remains unchanged and only the new comment uses the reduced Author format

#### Scenario: Pure human Issue needs no metadata section
- **WHEN** a human directly writes and publishes an Issue without Agent participation
- **THEN** the Issue remains understandable without an Author heading or invented Agent fields

### Requirement: Existing Issue association is verified within the target repository
The skill SHALL prefer an explicit Issue or verify candidate work associations and actual repository metadata, reading bodies and relevant comments. It SHALL reuse one confirmed work and resolve real ambiguity. Local Work Item IDs SHALL be source hints and SHALL NOT alone prove global identity or conflict. Legacy managed fields and null values SHALL remain readable.

#### Scenario: Repeated create has one exact association
- **WHEN** create finds one Issue for the same confirmed source identifiers
- **THEN** it returns that Issue without creating another, rewriting the body, or silently adding a comment

#### Scenario: Several matches or conflicting identifiers
- **WHEN** multiple Issues match or an Issue carries contradictory non-null source identifiers
- **THEN** the skill reports the candidates or conflict and does not write until the target is resolved

#### Scenario: Session-only candidates share null fields
- **WHEN** candidate Issues have null Change and Work Item fields
- **THEN** null equality is not treated as proof they are the same work
- **AND** a known explicit URL is reused, a plausible but uncertain match requires clarification, and otherwise a new session-only Issue can be created

#### Scenario: Association was added in an update comment
- **WHEN** an Issue began session-only and a later comment records its confirmed Change or Work Item
- **THEN** discovery considers that comment when verifying the association without requiring a body rewrite

#### Scenario: Different local records represent the same work
- **WHEN** verified Change and work scope match but local Work Item IDs differ
- **THEN** the difference alone does not block reuse and the local records remain source hints

#### Scenario: Same local ID represents unrelated work
- **WHEN** independent directories contain the same Work Item ID for different work
- **THEN** that ID alone does not authorize reuse or a remote update

### Requirement: Updates append an iteration comment without rewriting history
Update SHALL append one progress or Checkpoint comment using Handoff, substantive content, Next actions and shared Author. Progress SHALL explain this iteration. Handoff summaries SHALL follow shared Checkpoint rules. Update SHALL preserve body, title, state, labels, assignees and prior comments. A requested Issue reply SHALL use this append-only behavior.

#### Scenario: Work has progressed
- **WHEN** the user requests an update for an existing Issue
- **THEN** one new comment explains the new decisions, progress, results, or remaining work as applicable
- **AND** the Issue body, title, state, labels, assignees, and previous comments remain unchanged

#### Scenario: Target uses legacy or handwritten formatting
- **WHEN** the specified Issue has old managed markers, incomplete markers, or no markers
- **THEN** the update is appended as a new comment without rewriting or adopting its body

#### Scenario: Explicit Issue uses different local branch context
- **WHEN** the user specifies an Issue and the current branch relates to different work
- **THEN** the skill follows the explicit Issue's verified association and does not add unrelated branch identifiers

### Requirement: Native operations verify authorization and stored results
The skill SHALL use available configured gh or GitHub MCP with full host/owner/repository and authorized operation, verify actual stored results, and reconcile uncertain writes before retrying. It MUST NOT install clients, change authentication, perform probe writes, or treat read permission as write permission. Missing capabilities and denials SHALL stop the affected operation with an accurate report.

#### Scenario: Comment permission exists without body-edit capability
- **WHEN** the selected client can read the Issue and create comments but cannot edit Issue bodies
- **THEN** an authorized update can proceed using comment capability and readback

#### Scenario: Comment creation returns successfully
- **WHEN** the client returns a comment URL or identifier
- **THEN** the skill reads back that specific comment, confirms its repository, parent Issue, and content, and reports its URL
- **AND** it does not report successful creation of an Issue when it only posted a comment

#### Scenario: Create or comment result is uncertain
- **WHEN** a remote write times out or returns an inconclusive result
- **THEN** the skill reads recent Issues or target comments and checks the intended content and available authorship evidence before retrying
- **AND** if the result remains uncertain it reports uncertainty instead of resending or switching tools to resend

### Requirement: Issue-specific rules coexist with shared PR and Review contracts
The shared contract SHALL own Issue bodies, progress, Checkpoint and Closure templates. Issue close SHALL own Issue state changes while PR close SHALL own its PR target. Native safeguards and lifecycle evidence SHALL remain applicable. Formal requirements SHALL stay in OpenSpec, with Issue summaries linking published artifacts and retaining unresolved acceptance work.

#### Scenario: PR description is updated
- **WHEN** github-pr updates its description after this capability is installed
- **THEN** its shared content frame and human or Agent attribution remain in effect

#### Scenario: Acceptance still waits for real data
- **WHEN** the work requires future data for acceptance
- **THEN** the work explanation or update identifies the necessary window, evidence, owner, and next step as relevant
- **AND** a date arriving, a review pass, or a merge does not imply acceptance or close the Issue

### Requirement: Issue closure is independently authorized and evidenced
Close SHALL require a selected Issue and supported completed or not-planned reason. It SHALL use the shared Closure-before-state-change sequence, verify state and reason, and preserve linked PRs, dependencies and parent work. Required unmet acceptance SHALL prevent a completed verdict. Cancellation SHALL explain replacement or remaining work. Retries SHALL reconcile existing comments and states without duplicate writes or implicit reopening.

#### Scenario: Completed work
- **WHEN** required acceptance has evidence and close is authorized
- **THEN** Closure links results and remaining independent work, then only the selected Issue is closed completed and verified

#### Scenario: Validation pending
- **WHEN** a PR is merged but required real-data acceptance is unavailable
- **THEN** the skill reports pending acceptance without closing the Issue as completed

#### Scenario: Cancellation
- **WHEN** the user authorizes cancelling an Issue
- **THEN** Closure explains why and the Issue is closed not planned without closing linked PRs

#### Scenario: Retry after partial failure
- **WHEN** the comment or state change may have succeeded
- **THEN** readback resolves existing steps, reuses valid evidence and reports any reason mismatch

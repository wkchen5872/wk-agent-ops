# github-change-handoff Specification

## Purpose

Provide durable, versioned handoff between OpenSpec changes and GitHub Issues and pull requests so agents on different sessions or machines can recover the work, next action, and evidence without local discussion records.

## Requirements

### Requirement: Formal requirements have one authority
Issue and pull request content SHALL NOT decide requirements, design, tasks, or acceptance criteria; editing them alone MUST NOT approve a change to those. Issues SHALL hold work tracking and links; PRs SHALL hold published changes and review evidence. Required handoff information MUST remain usable without the conversation or a local Work Item.

#### Scenario: New machine has no Work Item
- **WHEN** an agent opens a linked Issue or PR on another machine
- **THEN** it can identify the Change, available artifact revision, current scope, unresolved work, and next action without a local Work Item
- **AND** a local-only specification is identified as unpublished instead of presented as remotely available

#### Scenario: Acceptance criteria need changing
- **WHEN** an Issue or pull request is edited to describe acceptance criteria that differ from the formal specification
- **THEN** the edit is treated as a record of discussion, not as approval of the new criteria
- **AND** the workflow that owns the specification decides how the criteria change

### Requirement: Writes verify the target and operation context
Before a write, the workflow SHALL verify the full repository target, intended operation, user-authorized scope, and available evidence from the executing tool. It SHALL stop on a known conflict or denial and verify the stored result. Read access MUST NOT imply write permission; incomplete permission metadata alone SHALL NOT require a probe write or block an otherwise authorized operation.

#### Scenario: Repository is readable but the write is denied
- **WHEN** the tool can read a repository but its token or App cannot create the requested Issue or PR
- **THEN** the workflow reports the actual denial and does not claim the write succeeded
- **AND** it does not change authentication or treat read access as write permission

#### Scenario: Permission metadata is incomplete
- **WHEN** the target and authorization are clear and there is no known denial but the native tool cannot fully preflight endpoint permissions
- **THEN** the workflow may perform the requested authorized operation and validate its response and stored result
- **AND** it does not create extra Issues, PRs, commits, or pushes solely to probe permission

#### Scenario: The host matches but the repository does not
- **WHEN** an intended operation targets another owner or repository on the same host
- **THEN** the workflow stops before that write and reports the full target mismatch
- **AND** matching github.com alone is not accepted

#### Scenario: A fork has the same branch name
- **WHEN** base and head repositories differ and another repository contains the same head branch name or SHA
- **THEN** discovery, creation, publication, and readback verify the actual base and head repository identities and refs
- **AND** a tool unable to express the selected fork reports the limitation instead of guessing

### Requirement: Operation checks use native clients without credential reconstruction
The workflow SHALL reuse native Git, gh, or an available GitHub MCP for operation-scoped checks and result verification. Local tool installation, SSH or HTTPS authentication, keys, and credential helpers SHALL remain local configuration. The workflow MUST NOT reconstruct the push principal by parsing credential helpers or SSH greetings, expose credentials, or require a custom identity script or trusted script-blob bootstrap. One tool's login MUST NOT attest another tool's execution identity.

#### Scenario: Git uses an existing SSH or HTTPS configuration
- **WHEN** an authorized publication uses a native Git push route with the verified destination repository and ref
- **THEN** Git performs authentication and reports the push result, and the workflow verifies the actual remote head
- **AND** no helper parser, credential fill, or SSH principal test is required

#### Scenario: Only another tool is authenticated
- **WHEN** gh is authenticated but the selected MCP cannot perform the operation, or the reverse
- **THEN** the other tool's login is not treated as proof that the selected connection works
- **AND** a tool may be selected before a write only within the same existing authorization and after its own target and capability checks

#### Scenario: No custom identity policy or script exists
- **WHEN** the native tool is configured and no explicit account restriction applies
- **THEN** the workflow can proceed with its normal target, authorization, and operation checks
- **AND** it does not require creating an identity policy, installing an identity script, or pinning its blob

#### Scenario: Diagnostic evidence is recorded
- **WHEN** an operation reports its tool, actor, connection, or failure evidence
- **THEN** only non-secret metadata is included and unknown actors are honestly marked unavailable
- **AND** credential configuration, token values, keys, and helper command contents are not copied into output or handoff records

### Requirement: Account restrictions are explicit and optional
The workflow SHALL allow a configured account unless a user or trusted project policy explicitly restricts the operation. An applicable restriction SHALL be checked in the executing context; conflict or unknown compliance SHALL stop that operation. Candidate PR content MUST NOT authorize relaxing trusted restrictions. The workflow MUST NOT require proof that an API account is the human requester or a separate recorder allowlist for an otherwise authorized handoff.

#### Scenario: API, commit, and push use different identities
- **WHEN** the configured identities differ and no applicable explicit restriction forbids the arrangement
- **THEN** the workflow does not block solely because they differ
- **AND** it records known identities with their sources without inventing unavailable principals

#### Scenario: A project requires a particular account
- **WHEN** an explicit trusted restriction requires a specific account and the selected operation uses another account or cannot establish compliance
- **THEN** that operation stops and reports the restriction and missing or conflicting evidence
- **AND** the workflow does not switch accounts or invent a custom credential parser to obtain a pass

#### Scenario: Candidate changes an account restriction
- **WHEN** the reviewed head changes an existing trusted account restriction
- **THEN** the candidate change is not itself permission to bypass that restriction
- **AND** adopting the changed restriction requires the applicable independent user authorization

#### Scenario: Repository access is mistaken for approval authority
- **WHEN** an account can write a repository but there is no identifiable user instruction approving the selected work
- **THEN** repository access alone does not authorize Apply or an approval attestation
- **AND** when an explicit instruction is available the workflow does not add a separate recorder-identity check

#### Scenario: Requester account is unknown or differs from API login
- **WHEN** the user explicitly authorizes the selected work and no applicable account restriction exists
- **THEN** an unknown human GitHub account or a different API login does not block the authorized work
- **AND** the workflow does not ask whether the API account is the user or infer that identity

### Requirement: Issue operations preserve work identity
The Issue entry SHALL offer create, update and close. It SHALL reuse a uniquely verified work association in the selected repository, treat local Work Item IDs as source hints, and resolve genuine scope conflicts before writing. Parent work, direct work and dependencies SHALL remain distinct with release conditions.

#### Scenario: Repeated create invocation
- **WHEN** create is invoked again and one Issue is positively associated with the same Change
- **THEN** the existing Issue is returned without creating a duplicate or silently replacing its body

#### Scenario: Similar titles do not prove association
- **WHEN** search returns an Issue with a similar title
- **THEN** the workflow reads its confirmed associations in body and comments and actual repository metadata and verifies the selected target before reuse
- **AND** a search match alone is not accepted as a positive association

#### Scenario: Several matching Issues
- **WHEN** discovery finds multiple plausible Issues without a unique explicit association
- **THEN** the workflow reports the candidates and does not choose the first or create another Issue

#### Scenario: Work splits into dependent Changes
- **WHEN** a parent objective is split into several Changes
- **THEN** the tracking links identify each child Change and its Issue or PR
- **AND** dependencies state whether they require design approval, merge, deployment, or acceptance instead of only naming another task

### Requirement: PR operations separate publication from description updates
The PR entry SHALL expose create, update, reply and close. Create SHALL retain necessary scoped Git publication. Other operations SHALL use only their authorized metadata or state scope. Publishing new commits to an existing PR SHALL remain an authorized Git action followed by an optional update. Reuse SHALL verify repository, branch and work association.

#### Scenario: Reviewer needs to add a report link
- **WHEN** an authorized caller invokes update for an existing PR
- **THEN** only the requested description section is updated
- **AND** no staging, commit, push, merge, base change, or closure is triggered

#### Scenario: Same PR receives implementation
- **WHEN** the selected PR already contains the design revision and its authorized branch receives implementation
- **THEN** authorized Git publication updates that same branch and verifies its new remote head, and update describes the published content
- **AND** it does not open a second PR automatically

### Requirement: Publication inspects the full change before committing
Create and separately authorized Git publication SHALL inspect staged, unstaged, untracked, and base-to-head changes before any commit delegation. The workflow MUST stop when a stage-all writer would include unauthorized work. It SHALL reuse valid existing commits, invoke the existing writer only for authorized uncommitted content, respect its input contract and checks, then verify the pushed head before publishing a matching PR description.

#### Scenario: Unrelated dirty file exists
- **WHEN** the selected Change has uncommitted work and another agent has an unrelated dirty file
- **THEN** the workflow stops before invoking a writer that stages all files
- **AND** it preserves the unrelated work without stash, reset, discard, or force staging

#### Scenario: Active Change is not archived
- **WHEN** publication delegates a commit for an active Change
- **THEN** it uses the writer's valid standalone association rules
- **AND** it does not fabricate an archive path, pass an incomplete archive argument pair, or archive the Change to enable committing

#### Scenario: Existing commit or failed push
- **WHEN** the required content is already committed but push fails
- **THEN** no replacement or empty commit is created
- **AND** the result distinguishes the local commit from the unavailable remote revision and does not claim successful publication

### Requirement: Shared content is updated without erasing other authors
Issue updates SHALL append comments. PR description updates SHALL read current content and change only authorized sections while preserving unrelated text and history. New bodies SHALL use shared headings without mandatory managed markers. Legacy sections SHALL remain readable. Concurrent shared-body writers SHALL resolve ownership before replacement.

#### Scenario: Human edits outside managed section
- **WHEN** the latest PR body contains a human note outside the managed section
- **THEN** the updated body preserves the note and other reviewers' records
- **AND** a missing or ambiguous section boundary is reported before a destructive replacement

#### Scenario: Another summary writer is active
- **WHEN** two agents claim the same PR summary section concurrently
- **THEN** the workflow requires one designated writer or reports the conflict before replacement
- **AND** read-before-write alone is not reported as a concurrency lock

### Requirement: Provenance records known event participants safely
Agent posts SHALL retain current tool, known root-session model and separate native/Xirp IDs, without Author mode or human-account fields or synonymous replacements. Unknown values SHALL remain honest. Pure human-direct posts SHALL omit empty Author sections and Agent metadata. Relayed substantive reports SHALL identify original author and source separately from the posting Agent. Legacy records SHALL remain readable without rewriting history.

#### Scenario: Model or session is unavailable
- **WHEN** the current model or native Session ID is unknown or not approved for disclosure
- **THEN** the workflow reports the omission, uses null for unavailable Session IDs and keeps aliases separate
- **AND** it does not infer a model from history or mislabel an alias as a native ID

#### Scenario: Machine information is recorded
- **WHEN** a record includes machine context
- **THEN** it uses a user-controlled neutral machine alias
- **AND** it does not publish raw hostname, private absolute Work Item paths, credentials, or an invented provider email

#### Scenario: Default remote provenance disclosure
- **WHEN** an Agent-assisted Issue, PR, or Review record is published without a stricter explicit project or user restriction
- **THEN** it retains the executing tool, known model, and known native session ID in dedicated fields
- **AND** unknown values are not guessed and routine posts do not require machine metadata

#### Scenario: Agent posts with reduced Author fields
- **WHEN** an agent creates or updates an Issue or PR body or publishes a review, repair, Checkpoint or Closure reply
- **THEN** Author retains Co-Authored-By, known AI-Assisted-By and both SESSION-ID and XIRP-SESSION-ID
- **AND** it omits the mode and human-account fields without adding synonymous labels or treating the API account as the requester

#### Scenario: A human directly publishes without an agent
- **WHEN** the content is written and published directly by a human without Agent assistance
- **THEN** it has no empty Author section or fabricated Agent fields and retains meaningful work content and Next actions

#### Scenario: Agent publishes on behalf of a human
- **WHEN** a human asks an agent to prepare or publish content
- **THEN** the new content retains that posting Agent's metadata rather than using the human-direct exception

#### Scenario: A substantive report is relayed
- **WHEN** the posting agent relays another author's Review or implementation report
- **THEN** it preserves the original author and verified source separately from its own metadata without requiring a mode label
- **AND** unknown original identity is not invented and a verified publisher alone does not become the implementer

#### Scenario: Old Author contains removed fields
- **WHEN** a consumer reads an existing record containing mode, human-account or old relay markers
- **THEN** it can recover the known source and Session namespaces without rewriting that record or copying removed fields into new output

### Requirement: Remote review records extend a shared local baseline
The review identity rules (verdict, phase, review ID, finding ID, and finding states) SHALL be held identically by the review skill and the pull request entry, reusing local review field and finding-status semantics; the review skill SHALL also hold the full review baseline and provenance. Verdict SHALL be pass, changes-required, or blocked. A review ID SHALL be assignable before publication and unique within the PR; each finding SHALL retain its origin-review ID and local finding number across later rounds.

#### Scenario: Report has not been published yet
- **WHEN** a reviewer prepares its first report before a report URL exists
- **THEN** it assigns a unique reviewer-session alias plus round identifier and uses that origin identifier for its findings
- **AND** later reports retain the original finding IDs instead of deriving them from a nonexistent or changing URL

#### Scenario: The pull request entry writes a review reply on its own
- **WHEN** github-pr reply is invoked directly to post a first-round review or a fix reply that refers to findings
- **THEN** it applies the verdict, phase, review ID, finding ID, and finding-state rules from its own files
- **AND** those rules are identical to the ones the review skill holds

### Requirement: Review reports expose session and Git baseline explicitly
Remote Review replies SHALL use Handoff, version-bound Review, Verification, Next actions and Author. Full Scope and Baseline, Findings, Summary and Limitations records SHALL remain available as supplementary evidence. Reports SHALL identify reviewed and checked content, separate IDs from aliases, and expose unpublished or mismatched versions without fabricating evidence.

#### Scenario: Native session ID is supplied by the user
- **WHEN** the reviewer knows a native session ID from explicit user input
- **THEN** the report records it separately from the local alias and labels its user-provided source when disclosure is permitted
- **AND** withheld or unavailable IDs remain null with the reason rather than being replaced by invented values

#### Scenario: Local checks differ from the published Git revision
- **WHEN** the checkout HEAD, comparison baseline, or unpublished content differs from the selected PR revision
- **THEN** Scope and Baseline identifies those differences and the actual content checked
- **AND** neither the branch name nor a HEAD-only reference is used to imply that all local evidence verifies the published PR

### Requirement: Human design approval is recoverable and versioned
Published approval records SHALL preserve source, scope, revision and honest recording metadata without requiring a human GitHub account or recorder allowlist. They SHALL be discoverable from the pull request and comparable against the actual current design content. A record's author SHALL identify only the publisher. Reading or publishing a record MUST NOT require a prior PR event; whether an instruction authorizes implementation is defined by the workflow that owns the lifecycle. The pull request entry skill SHALL hold the record format and its reading rules.

#### Scenario: New session starts implementation
- **WHEN** a new session relies on a published approval record for the Change it is about to implement
- **THEN** it reads the latest valid record and compares its scope and revision with the actual current design content, including uncommitted and untracked files
- **AND** an unavailable baseline or a failed comparison is reported as unverifiable rather than treated as unchanged

#### Scenario: Approval is relayed from the user
- **WHEN** publication of an existing explicit user instruction is authorized
- **THEN** the reply preserves the instruction source, approved scope and revision, recording identity and honest time precision; unknown human GitHub identifiers are omitted
- **AND** a receiving session checks the source and content without an additional recorder allowlist or requiring the private original conversation

#### Scenario: Body claims an authorized recorder without matching authorship
- **WHEN** a body merely claims a recorder or approval without an identifiable user instruction covering the design
- **THEN** that claim is not accepted as an approval record
- **AND** the actual comment author is recorded as the publisher rather than used as proof of human identity or intent

#### Scenario: Explicit implementation instruction has no PR event
- **WHEN** implementation has been explicitly requested and the pull request has no approval record
- **THEN** the lookup reports that no record was found without demanding that one be published
- **AND** no approval record is published unless remote publication is separately requested

#### Scenario: Only planning or a technical verdict exists
- **WHEN** the only evidence on the pull request is a planning request or an agent's technical pass
- **THEN** neither is reported as an approval record

#### Scenario: Design or authorization changes materially
- **WHEN** the approved design later changes materially or the instruction is withdrawn, and publishing that fact is requested
- **THEN** a new superseding record is appended that points at the earlier one
- **AND** historical records remain intact and are neither edited nor deleted

#### Scenario: Legacy approval is read
- **WHEN** an existing event has the old approved_by field, marker or source kinds
- **THEN** it remains readable with its actual source and version, without rewriting history or demanding another account confirmation

### Requirement: Execution channels preserve equivalent handoff guarantees
Issue, PR, Review, and comment operations SHALL use an available, already configured gh or GitHub MCP with explicit target and operation context. Commit and push SHALL use native Git. Shared templates, duplicate reconciliation, ownership, version evidence, and user authorization SHALL remain equivalent across execution channels without requiring a new adapter framework. Missing capability SHALL be reported honestly; installation and authentication configuration MUST NOT be changed automatically.

#### Scenario: gh is unavailable but MCP is usable
- **WHEN** an authorized operation can be performed by an available configured MCP and gh is unavailable
- **THEN** the workflow may select that MCP after verifying its own target and capability
- **AND** gh or a custom preflight script is not an additional prerequisite

#### Scenario: Neither channel can perform the operation
- **WHEN** no available configured client has the required capability or the operation is explicitly denied
- **THEN** the workflow reports the missing prerequisite or denial and stops the affected operation
- **AND** it does not install a tool, change authentication, or claim success

#### Scenario: Request is retried after uncertain remote response
- **WHEN** a write times out without a confirmed remote result
- **THEN** the workflow reconciles existing Issue, PR, review, or remote-ref state before any retry, including a retry through another channel
- **AND** an unresolved result is reported instead of blindly repeating the write

#### Scenario: Managed documentation includes a diagram
- **WHEN** the shared handoff documentation and its referenced workflow SVG change
- **THEN** reinstalling updates both managed assets while preserving unrelated project-owned files
- **AND** a copied-once diagram is not reported as an updated managed artifact

#### Scenario: Existing custom preflight is retired
- **WHEN** the new workflow is installed for a new or existing project
- **THEN** the old identity-check script is no longer installed or required by Skills, rules, or the protocol
- **AND** unrelated or locally modified project scripts and authentication configuration are preserved rather than indiscriminately deleted

### Requirement: Team publication uses one shared content frame
Issue and PR entries SHALL use one shared content frame for bodies, progress, reviews, fixes, checkpoints and closure. Each entry skill SHALL hold the copy of that frame it needs, and the shared parts of those copies SHALL be identical. New posts SHALL start with Handoff, explain their purpose and include concise Next actions. Agent-assisted posts SHALL end with the reduced shared Author; pure human-direct posts SHALL omit empty Author sections and Agent metadata. Unknown optional associations and empty optional sections SHALL be omitted. PR bodies SHALL identify the verified head branch. Next actions SHALL state genuine continuation, waiting or no remaining action.

#### Scenario: Human opens unplanned work
- **WHEN** a human publishes a concrete request without a Change or branch
- **THEN** the post has a readable goal, supported completion conditions, Next actions without an empty Author section, Agent metadata or manufactured tracking records

#### Scenario: Agent publishes linked work
- **WHEN** an agent posts with confirmed Change, branch and related Issue or PR
- **THEN** Handoff includes relevant associations and marks a local Work Item local-only

#### Scenario: Next step is unknown
- **WHEN** the sources establish no owner or actionable next step
- **THEN** the post states what needs confirmation without inventing an assignee or deadline

#### Scenario: The frame differs between the two entries
- **WHEN** the shared frame rules held by the Issue entry and the PR entry are not identical
- **THEN** the project's checks report the difference before the skills are released

### Requirement: Checkpoint summarizes recoverable published context
A pause, transfer or substantial multi-round discussion SHALL support a self-contained Checkpoint through Issue update or PR reply. It SHALL identify current state, confirmed decisions or results, open questions, published version or unavailable work, evidence and Next actions. Routine progress SHALL stay concise. Receivers SHALL reconcile later events and current versions. Checkpoints SHALL link formal tasks instead of duplicating them.

#### Scenario: Transfer without local records
- **WHEN** another environment lacks the original Work Item
- **THEN** the checkpoint explains known facts, unavailable work and continuation using published references

#### Scenario: Later event supersedes summary
- **WHEN** a fix or decision was posted after the last checkpoint
- **THEN** the receiver reconciles that event and current version instead of assuming the latest checkpoint label proves freshness

#### Scenario: Parallel summaries disagree
- **WHEN** overlapping checkpoints claim conflicting state
- **THEN** the conflict is exposed for coordination rather than silently resolved by timestamp or a claimed read-before-write lock

### Requirement: Closure preserves outcome evidence before state mutation
Closing an Issue or PR SHALL first publish and confirm a Handoff, Closure and Next actions summary, with the shared reduced Author for Agent-assisted content and no empty Author for pure human-direct content. Closure SHALL explain intended outcome, delivered or cancelled scope, verification, remaining work and references. Only then SHALL the authorized state change run and be read back. Summaries SHALL NOT attest unperformed close or merge actions. Partial results and retries SHALL be reconciled independently.

#### Scenario: Summary succeeded but close failed
- **WHEN** Closure was confirmed but the state operation failed
- **THEN** the result preserves the summary URL and actual state, and retry reuses unchanged valid evidence

#### Scenario: Summary result is uncertain
- **WHEN** the closure comment times out or cannot be verified
- **THEN** the skill reconciles the comment before closing or posting again

#### Scenario: New work arrives before closing
- **WHEN** the target changes after summary preparation
- **THEN** the skill reconciles scope or version and publishes new closure evidence when needed

### Requirement: Reference examples demonstrate the full publication lifecycle
Skill references SHALL provide coherent examples of create, update, review, fix, pass, checkpoint and closure with the shared frame. Synthetic identities, revisions and results SHALL be labeled. Examples SHALL cover human authors, missing Agent metadata, local-only records, cancellation and partial failure. They SHALL be the complete examples for their own skill and SHALL agree with the frame that skill holds, without depending on a separate format document.

#### Scenario: Full PR lifecycle
- **WHEN** a reader follows the PR reference through repair and closure
- **THEN** Finding IDs, versions, Author and Next actions remain consistent across rounds

#### Scenario: Human and unknown metadata
- **WHEN** a human posts directly or Agent metadata is unavailable
- **THEN** the human example invents no Agent fields and the Agent example discloses unknown values

### Requirement: Integration guide describes workflow touchpoints instead of post formats
The managed GitHub handoff document SHALL explain only how the development workflow connects to GitHub collaboration: at which points an Issue or pull request is involved, which entry skill and operation is invoked, what information is passed in and returned, and which points are optional. It MUST NOT contain post templates or field rules; for those it SHALL name the entry skill that holds them. Reading it MUST NOT be a prerequisite for running an entry skill.

#### Scenario: Reader looks for a post format
- **WHEN** an agent opens the handoff document to learn how a pull request description or an Issue comment is written
- **THEN** the document names the entry skill that holds that format and where the skill is installed
- **AND** the document itself contains no body template, reply template, or Author field layout

#### Scenario: Reader coordinates a Change with GitHub
- **WHEN** an agent needs to know when the define, implement, review, or finish stage touches GitHub
- **THEN** the document lists, for that stage, the entry skill and operation, the information handed over, the result returned, and whether the step is optional

#### Scenario: Tool loads only AGENTS.md
- **WHEN** a tool that does not load skills follows the root instruction file to the managed protocol and then to the handoff document
- **THEN** the paths the document gives for the entry skills resolve to installed files
- **AND** the tool can reach the format and write rules without a provider-specific rules directory

#### Scenario: Existing project still points at the document
- **WHEN** a project's own instruction file, installed before this change, tells the agent to read the handoff document before using Issues or pull requests
- **THEN** the document at that unchanged path directs the agent to the entry skills

### Requirement: Define stage accepts Issue-first and Change-first entry
Planning SHALL be able to start either from an existing Issue or from a locally created Change. Starting from an Issue, the agent SHALL read its problem statement, acceptance information, and open questions, then create or reuse the corresponding Change. Starting from a Change, an Issue SHALL be created or reused only when tracking is wanted, and MAY be omitted. An existing Issue for the same work MUST NOT be duplicated. Both entries SHALL hand the same outputs to implementation.

#### Scenario: A colleague opened the Issue first
- **WHEN** another person has opened an Issue and the user takes it over for planning
- **THEN** the agent reads the Issue's problem, impact, acceptance information, and open questions and creates or reuses the corresponding Change, which cites that Issue
- **AND** no second Issue is created and the original Issue body is not rewritten

#### Scenario: The Issue lacks acceptance information
- **WHEN** the Issue taken over does not state how completion is judged
- **THEN** the planning artifacts record the missing acceptance information as an open question
- **AND** the agent neither invents acceptance criteria nor edits the Issue to add them without a request

#### Scenario: The Change association is recorded on the Issue
- **WHEN** the Change exists and the user asks to record it on the Issue that started the work
- **THEN** the Issue update operation appends a comment with the confirmed Change and branch
- **AND** nothing is written to the Issue without that request

#### Scenario: The Change is created first
- **WHEN** the user creates a Change locally with no Issue
- **THEN** planning completes without an Issue
- **AND** an Issue is created afterward only when the user wants tracking, reusing an existing Issue for the same work when one is found

#### Scenario: Either entry hands over to implementation
- **WHEN** planning from either entry has been confirmed by the user
- **THEN** implementation receives the Change, the branch, the confirmed scope, and the implementation authorization
- **AND** an Issue is included only when one exists

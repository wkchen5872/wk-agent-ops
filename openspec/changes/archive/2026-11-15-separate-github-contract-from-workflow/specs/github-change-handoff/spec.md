# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

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

### Requirement: Reference examples demonstrate the full publication lifecycle
Skill references SHALL provide coherent examples of create, update, review, fix, pass, checkpoint and closure with the shared frame. Synthetic identities, revisions and results SHALL be labeled. Examples SHALL cover human authors, missing Agent metadata, local-only records, cancellation and partial failure. They SHALL be the complete examples for their own skill and SHALL agree with the frame that skill holds, without depending on a separate format document.

#### Scenario: Full PR lifecycle
- **WHEN** a reader follows the PR reference through repair and closure
- **THEN** Finding IDs, versions, Author and Next actions remain consistent across rounds

#### Scenario: Human and unknown metadata
- **WHEN** a human posts directly or Agent metadata is unavailable
- **THEN** the human example invents no Agent fields and the Agent example discloses unknown values

## REMOVED Requirements

### Requirement: Lifecycle transitions retain their own evidence and authority
**Reason**: This requirement governs when work may move between stages. That decision applies with or without GitHub and belongs to the workflow, not to the GitHub handoff.
**Migration**: The requirement and its scenarios are restated in `openspec-change-lifecycle` as "Lifecycle stages retain their own evidence and authority". The fields an Issue comment records while acceptance waits for real data remain defined by `github-issue`.

### Requirement: Finalization changes receive a new version-bound review
**Reason**: Reviewing the head produced by archive and documentation commits is a delivery step owned by the completion and review workflows.
**Migration**: `openspec-commit` already requires review evidence for the final published head ("Successful PR handoff uses the verified final published version") and gains the already-merged pull request scenario. `change-review` gains "Final-version review narrows only with diff evidence" for the narrowed and broadened review cases.

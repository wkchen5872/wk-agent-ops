# Spec Delta

## MODIFIED Requirements

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
Each new body or comment SHALL identify human-direct or agent-assisted authorship. Agent posts SHALL retain current posting tool, known root-session model and separate native and Xirp IDs. Unknown identities SHALL remain honest. Relayed substantive reports SHALL identify their original author and source separately. Extended provenance SHALL appear only when needed for evidence.

#### Scenario: Model or session is unavailable
- **WHEN** the current model or native Session ID is unknown or not approved for disclosure
- **THEN** the workflow reports the omission, uses null for unavailable Session IDs and keeps aliases separate
- **AND** it does not infer a model from history or mislabel an alias as a native ID

#### Scenario: Machine information is recorded
- **WHEN** a record includes machine context
- **THEN** it uses a user-controlled neutral machine alias
- **AND** it does not publish raw hostname, private absolute Work Item paths, credentials, or an invented provider email

#### Scenario: Default remote provenance disclosure
- **WHEN** an Issue, PR, or Review record is published without a stricter explicit project or user restriction
- **THEN** it retains the executing tool, known model, and known native session ID in dedicated fields
- **AND** unknown values are not guessed and routine posts do not require machine metadata


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


## ADDED Requirements

### Requirement: Team publication uses one shared content frame
The shared contract SHALL own Issue and PR templates for bodies, progress, reviews, fixes, checkpoints and closure. New posts SHALL start with Handoff, explain their purpose, include concise Next actions and end with Author. Unknown optional associations and empty optional sections SHALL be omitted. PR bodies SHALL identify the verified head branch. Next actions SHALL state genuine continuation, waiting or no remaining action.

#### Scenario: Human opens unplanned work
- **WHEN** a human publishes a concrete request without a Change or branch
- **THEN** the post has a readable goal, supported completion conditions, Next actions and human Author without manufacturing tracking records

#### Scenario: Agent publishes linked work
- **WHEN** an agent posts with confirmed Change, branch and related Issue or PR
- **THEN** Handoff includes relevant associations and marks a local Work Item local-only

#### Scenario: Next step is unknown
- **WHEN** the sources establish no owner or actionable next step
- **THEN** the post states what needs confirmation without inventing an assignee or deadline


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
Closing an Issue or PR SHALL first publish and confirm a Handoff, Closure, Next actions and Author summary. Closure SHALL explain intended outcome, delivered or cancelled scope, verification, remaining work and references. Only then SHALL the authorized state change run and be read back. Summaries SHALL NOT attest unperformed close or merge actions. Partial results and retries SHALL be reconciled independently.

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
Skill references SHALL provide coherent examples of create, update, review, fix, pass, checkpoint and closure with the shared frame. Synthetic identities, revisions and results SHALL be labeled. Examples SHALL cover human authors, missing Agent metadata, local-only records, cancellation and partial failure. They SHALL link the common contract rather than define a competing schema.

#### Scenario: Full PR lifecycle
- **WHEN** a reader follows the PR reference through repair and closure
- **THEN** Finding IDs, versions, Author and Next actions remain consistent across rounds

#### Scenario: Human and unknown metadata
- **WHEN** a human posts directly or Agent metadata is unavailable
- **THEN** the human example invents no Agent fields and the Agent example discloses unknown values


## Purpose

Define disposable, local, cross-session collaboration records — Work Items — that hold
requirement exploration, independent multi-agent analysis, agreed decisions, and review notes
before and alongside formal specifications: where records live, how the convention is delivered
and loaded, who may write what, how evidence is marked, which outcomes must reach a formal home,
and who may delete what.

## ADDED Requirements

### Requirement: Records live in the directory actually being worked in
Work Item records SHALL live under `work-items/WI-*/` in the project or linked worktree root the
agent actually operates in. The agent SHALL resolve that root from its own working directory
rather than from a path mentioned in conversation, and SHALL list `work-items/WI-*/` by explicit
path rather than relying on code search or Git file listings.

#### Scenario: Conversation path differs from the working directory
- **WHEN** the conversation names a project path that differs from the tool's actual working directory
- **THEN** the agent resolves the real root it operates in before looking for records

#### Scenario: Records are found by explicit path
- **WHEN** an agent checks whether a reusable record exists
- **THEN** it lists `work-items/WI-*/` under the resolved root by explicit path

### Requirement: Records stay out of project Git
Records MUST NOT be added to project Git, and an agent MUST NOT force-add them past the ignore
rule. Before the first write the agent SHALL confirm the ignore rule is effective; when it is
missing it SHALL add the rule only under existing file-modification authority, and otherwise
report. When records are already tracked it SHALL report and MUST NOT modify the Git index.

#### Scenario: First write into a project without the rule
- **WHEN** an agent is about to create the first record and no equivalent ignore rule exists
- **THEN** it reports the missing rule, adding it only when file modification is already authorized
- **AND** it does not force-add any record

#### Scenario: Untracked records are invisible to normal staging
- **WHEN** untracked records exist and the rules in effect resolve that path as ignored
- **THEN** `git status` reports them as ignored and `git add -A` stages no record file

#### Scenario: Effect comes only from a non-versioned source
- **WHEN** the records resolve as ignored only because of a repository-local exclude file or a
  personal global excludes file
- **THEN** the agent treats the project requirement as unmet, because the project carries no rule
- **AND** it reports that a fresh clone would have no protection, and does not change personal or
  repository-local configuration

#### Scenario: A later negation re-includes the records
- **WHEN** a negation after the rule makes the records not actually ignored, although the rule line
  is present
- **THEN** the agent treats protection as absent despite the rule line and reports it
- **AND** it does not write records until the condition is resolved under existing authority

#### Scenario: A parent-level rule also hides the convention
- **WHEN** a parent-level rule ignores the whole `work-items/` directory, so the records are ignored
  but the convention file cannot be tracked
- **THEN** the agent reports that the two-way condition fails because the convention is untrackable
- **AND** it does not describe the records as merely unignored

#### Scenario: Records are already tracked
- **WHEN** a record file inside `work-items/WI-*/` is tracked
- **THEN** the agent reports the condition, states that protection is not in force for that file,
  and leaves the Git index unchanged

### Requirement: No shared or synchronized record storage
No store outside the repository, separate records repository, global index, or cross-worktree
copying, moving, searching, or synchronization SHALL be created. A directory without records is
a normal state.

#### Scenario: Work continues in another worktree
- **WHEN** work continues in a worktree that has no local record
- **THEN** that is treated as normal and nothing is copied, moved, or reconstructed from elsewhere

### Requirement: The convention has a single source and loads on demand
The convention SHALL be delivered as one managed file at `work-items/AGENTS.md`, refreshed by
re-running the installer, and SHALL be the single source of its rules. Activation entries in
provider-native channels and in the shared operating protocol SHALL be short pointers that
direct an agent to read that file when the task needs cross-session temporary records, and MUST
NOT restate its rules or load its full text unconditionally at session start.

#### Scenario: Convention text exists in exactly one place
- **WHEN** the installed project is scanned for the convention's rules
- **THEN** the full rules appear only in `work-items/AGENTS.md`
- **AND** every other mention is a pointer to that file

#### Scenario: A task that needs no records does not load the convention
- **WHEN** a session handles a short question with no cross-session tracking need
- **THEN** no activation entry requires reading the full convention, and no Work Item is created

### Requirement: Reuse before creation, and report ambiguity
An agent SHALL reuse the existing record for the same topic in the same directory. A new session
alone SHALL NOT justify a new Work Item. Creation is allowed when the user asks for records or a
concrete task needs cross-session or multi-agent collaboration. When several candidates are
plausible and the agent cannot decide, it SHALL report the ambiguity and MUST NOT merge, pick
arbitrarily, or create a duplicate.

#### Scenario: Second tool joins the same topic in the same directory
- **WHEN** another agent starts on a topic that already has a record in that directory
- **THEN** it reuses that record instead of creating its own

#### Scenario: Two plausible candidates
- **WHEN** two existing records could both match the current task
- **THEN** the agent reports the ambiguity and waits for the user to choose

#### Scenario: One-off question
- **WHEN** a session answers a single conceptual question with no tracking need
- **THEN** no Work Item is created

### Requirement: Identifier is local and stable
Directory names SHALL follow `WI-YYYYMMDD-short-slug` using the real creation date, with a
lowercase slug. The identifier need only be unique within the current working directory and
SHALL NOT be renamed when the title changes. One OpenSpec change MAY correspond to records in
several worktrees.

#### Scenario: Same change discussed in two worktrees
- **WHEN** two worktrees each hold a record pointing at the same OpenSpec change
- **THEN** both are valid and neither is required to be merged or removed

#### Scenario: Title is revised
- **WHEN** a record's title changes
- **THEN** its directory name stays the same

### Requirement: Required files and README fields
A Work Item SHALL contain `README.md`, `context.md`, and `decisions.md`, with `agents/` and
`reviews/` created only when needed. `README.md` SHALL carry `id`, `title`, `status`,
`openspec_change`, `coordinator`, `created_at`, and `updated_at`. It MUST NOT carry `branch` or
`worktree` fields, and MUST NOT hold a second copy of OpenSpec tasks or implementation progress.

#### Scenario: Values are not yet known
- **WHEN** a record is created before a coordinator or change is known
- **THEN** those fields are `null` rather than guessed, and no template example is left as content

#### Scenario: Change is created later
- **WHEN** an OpenSpec change is created for the record
- **THEN** `openspec_change` is updated and tasks remain only in the OpenSpec artifacts

### Requirement: Status set and closure authority
Status SHALL be exactly one of `active`, `parked`, `closed`, `cancelled`, where `closed` means
local collaboration ended and necessary outcomes were handed off, not that code merged or
shipped. Moving to `closed` or `cancelled` SHALL require user confirmation or a previously stated
explicit rule.

#### Scenario: Change is created while discussion continues
- **WHEN** an OpenSpec change is created for an active record
- **THEN** the status stays `active` until the user confirms closure

#### Scenario: Agent stops responding
- **WHEN** a session ends or a test run finishes
- **THEN** the status is not changed to `closed` automatically

### Requirement: Write ownership across several agents
The coordinator SHALL own `README.md`, `context.md`, and `decisions.md`; every other participant
SHALL write to its own `agents/` or `reviews/` file. An agent MUST NOT modify or delete another
agent's records and SHALL rebut by citing evidence in its own file. Before each write it SHALL
re-read the target and apply a local update that preserves others' content.

#### Scenario: Reviewer disagrees with an analysis
- **WHEN** a reviewer finds another agent's analysis wrong
- **THEN** it records the rebuttal with evidence in its own file, leaving the other file unchanged

#### Scenario: Concurrent change detected
- **WHEN** a shared file changed since it was read
- **THEN** the agent re-reads and merges rather than overwriting the whole file

### Requirement: Coordinator role is assigned, not assumed
The creator of a record SHALL be its initial coordinator. An agent joining an existing record
MUST NOT take over that role without the user's instruction or prior explicit authorization.
Session identifiers MAY be local aliases and MUST NOT impersonate a tool-provided session ID.

#### Scenario: Another tool joins an existing record
- **WHEN** a second agent starts work on an existing record
- **THEN** it writes to its own file and does not update the shared summary as coordinator

### Requirement: Write ownership does not widen write authority
File ownership inside a Work Item SHALL determine who may write which record, and SHALL NOT relax
the project's one-active-writer-per-worktree rule or authorize concurrent writers in one worktree.
It grants no authority over product code, specifications, or Git state. Participants collaborate
either in sequence within one worktree, with the writer role handed over, or concurrently in
separate worktrees holding their own local records.

#### Scenario: Two agents want to work in the same worktree at once
- **WHEN** a second agent joins while another is the active writer in that worktree
- **THEN** it does not write concurrently; the writer role is handed over, or it works in a separate
  worktree with its own records

#### Scenario: Record authority is mistaken for change authority
- **WHEN** an agent may write its own analysis file
- **THEN** that permission alone does not let it modify product code, specifications, or Git state

### Requirement: Record new information with marked evidence
While bound to a Work Item, an agent SHALL write materially new information into the files it
owns before the end of that reply, and SHALL write nothing when there is no substantive progress.
Records SHALL distinguish fact, assumption, recommendation, and items awaiting verification, and
SHALL mark the source of each as user-provided, retrieved with a checkable reference, unverified
prior knowledge, or still needing external lookup.

#### Scenario: Claim that was not verified in this project
- **WHEN** an agent records a conclusion it could not check against this project
- **THEN** it marks the conclusion as unverified rather than as an established project fact

#### Scenario: Reply with no substantive progress
- **WHEN** a turn produces no new requirement, fact, risk, option, or decision
- **THEN** no record file is updated

### Requirement: No fabricated or borrowed evidence
An agent MUST NOT fabricate sources, line numbers, commits, or test executions or results, and
SHALL state that something is undetermined when it cannot verify it. Another agent's report is an
input to be checked, not independent evidence; when restating it the agent SHALL attribute it and
say whether it verified the claim itself.

#### Scenario: Verification is impossible in this environment
- **WHEN** a check cannot be run
- **THEN** the record says so explicitly instead of reporting an assumed result

#### Scenario: Restating another agent's finding
- **WHEN** an agent repeats a finding from another agent's analysis
- **THEN** it names the source and states whether it verified the finding

### Requirement: Excluded content
Records MUST NOT store full chat transcripts, verbatim internal reasoning, redundant
restatement, unused full logs, or credentials, tokens, API keys, or unnecessary personal data.
The ignore rule SHALL NOT be treated as authorization to store sensitive data.

#### Scenario: A credential appears during investigation
- **WHEN** an agent encounters a token or key while investigating
- **THEN** it is not written into any record, even though records are ignored by Git

### Requirement: Independent analysis is ordered before cross-reading
When the user asks for independent analysis or review, an agent SHALL first read only the shared
inputs — the user's requirements, approved decisions, formal specifications, and the aligned code
version. It MUST NOT read other agents' unconfirmed analysis, reviews, or summaries before
producing its own first conclusions, SHALL write its own result first, and SHALL keep original
findings separate from corrections made after comparison.

#### Scenario: Two agents analyse the same requirement
- **WHEN** the second agent begins its independent analysis
- **THEN** it does not read the first agent's unconfirmed analysis until its own draft is written

#### Scenario: Cross-comparison changes a conclusion
- **WHEN** comparison with another analysis corrects a finding
- **THEN** the original finding and the correction are recorded separately

### Requirement: Decisions require confirmation
`decisions.md` SHALL record only decisions confirmed by the user or an explicitly authorized
party, with rationale, significant alternatives, confirmer and date, supporting evidence, and the
formal landing place. Agreement among agents, a coordinator's summary, or a recommendation SHALL
NOT count as approval; unconfirmed options stay in `context.md` or individual analyses.

#### Scenario: Several agents agree on an option
- **WHEN** multiple agents independently recommend the same option without user confirmation
- **THEN** it stays an unconfirmed option and is not recorded as an approved decision

#### Scenario: A decision is superseded
- **WHEN** a later decision replaces an earlier one
- **THEN** the relationship is noted briefly without building a version history for the record

### Requirement: Reviews state scope and baseline
Each review record SHALL state reviewer, scope, the version it is based on as a base→head commit
range or an explicit document snapshot, whether uncommitted content is included, and which checks
actually ran, recording honestly when a check did not run. An agent MUST NOT invent a commit SHA
or create a commit merely to produce a baseline. A reviewer SHALL NOT modify product code by
default.

#### Scenario: Review includes uncommitted work
- **WHEN** a review covers staged, unstaged, or untracked content
- **THEN** the record states that scope and does not claim the content is fixed by HEAD alone

#### Scenario: No commit exists yet
- **WHEN** there is no usable commit to cite as a baseline
- **THEN** the record states that it is not yet versioned rather than citing a fabricated SHA

#### Scenario: No problems found
- **WHEN** a review finds no issue
- **THEN** it still records scope and limitations and invents no finding

### Requirement: Disagreement is settled by evidence, not consensus
Before comparing conclusions across agents, the agents SHALL confirm they reviewed the same
content and scope. Disagreement SHALL be resolved using requirements, code, and reproducible
checks, and MUST NOT be settled by counting agreeing models.

#### Scenario: Two agents reach opposite conclusions
- **WHEN** two reviews disagree
- **THEN** their versions and scope are compared first, then the question is decided by reproducible evidence

### Requirement: Necessary outcomes must have a formal home
Information needed for delivery or continued tracking MUST NOT exist only in a Work Item.
Requirements, constraints, behavior, and acceptance criteria SHALL land in the corresponding
OpenSpec documents; design decisions and trade-offs in the project's design document; confirmed
but unfinished fixes, risks, and verification in its formal task or risk mechanism; completed
fixes in code, tests, and the related task updates. Handoff applies at every stage, not only when
a change is first created.

#### Scenario: Review finds an unresolved delivery risk
- **WHEN** a review confirms a risk that affects delivery
- **THEN** the risk is recorded in the project's formal task or risk mechanism rather than only in the review file

#### Scenario: Updating formal artifacts is not authorized
- **WHEN** the agent lacks authority to change the formal artifacts
- **THEN** it lists the pending handoff and reports it, and does not claim the handoff is complete

### Requirement: Formal artifacts stand without the records
Formal documents SHALL be understandable when the Work Item does not exist, and MUST NOT say only
that work follows the Work Item's discussion. The handoff criterion is that a new agent which
reads neither the original conversation nor the Work Item can continue implementation and
verification from the project rules, OpenSpec, formal tasks, and code.

#### Scenario: Spec references the discussion instead of the requirement
- **WHEN** a formal document would say "implement as discussed in the Work Item"
- **THEN** the requirement itself is written into the formal document

#### Scenario: Handoff across directories
- **WHEN** work continues in another directory
- **THEN** the agent confirms that directory actually holds the required formal version rather than assuming it

### Requirement: Cleanup authority is explicit and bounded
A Work Item SHALL NOT be deleted automatically because a change was created, a status became
`closed`, an agent stopped, or time passed, and no retention period SHALL be enforced. Deletion
SHALL require explicit authorization or a previously stated explicit cleanup rule, and that
authorization SHALL NOT extend to OpenSpec content, branches, worktrees, other Work Items, or
formal outcomes.

#### Scenario: Change was just created
- **WHEN** an OpenSpec change is created from a record
- **THEN** the record is not deleted or ended automatically

#### Scenario: Cleanup requested with pending handoff
- **WHEN** cleanup is requested while a confirmed decision has no formal landing place
- **THEN** the agent names the gap before cleanup and proceeds only on the user's explicit decision

### Requirement: Records may disappear with an authorized worktree removal
When a worktree is removed under authorization, its records MAY disappear with it, and no backup
or relocation SHALL be required. This SHALL NOT authorize an agent to remove a worktree itself,
and Git or tool deletion warnings SHALL NOT be treated as protection for this data.

#### Scenario: Authorized worktree removal
- **WHEN** a worktree holding ignored records is removed under authorization
- **THEN** the removal proceeds without requiring a force flag for those records
- **AND** the records disappear with the worktree and no backup is created

#### Scenario: Agent wants to clean up a worktree
- **WHEN** an agent has authorization to delete a Work Item
- **THEN** it still does not remove the worktree, branch, or any formal artifact

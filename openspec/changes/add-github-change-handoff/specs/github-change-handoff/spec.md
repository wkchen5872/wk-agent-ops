# Spec Delta

## Purpose

Provide durable, versioned handoff between OpenSpec changes and GitHub Issues and pull requests so agents on different sessions or machines can recover the work, next action, and evidence without local discussion records.

## ADDED Requirements

### Requirement: Formal requirements have one authority
The handoff workflow SHALL use OpenSpec as the authority for requirements, design, tasks, and acceptance criteria. Issues SHALL hold work tracking and links; PRs SHALL hold published changes and review evidence. Required handoff information MUST remain usable without the conversation or a local Work Item.

#### Scenario: New machine has no Work Item
- **WHEN** an agent opens a linked Issue or PR on another machine
- **THEN** it can identify the Change, available artifact revision, current scope, unresolved work, and next action without a local Work Item
- **AND** a local-only specification is identified as unpublished instead of presented as remotely available

#### Scenario: Acceptance criteria need changing
- **WHEN** implementation feedback requires changing approved acceptance criteria
- **THEN** the workflow returns the change to OpenSpec and the applicable human design approval
- **AND** editing an Issue or PR alone does not approve the new criteria

### Requirement: Writes verify the target and actual actor
Before a remote write the workflow SHALL verify the intended host, repository, and actual API actor against trusted project expectations or explicit user input. Commit and push operations SHALL additionally verify effective author and committer identities and the actual push destination and authenticated actor. Unknown or conflicting identity MUST stop the affected write without changing account, remote, key, or global configuration.

#### Scenario: Git identity differs from API authentication
- **WHEN** Git author email is configured but the current gh API actor is unverified
- **THEN** the workflow does not use that email or a different gh execution context as actor evidence
- **AND** it stops the remote write and reports the missing verification without exposing credentials

#### Scenario: Expected actors intentionally differ
- **WHEN** trusted project expectations name different commit, push, and API actors and each actual actor matches its expectation
- **THEN** the workflow accepts the declared arrangement without requiring all actors to match

#### Scenario: Push principal cannot be established
- **WHEN** a selected SSH or HTTPS push route cannot be safely attributed to the expected principal
- **THEN** push is blocked and the missing evidence is reported
- **AND** the workflow neither switches authentication nor dumps credential output

### Requirement: Identity checks share an operation-scoped executable
The workflow SHALL provide one read-only identity-check script reused before API, commit, and push writes. It SHALL compare actual evidence with the trusted expected identity for the selected operation, return pass, mismatch, unverified, or error with distinct exit codes and sanitized evidence, and perform no write or authentication change. Only pass SHALL permit an already authorized operation to continue.

#### Scenario: API actor matches but push actor does not
- **WHEN** the api check passes and the later push check identifies another actor
- **THEN** the script reports mismatch for push and the Skill stops that push
- **AND** the api result is not reused as proof of the push identity

#### Scenario: Evidence or required tool is unavailable
- **WHEN** the script cannot establish required identity evidence or lacks a necessary tool
- **THEN** it returns unverified rather than pass and reports the missing prerequisite without credentials
- **AND** the Skill does not proceed with the affected write or silently change channels

#### Scenario: Rule requires a preflight check
- **WHEN** a supported Agent starts a handoff operation
- **THEN** it reaches the shared requirement through its installed protocol or thin rule and invokes the appropriate check before writing
- **AND** rule delivery is not described as a universal runtime block or a new Git hook

#### Scenario: Reviewed head changes the identity-check script
- **WHEN** the candidate checkout contains a modified identity-check script
- **THEN** the caller obtains a verified ordinary-file blob from the fixed trusted policy revision or an explicitly trusted installed snapshot
- **AND** it runs that trusted content against the actual candidate checkout and records script-source and target evidence without executing the candidate script

#### Scenario: No trusted script exists yet
- **WHEN** the trusted revision lacks the script and no explicitly trusted installed snapshot is available
- **THEN** the workflow reports the bootstrap prerequisite and does not silently use the candidate version
- **AND** a previously explicit authorization for an unchanged script snapshot can be reused

#### Scenario: SSH authentication test identifies the push actor
- **WHEN** a noninteractive authentication test using the actual push route and SSH settings returns a trusted GitHub greeting for the expected account
- **THEN** that greeting is accepted as actor evidence even when the documented test exits with code 1
- **AND** missing host trust, an interactive prompt, or mismatched settings blocks push without changing keys or host verification

#### Scenario: HTTPS helper cannot be connected to API actor evidence
- **WHEN** Git uses osxkeychain or another unverified credential path while a separate CLI reports a matching login
- **THEN** the CLI result does not verify the push actor and push remains blocked
- **AND** neither the credential secret nor a user statement is substituted for actual authentication evidence

### Requirement: Expected identities come from a trusted policy snapshot
Expected identities SHALL come from explicit user input or an explicitly trusted project policy revision fixed before reviewing the candidate head. The policy SHALL identify host, repository, API actor and, when applicable, commit identities and push route and actor. Candidate PR content MUST NOT silently replace that policy; unresolved source or profile ambiguity SHALL stop affected writes.

#### Scenario: PR changes its own identity policy
- **WHEN** the reviewed head modifies the project's expected API or push account
- **THEN** the reviewer continues to use the previously trusted policy snapshot
- **AND** adopting the new policy requires explicit user authorization independent of the candidate content

### Requirement: Issue operations preserve work identity
The Issue entry SHALL offer explicit create and update operations, use the selected Change and repository to discover existing associations, and reuse a unique confirmed Issue. Ambiguous or contradictory associations MUST be resolved before writing. Parent work, child work, and dependencies SHALL remain distinct; dependency records SHALL state their release condition.

#### Scenario: Repeated create invocation
- **WHEN** create is invoked again and one Issue is positively associated with the same Change
- **THEN** the existing Issue is returned without creating a duplicate or silently replacing its body

#### Scenario: Similar titles do not prove association
- **WHEN** search returns an Issue with a similar title
- **THEN** the workflow reads its managed `openspec-change` and `repository` keys and verifies the selected target before reuse
- **AND** a search match alone is not accepted as a positive association

#### Scenario: Several matching Issues
- **WHEN** discovery finds multiple plausible Issues without a unique explicit association
- **THEN** the workflow reports the candidates and does not choose the first or create another Issue

#### Scenario: Work splits into dependent Changes
- **WHEN** a parent objective is split into several Changes
- **THEN** the tracking links identify each child Change and its Issue or PR
- **AND** dependencies state whether they require design approval, merge, deployment, or acceptance instead of only naming another task

### Requirement: PR operations separate publication from description updates
The PR entry SHALL distinguish create, publish-existing-version, and update-description operations. Create and publish SHALL work only within the authorized Change and branch scope; update-description SHALL perform metadata changes without commit or push. Reuse SHALL be based on verified repository, branch, and Change association, with conflicts reported before writes.

#### Scenario: Reviewer needs to add a report link
- **WHEN** an authorized caller invokes update-description for an existing PR
- **THEN** only the requested description section is updated
- **AND** no staging, commit, push, merge, base change, or closure is triggered

#### Scenario: Same PR receives implementation
- **WHEN** the selected PR already contains the design revision and its authorized branch receives implementation
- **THEN** publish updates that same PR branch and reports the new remote head
- **AND** it does not open a second PR automatically

### Requirement: Publication inspects the full change before committing
Create and publish SHALL inspect staged, unstaged, untracked, and base-to-head changes before any commit delegation. The workflow MUST stop when a stage-all writer would include unauthorized work. It SHALL reuse valid existing commits, invoke the existing writer only for authorized uncommitted content, respect its input contract and checks, then verify the pushed head before publishing a matching PR description.

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
Issue and PR templates SHALL define bounded managed sections and minimum information per operation. Updates SHALL read the latest body, preserve unrelated text and prior provenance, and change only the caller-owned sections or requested fields. Concurrent summary ownership conflicts MUST stop shared-body writes; review reports and repair replies SHALL remain separate records owned by their authors.

#### Scenario: Human edits outside managed section
- **WHEN** the latest PR body contains a human note outside the managed section
- **THEN** the updated body preserves the note and other reviewers' records
- **AND** a missing or ambiguous section boundary is reported before a destructive replacement

#### Scenario: Another summary writer is active
- **WHEN** two agents claim the same PR summary section concurrently
- **THEN** the workflow requires one designated writer or reports the conflict before replacement
- **AND** read-before-write alone is not reported as a concurrency lock

### Requirement: Provenance records known event participants safely
Planning, implementation, publication, and review records SHALL distinguish their roles, executing tool, known current root-session model, session reference type, optional machine alias, timestamp with timezone, and artifact revision or explicit unpublished state. Unknown values MUST NOT be guessed. Publishing a later update MUST preserve earlier authorship; a publisher MUST identify a separately authored source report.

#### Scenario: Model or session is unavailable
- **WHEN** the current model or native Session ID is unknown or not approved for disclosure
- **THEN** the workflow reports the omission or uses an explicitly labeled session alias
- **AND** it does not infer a model from history or mislabel an alias as a native ID

#### Scenario: Machine information is recorded
- **WHEN** a record includes machine context
- **THEN** it uses a user-controlled neutral machine alias
- **AND** it does not publish raw hostname, private absolute Work Item paths, credentials, or an invented provider email

#### Scenario: Default remote provenance disclosure
- **WHEN** an Issue, PR, or Review record is published without a stricter explicit project or user restriction
- **THEN** it retains the executing tool, known model, and known native session ID with its source
- **AND** machine information is limited to a neutral configured alias or null; unknown values are not guessed

### Requirement: Remote review records extend a shared local baseline
The shared handoff contract SHALL own the remote review schema, reuse local review field and finding-status semantics, and define phase, verdict, provenance, and identifiers. Verdict SHALL be pass, changes-required, or blocked. A review ID SHALL be assignable before publication and unique within the PR; each finding SHALL retain its origin-review ID and local finding number across later rounds.

#### Scenario: Report has not been published yet
- **WHEN** a reviewer prepares its first report before a report URL exists
- **THEN** it assigns a unique reviewer-session alias plus round identifier and uses that origin identifier for its findings
- **AND** later reports retain the original finding IDs instead of deriving them from a nonexistent or changing URL

### Requirement: Review reports expose session and Git baseline explicitly
Review reports SHALL contain Scope and Baseline, Findings, and Summary and Limitations sections. The baseline SHALL identify session ID with source or null and reason, a separate alias, tool and known model, review scope and time, repository and PR context, branch and commit baselines, actual checkout revision, unpublished content, snapshot evidence, and actual checks. Unknown values MUST NOT be fabricated or masked by aliases.

#### Scenario: Native session ID is supplied by the user
- **WHEN** the reviewer knows a native session ID from explicit user input
- **THEN** the report records it separately from the local alias and labels its user-provided source when disclosure is permitted
- **AND** withheld or unavailable IDs remain null with the reason rather than being replaced by invented values

#### Scenario: Local checks differ from the published Git revision
- **WHEN** the checkout HEAD, comparison baseline, or unpublished content differs from the selected PR revision
- **THEN** Scope and Baseline identifies those differences and the actual content checked
- **AND** neither the branch name nor a HEAD-only reference is used to imply that all local evidence verifies the published PR

### Requirement: Lifecycle transitions retain their own evidence and authority
The workflow SHALL distinguish design review, human design approval, implementation review, merge, deployment, real-data acceptance, Issue closure, and archive. It SHALL not infer any later stage from an earlier one. Human approval of the relevant design SHALL precede Apply; publishing a report alone SHALL not be treated as waking another agent.

#### Scenario: Design passes
- **WHEN** design Review reports pass
- **THEN** implementation still requires the applicable human design approval
- **AND** the design result is not represented as implementation acceptance

#### Scenario: Acceptance waits for real data
- **WHEN** required acceptance depends on data available after a future interval
- **THEN** the Issue records the starting event and version, earliest check time with timezone, required data window, acceptance criteria and evidence location, owner, and next action
- **AND** review pass, merge, or the date arriving does not mark acceptance complete or auto-close the Issue

### Requirement: Human design approval is recoverable and versioned
The PR handoff record SHALL state approval status, human approver, time or unknown, approved scope and artifact revision, source type and reference, and recording actor and time. Apply SHALL accept a human GitHub approval or an explicitly authorized agent's named attestation of the user's instruction covering that scope and revision. Technical verdicts, unauthorized attestations, and superseded approvals MUST NOT authorize Apply.

#### Scenario: New session starts implementation
- **WHEN** a new session considers applying the published Change
- **THEN** it can identify the human approval, its source, scope, and approved design revision from the PR
- **AND** pending, incomplete, untrusted, or superseded approval does not authorize Apply

#### Scenario: Approval is relayed from the user
- **WHEN** an authorized agent records the user's explicit approval rather than the human posting it directly
- **THEN** it publishes an agent-attested-user-instruction event with human source, approved scope and revision, recording identity and time, and honest unknown timestamps
- **AND** a new session trusts that event after checking the actual comment author against trusted recorder authorization, without requiring access to the original conversation or a repeated human GitHub approval

#### Scenario: Body claims an authorized recorder without matching authorship
- **WHEN** an approval body names a trusted recorder but the actual comment author is not an authorized recording account
- **THEN** that attestation is not accepted as permission to Apply
- **AND** a technical review pass or body field cannot bypass the recorder check

### Requirement: Finalization changes receive a new version-bound review
Archive and documentation commits after a review SHALL invalidate its applicability to the new head. Authorized finalization SHALL use the existing archive and commit workflow, then publish and review the resulting revision. A narrowed review SHALL require evidence that the remaining diff is limited to finalization; semantic changes SHALL receive the necessary broader verification.

#### Scenario: Archive follows implementation review
- **WHEN** authorized archive, spec synchronization, and documentation update produce a new commit after implementation review passed
- **THEN** publication pushes the actual new commit and a subsequent report reviews that final head
- **AND** the prior report remains attributed to its earlier head

#### Scenario: Original PR is already merged
- **WHEN** finalization creates new changes after the original PR was merged
- **THEN** the workflow requires an explicitly authorized follow-up PR or reports pending handoff
- **AND** pushing to the old branch alone is not reported as completed review or merge

### Requirement: GitHub CLI is the first-version execution layer
Issue, PR, and Review operations SHALL use GitHub CLI gh in the verified host and repository context; commit and push SHALL use Git. The first version MUST NOT execute a GitHub MCP path or silently switch backends. Installation SHALL deliver the shared contract and identity-check script to Claude Code, Codex, and Antigravity without modifying third-party Skills or adding background automation.

#### Scenario: GitHub CLI is unavailable or insufficient
- **WHEN** gh is missing or lacks the required capability or permission
- **THEN** the workflow reports the prerequisite or operation failure and stops the affected action
- **AND** it does not install or log in automatically, switch to MCP, or claim success

#### Scenario: Request is retried after uncertain remote response
- **WHEN** a create request times out without a confirmed remote result
- **THEN** the workflow reconciles existing Issue or PR associations before retrying
- **AND** an unresolved result is reported instead of blindly repeating the create request

#### Scenario: Managed documentation includes a diagram
- **WHEN** the shared handoff documentation and its referenced workflow SVG change
- **THEN** reinstalling updates both managed assets while preserving unrelated project-owned files
- **AND** a copied-once diagram is not reported as an updated managed artifact

#### Scenario: Shared identity script is installed or updated
- **WHEN** the installer runs for a new or existing target project
- **THEN** the common identity-check script is delivered with its executable mode and refreshed on reinstall
- **AND** unrelated project scripts and local Work Items are preserved

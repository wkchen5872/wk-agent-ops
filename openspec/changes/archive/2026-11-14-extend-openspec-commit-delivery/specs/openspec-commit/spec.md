# Spec Delta

## MODIFIED Requirements

### Requirement: Coordinate the completion workflow in order
`openspec-commit` SHALL invoke exactly one archive action, followed by
`doc-updater`, followed by `git-commit-writer`. It MUST stop before downstream
steps when archive fails. Optional authorized PR delivery SHALL follow successful local completion and SHALL NOT change this core order or provider routing.

#### Scenario: Successful ordered completion
- **WHEN** a selected OpenSpec change archives successfully
- **THEN** the workflow invokes `doc-updater` after archive
- **AND** invokes `git-commit-writer` only after documentation handling completes

#### Scenario: Archive failure
- **WHEN** `openspec-archive-change` fails or does not return an archive path
- **THEN** the workflow stops without invoking `doc-updater` or `git-commit-writer`

### Requirement: Resume an interrupted completion workflow
`openspec-commit` SHALL detect an uncommitted archived change and resume from
documentation update when archive has already completed. It SHALL also recover an explicitly identified completed commit and remote delivery progress from verified Git and PR evidence, including a committed archive. Only missing authorized steps SHALL run; ambiguous or uncertain states MUST NOT be guessed or blindly repeated.

#### Scenario: Retry after documentation failure
- **WHEN** no matching active change exists
- **AND** Git status contains exactly one uncommitted archive candidate
- **THEN** the workflow reuses that archive and skips the archive action

#### Scenario: Multiple resume candidates
- **WHEN** Git status contains multiple uncommitted archive candidates
- **THEN** the workflow asks the user to select one and MUST NOT guess

#### Scenario: Retry after committed archive and failed push
- **WHEN** the selected Change has a verified archive and completion commit but its authorized push failed
- **THEN** the workflow reuses that commit and exact archive context, performing only the missing authorized delivery
- **AND** it does not re-archive, repeat docs unnecessarily or create a duplicate completion commit

#### Scenario: Retry after Closure but failed close
- **WHEN** the PR Closure was confirmed but its close failed
- **THEN** the workflow delegates recovery using the existing summary and actual PR state
- **AND** it does not post a duplicate Closure or reopen ended work

#### Scenario: Uncertain or conflicting recovery evidence
- **WHEN** local history, remote head or PR comments do not identify one consistent completion state
- **THEN** the workflow reports the known partial results and uncertainty or asks for the missing selection
- **AND** it does not select the newest archive, fabricate success or resend writes blindly


## ADDED Requirements

### Requirement: Completion resolves local and remote delivery authority separately
The workflow SHALL distinguish local completion, successful PR handoff and explicitly requested abandoned-PR closure. A local commit request SHALL NOT authorize push, PR creation, merge or close. An absent PR MUST NOT prevent local completion. Unknown PR discovery or missing authority SHALL be reported separately from completed local work. The workflow MUST NOT close linked Issues or delete branches.

#### Scenario: Local completion without a PR
- **WHEN** the request is local-only or no corresponding PR exists
- **THEN** archive, documentation and commit can complete with their actual results reported
- **AND** the workflow does not create a PR, push or mutate GitHub state

#### Scenario: PR exists without remote authorization
- **WHEN** a corresponding PR is known but publishing or closing it was not authorized
- **THEN** the workflow reports the local completion and pending remote action without performing that action

#### Scenario: Remote target is unknown
- **WHEN** remote delivery was requested but the repository, PR or required authority cannot be confirmed
- **THEN** the workflow reports remote delivery as pending or blocked while preserving confirmed local results
- **AND** unknown discovery is not treated as permission for another target

### Requirement: Successful PR handoff uses the verified final published version
Authorized successful PR delivery SHALL confirm the intended head repository and ref, publish through normal Git push when needed, and read back the actual head before describing it. A ready-to-merge Closure SHALL require sufficient review evidence for the final published content. New content MUST NOT inherit an earlier pass. A missing or failed final review SHALL stop the ready-to-merge claim without undoing local completion.

#### Scenario: Final reviewed head is published
- **WHEN** authorized publication is confirmed and valid review evidence covers the actual PR head
- **THEN** the workflow updates the authorized PR description and posts a version-bound Closure through github-pr reply with readback
- **AND** it leaves merge, deployment and independent Issue acceptance unperformed

#### Scenario: Archive or documentation changes the head
- **WHEN** completion creates content not covered by the prior review
- **THEN** the workflow obtains one authorized review round or reports that the final revision needs review before claiming ready to merge
- **AND** it does not auto-repair, poll or copy the old pass to the new head

#### Scenario: Push fails or head moves
- **WHEN** push is rejected or the observed PR head differs from the intended reviewed version
- **THEN** the workflow reports the confirmed commit and the publication or version limit
- **AND** it does not force push, describe unpushed content as published or attest readiness for a different head

### Requirement: Abandoned PR closure delegates the existing close capability
For explicitly authorized cancellation or replacement, the workflow SHALL delegate github-pr close for the confirmed selected PR and evidenced reason. That capability SHALL own Closure publication, readback and state mutation without a duplicate preliminary summary. Successful handoff MUST NOT use close. Closing SHALL NOT require or fabricate a successful implementation review, nor implicitly publish abandoned local work or close Issues.

#### Scenario: Cancelled or superseded PR
- **WHEN** local completion has succeeded and the user explicitly requests closing its cancelled or superseded PR
- **THEN** github-pr close posts and verifies Closure before closing and reading the selected PR state
- **AND** linked Issues, dependencies and branches remain untouched and no unrequested push occurs

#### Scenario: Closure authorization is missing
- **WHEN** closing was not authorized or the reason is unsupported
- **THEN** the workflow retains the local result and reports what prevents closure without closing or merging

#### Scenario: PR is already merged or closed
- **WHEN** the selected PR has already ended
- **THEN** the workflow reports its actual state and only performs explicitly requested missing summary work allowed by github-pr
- **AND** it does not reopen, close again or turn that state into acceptance evidence

### Requirement: Completion reports stage outcomes independently
The workflow SHALL report local archive and sync status, documentation, commit, remote publication, PR description or final review, Closure and close as distinct applicable outcomes with their evidence. A failure at one stage SHALL preserve earlier successful outcomes and leave later dependent actions unperformed. Unknown results SHALL stay uncertain until reconciled; generated URLs or implied atomic rollback are forbidden.

#### Scenario: Commit succeeds but remote update fails
- **WHEN** the completion commit and push are confirmed but the PR description update fails
- **THEN** the report retains the commit and published head and states that the update is incomplete
- **AND** it does not claim completed PR handoff or repeat a confirmed commit on retry

#### Scenario: Summary readback fails
- **WHEN** Closure may have been posted but cannot be confirmed
- **THEN** the workflow preserves the uncertainty and reconciles PR comments before any retry or dependent close

### Requirement: Confirmed local workflows are available outside Work Items
This repository SHALL document the four confirmed local development stages in tracked docs with independently viewable diagrams and mobile previews. The documents SHALL show human publication checkpoints in the first two stages, existing Review, and completion outcome branches. They MUST NOT depend on ignored Work Item contents or impose these personal workflow choices on every managed installation target.

#### Scenario: Fresh checkout has no Work Item
- **WHEN** a reader opens the tracked workflow documentation without the original Work Item or conversation
- **THEN** all four flows, prerequisites, report paths and publication or closure boundaries remain understandable and linked diagrams are available

#### Scenario: Capability status differs from process approval
- **WHEN** the confirmed process documentation describes existing abilities and the new completion integration
- **THEN** it distinguishes confirmed process choices from implementation status and retains manual publication decisions without proposing new first-stage or second-stage workflow skills

## MODIFIED Requirements

### Requirement: wt-work supports pre-existing local feature branch
When `feature/<change-id>` exists locally, `wt-work` SHALL reuse an eligible registered non-primary Worktree for that branch or create `.worktrees/<change-id>` from the existing branch without `-b`. If the primary checkout holds the branch, it SHALL move that checkout to the requested base branch only after validating that the switch is safe.

#### Scenario: Local branch exists without an eligible Worktree
- **WHEN** `feature/<change-id>` exists locally and no eligible non-primary Worktree exists
- **THEN** `wt-work` creates `.worktrees/<change-id>` from that branch without `-b`

#### Scenario: Exact branch is already in another Worktree
- **WHEN** a registered non-primary Worktree checks out `feature/<change-id>` and it is the only eligible candidate
- **THEN** `wt-work` attaches that path rather than creating a second Worktree

### Requirement: wt-work supports remote-only feature branch (cross-machine)
When the local feature branch is absent and `origin/feature/<change-id>` is confirmed to exist, `wt-work` SHALL fetch it and create a local tracking branch in `.worktrees/<change-id>`.

#### Scenario: Remote branch exists
- **WHEN** the remote query succeeds and confirms `origin/feature/<change-id>`
- **THEN** the system fetches that ref and creates the Project-managed tracking Worktree

#### Scenario: Remote lookup infrastructure fails
- **WHEN** no `origin` exists or the remote query fails because of authentication, network, or command error
- **THEN** the system exits non-zero with the observed failure
- **AND** does not treat the error as proof that the branch is absent

### Requirement: wt-work falls back to creating new branch
`wt-work` SHALL NOT create a new feature branch from the base branch when the PM planning hand-off is missing. Branch creation belongs to the explicit branch-first transition.

#### Scenario: Local and remote feature branch are absent
- **WHEN** local lookup and a successful remote lookup both confirm that `feature/<change-id>` is absent
- **THEN** `wt-work` exits non-zero with branch-first guidance
- **AND** leaves the current checkout unchanged

## ADDED Requirements

### Requirement: Cross-machine hand-off requires portable planning state
Cross-machine RD setup SHALL require the reviewed planning artifacts to be reachable through the fetched feature branch. Dirty state in another machine's Worktree SHALL NOT be treated as transferable.

#### Scenario: Planning commit is reachable
- **WHEN** the fetched feature branch contains the active OpenSpec change and reviewed planning commit
- **THEN** Worktree creation may continue

#### Scenario: Planning state exists only as remote-machine dirty files
- **WHEN** the fetched branch does not contain the required planning artifacts
- **THEN** `wt-work` stops and requests a commit／push or an explicit patch hand-off

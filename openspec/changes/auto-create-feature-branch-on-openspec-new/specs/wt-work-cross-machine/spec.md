## ADDED Requirements

### Requirement: wt-work supports pre-existing local feature branch
When `wt-work <name>` is called and `feature/<name>` already exists locally (created by PM on the same machine), `wt-work` SHALL create the worktree from the existing branch without the `-b` flag.

#### Scenario: Local branch exists, worktree does not
- **WHEN** `git show-ref refs/heads/feature/<name>` succeeds AND `.worktrees/<name>` does not exist
- **THEN** `git worktree add .worktrees/<name> feature/<name>` (no `-b`) succeeds

#### Scenario: Local branch exists and worktree exists (resume path)
- **WHEN** `.worktrees/<name>` directory already exists
- **THEN** `wt-work` takes the existing resume path (unchanged from current behavior)

### Requirement: wt-work supports remote-only feature branch (cross-machine)
When `feature/<name>` does not exist locally but exists on the remote (e.g., PM on machine A pushed the branch, RD is on machine B), `wt-work` SHALL fetch the branch from remote and create a tracking worktree.

#### Scenario: Remote branch exists, local does not
- **WHEN** `git ls-remote --exit-code origin feature/<name>` succeeds AND local branch does not exist
- **THEN** `git fetch origin feature/<name>` followed by `git worktree add .worktrees/<name> -b feature/<name> origin/feature/<name>`

#### Scenario: Remote check fails (no remote configured)
- **WHEN** `git ls-remote` fails or no remote named `origin` exists
- **THEN** fall through to the "create new" path (existing behavior)

### Requirement: wt-work falls back to creating new branch
When neither local nor remote branch exists, `wt-work` SHALL behave exactly as before: checkout BASE_BRANCH and create a new `feature/<name>` branch.

#### Scenario: No local, no remote branch
- **WHEN** local and remote checks both return no branch
- **THEN** `git checkout <BASE_BRANCH>` followed by `git worktree add .worktrees/<name> -b feature/<name>`

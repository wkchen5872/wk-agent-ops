## ADDED Requirements

### Requirement: Explicit branch-first transition precedes OpenSpec artifact creation
The workflow SHALL provide an `opsx-branch <change-id>` entrypoint that creates or switches to `feature/<change-id>` before `openspec new change <change-id>` writes any artifact. The entrypoint SHALL only manage Git state and SHALL NOT create an OpenSpec change or launch a Provider session.

#### Scenario: Create branch for a new change
- **WHEN** the user runs `opsx-branch refine-workflow` in a Git repository and `feature/refine-workflow` does not exist
- **THEN** the entrypoint creates and switches to `feature/refine-workflow` from the current HEAD
- **AND** no OpenSpec artifact is created

#### Scenario: Reuse an existing local branch
- **WHEN** the user runs `opsx-branch refine-workflow` and `feature/refine-workflow` already exists but is not checked out by another Worktree
- **THEN** the entrypoint switches to that branch without creating a duplicate branch

#### Scenario: Branch belongs to another Worktree
- **WHEN** `feature/refine-workflow` is already checked out in another registered Worktree
- **THEN** the entrypoint exits non-zero and reports that Worktree path
- **AND** it does not move or delete either checkout

#### Scenario: Invalid change identifier
- **WHEN** the supplied change ID is missing or is not kebab-case
- **THEN** the entrypoint prints usage guidance and exits non-zero without changing Git state

### Requirement: PostToolUse branch creation is compatibility-only
The existing PostToolUse hook SHALL remain idempotent as a compatibility fallback, but the documented workflow and installed instructions SHALL NOT rely on it for branch-first correctness.

#### Scenario: Explicit transition already completed
- **WHEN** `opsx-branch <change-id>` has already selected `feature/<change-id>` and the compatibility hook later observes `openspec new change <change-id>`
- **THEN** the hook exits successfully without creating or switching to a different branch

#### Scenario: Compatibility hook is absent or disabled
- **WHEN** the Provider does not execute the PostToolUse hook
- **THEN** following the documented explicit transition still places all new change artifacts on `feature/<change-id>`

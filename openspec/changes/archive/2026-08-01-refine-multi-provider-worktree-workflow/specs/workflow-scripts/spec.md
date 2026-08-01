## MODIFIED Requirements

### Requirement: workflow install.sh deploys hook as part of standard setup
`scripts/workflow/install.sh` SHALL install `wt-work`, `wt-done`, `wt-resume`, `pm-start`, `opsx-branch`, and shell completion. It SHALL continue deploying the idempotent openspec-branch-creator hook as a compatibility fallback while documenting `opsx-branch` as the required branch-first entrypoint.

#### Scenario: Running install.sh installs workflow entrypoints and fallback
- **WHEN** `bash scripts/workflow/install.sh` is executed
- **THEN** all five workflow commands and completion are installed
- **AND** the compatibility hook is deployed without duplicate registration
- **AND** the output identifies `opsx-branch` as the pre-artifact transition

### Requirement: wt-work-flow.md documents the branch resolution flow
`docs/workflow/wt-work-flow.md` SHALL document the implemented resolution flow, including explicit `--path`, Git registry auto-discovery, Project-managed creation, cross-machine hand-off, Provider adapters, and ambiguous-candidate failure.

#### Scenario: Documentation exposes implemented behavior
- **WHEN** `docs/workflow/wt-work-flow.md` is read
- **THEN** it contains Mermaid flows for Worktree resolution and branch hand-off
- **AND** it does not retain obsolete fallback or automatic-resume behavior

## ADDED Requirements

### Requirement: Workflow cleanup respects Worktree ownership
Workflow commands SHALL distinguish Project-managed Worktrees from Provider-native Worktrees. `wt-done` SHALL remove only `.worktrees/<change-id>` created by the project workflow and SHALL NOT remove an attached Provider-native path.

#### Scenario: Complete a Project-managed Worktree
- **WHEN** `wt-done <change-id>` successfully merges `feature/<change-id>` and the registered project path is `.worktrees/<change-id>`
- **THEN** it removes that Worktree, prunes Git metadata, and deletes the merged feature branch

#### Scenario: Provider-native Worktree remains provider-owned
- **WHEN** a Provider-native Worktree was attached during implementation
- **THEN** `wt-done` does not infer or remove its path
- **AND** cleanup remains the responsibility of the Provider or user that created it

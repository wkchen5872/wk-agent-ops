# Spec: wt-work

## Purpose

Provides a multi-Provider `wt-work <change-id>` apply launcher that safely resolves a registered Worktree or creates a Project-managed Worktree from a reviewed feature branch, preserving dirty same-machine hand-offs and cleanup ownership.

## Requirements

### Requirement: wt-work command replaces wt-new
The system SHALL provide `wt-work <change-id>` as the RD apply launcher. Without `--path`, it SHALL reuse one uniquely verifiable registered Worktree or create a Project-managed Worktree at `.worktrees/<change-id>` from the existing local or remote `feature/<change-id>` branch. Without `--session`, it SHALL start a new session for the selected Provider and pass the portable OpenSpec apply intent.

#### Scenario: Create the default Project-managed Worktree
- **WHEN** the user runs `wt-work feature123`
- **AND** no eligible non-primary Worktree exists
- **AND** local `feature/feature123` contains the reviewed OpenSpec planning artifacts
- **THEN** the system creates `.worktrees/feature123` attached to that branch
- **AND** launches a new Claude RD session there with the apply intent for `feature123`

#### Scenario: Existing Project-managed Worktree starts a new selected Provider
- **WHEN** `.worktrees/feature123` is registered and the user runs `wt-work feature123 --agent codex` without `--session`
- **THEN** the system reuses the same physical path without creating another Worktree
- **AND** starts a new Codex session rather than attempting to resume a Claude session

#### Scenario: Explicit session resumes in the resolved Worktree
- **WHEN** the user runs `wt-work feature123 --agent claude --session <session>`
- **THEN** the system resolves and validates the Worktree
- **AND** forwards `<session>` to Claude's resume mechanism with the apply intent

#### Scenario: Missing reviewed feature branch
- **WHEN** no eligible Worktree, local feature branch, or confirmed remote feature branch exists
- **THEN** the system exits non-zero and instructs the user to complete the branch-first planning hand-off
- **AND** does not create an empty feature branch from the base branch

#### Scenario: Missing change ID
- **WHEN** the user runs `wt-work` without a change ID
- **THEN** the system prints usage guidance and exits non-zero

### Requirement: wt-work supports --session parameter
The system SHALL accept `--session`／`-s` only as an explicit request to resume that session for the selected Provider inside the resolved Worktree. Omitting the option SHALL start a new Provider session.

#### Scenario: Claude session forwarding
- **WHEN** `--agent claude --session my-session-name` is supplied
- **THEN** the Claude adapter resumes `my-session-name` and supplies the apply intent

#### Scenario: Codex session forwarding
- **WHEN** `--agent codex --session <session-id>` is supplied
- **THEN** the Codex adapter uses Codex's native resume command in the resolved Worktree and supplies the apply intent when supported

#### Scenario: Antigravity conversation forwarding
- **WHEN** `--agent antigravity --session <conversation-id>` is supplied
- **THEN** the Antigravity adapter uses its native conversation option in the resolved Worktree

### Requirement: wt-work supports the current Provider matrix
`wt-work --agent` SHALL accept `claude`, `codex`, `antigravity`, `agy`, and `copilot`, with `agy` normalized as an alias of `antigravity`. Each adapter SHALL launch from the resolved Worktree and express the same portable OpenSpec apply intent exactly once.

#### Scenario: Antigravity launch
- **WHEN** the user runs `wt-work feature123 --agent antigravity`
- **THEN** the system launches `agy` from the resolved Worktree with the apply intent

#### Scenario: Antigravity alias launch
- **WHEN** the user runs `wt-work feature123 --agent agy`
- **THEN** the system behaves identically to `--agent antigravity`

#### Scenario: Codex launch
- **WHEN** the user runs `wt-work feature123 --agent codex`
- **THEN** the system launches Codex with the resolved Worktree as its working root and the apply intent

#### Scenario: Invalid or removed Provider
- **WHEN** the user supplies `gemini` or another unsupported value
- **THEN** the system exits non-zero and lists only the four supported Provider values

### Requirement: wt-work resolves explicit and discovered Worktree paths safely
The system SHALL accept `--path <worktree-path>` with highest precedence. Without it, the resolver SHALL inspect only Git's registered Worktrees and select a candidate only when exactly one candidate can be verified for the requested change.

#### Scenario: Explicit registered path
- **WHEN** `--path` points to a registered Worktree belonging to the same repository and containing the reviewed planning commit
- **THEN** the system uses that path without creating or removing a Worktree

#### Scenario: Explicit invalid path
- **WHEN** `--path` is absent from the repository's Git Worktree registry, belongs to another repository, or lacks the planning commit
- **THEN** the system exits non-zero without launching a Provider

#### Scenario: One automatically discovered candidate
- **WHEN** exactly one eligible registered non-primary Worktree matches `.worktrees/<change-id>`, `feature/<change-id>`, or the verified detached-change criteria
- **THEN** the system attaches that candidate

#### Scenario: Ambiguous automatic discovery
- **WHEN** two or more registered Worktrees remain eligible
- **THEN** the system exits non-zero, lists their exact paths and states, and requires `--path`

### Requirement: Same-machine failover preserves dirty state
The resolver SHALL NOT require a clean Worktree for same-machine Provider failover. It SHALL report the current branch／detached state and dirty summary before launch and SHALL leave checkpoint commits to the user.

#### Scenario: Dirty Worktree attach
- **WHEN** the original active writer has stopped and the selected Worktree contains modified, staged, or untracked files
- **THEN** `wt-work` reports that state and launches the new Provider in the same path without stashing, committing, resetting, or deleting files

### Requirement: Project-managed setup copies only relevant local files
When creating a Project-managed Worktree, the system SHALL copy an existing `.env` plus the selected Provider's allowlisted repository-local settings. It SHALL NOT copy another Provider's local settings, overwrite tracked files, copy global credentials, create `.worktreeinclude`, or install dependencies.

#### Scenario: Claude local setup
- **WHEN** a Claude Worktree is created and `.env` plus `.claude/settings.local.json` exist in the source checkout
- **THEN** those existing local files are copied without copying Codex or Antigravity settings

#### Scenario: Selected Provider has no local-only file
- **WHEN** the selected Provider's allowlisted local setting is absent
- **THEN** Worktree creation continues successfully without synthesizing a setting file

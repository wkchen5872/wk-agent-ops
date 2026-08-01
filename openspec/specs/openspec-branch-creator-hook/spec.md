# openspec-branch-creator-hook

## Purpose

Provides the explicit `opsx-branch <change-id>` branch-first entry point plus a fail-soft Claude Code PostToolUse compatibility hook. The explicit command prepares `feature/<change-id>` before OpenSpec writes artifacts; the hook only repairs legacy invocation order when possible.

---

## Requirements

### Requirement: Hook detects openspec new change commands
The compatibility hook SHALL normalize supported PostToolUse events from Claude Code, Codex, and GitHub Copilot CLI, detect a successful shell command matching `openspec new change <name>`, and extract the change name. It SHALL silently ignore non-matching commands, failed tool executions, and inputs that cannot be normalized.

#### Scenario: Supported Provider reports successful change creation
- **WHEN** a supported Provider emits a successful PostToolUse event for `openspec new change "my-feature"`
- **THEN** the hook extracts `my-feature` and proceeds to branch coordination

#### Scenario: Change creation failed
- **WHEN** the observed `openspec new change <name>` execution reports failure
- **THEN** the hook exits 0 without attempting any Git operation

#### Scenario: Non-matching command is ignored
- **WHEN** the normalized shell command does not contain `openspec new change`
- **THEN** the hook exits 0 without attempting any Git operation

#### Scenario: Empty, malformed, or unsupported input
- **WHEN** stdin is empty, malformed, or does not contain a supported Provider event shape
- **THEN** the hook exits 0 without error

### Requirement: Hook creates feature branch in project directory
The compatibility hook SHALL resolve the repository directory from the normalized Provider event and invoke `opsx-branch <name>` from that repository. It SHALL NOT maintain a separate Git create-or-switch implementation.

#### Scenario: Branch coordination succeeds
- **WHEN** the hook observes successful creation of change `my-feature` and `opsx-branch my-feature` succeeds
- **THEN** the repository is on `feature/my-feature`
- **AND** the hook exits 0

#### Scenario: Explicit transition already selected the branch
- **WHEN** the repository is already on `feature/my-feature`
- **THEN** the delegated branch command succeeds without creating or switching to another branch

#### Scenario: Another Worktree owns the branch
- **WHEN** `opsx-branch my-feature` reports that another registered Worktree owns `feature/my-feature`
- **THEN** the hook reports a warning and exits 0
- **AND** it does not attach to, move, or delete either Worktree

#### Scenario: Repository directory is unavailable
- **WHEN** the Provider event and process environment do not resolve to a Git repository
- **THEN** the hook exits 0 without changing Git state

### Requirement: Hook never blocks Claude Code
The hook script SHALL always exit with code 0, regardless of any error (git failure, missing jq, network issue, non-git directory).

#### Scenario: git checkout fails
- **WHEN** `git checkout -b feature/<name>` fails (e.g., dirty working tree)
- **THEN** the hook logs the error to stderr and exits 0

#### Scenario: jq is not installed
- **WHEN** `jq` is not available on the system
- **THEN** the hook falls back to grep-based JSON parsing or skips branch creation, and exits 0

### Requirement: Hook is registered via PostToolUse in settings.json
The installer SHALL idempotently deploy the compatibility hook for Claude Code, Codex, and GitHub Copilot CLI using each Provider's supported PostToolUse configuration. An existing compatible Codex entry migrated from Claude Code SHALL count as registered and SHALL NOT be duplicated. Antigravity SHALL use the Agent-mediated branch guard and SHALL NOT receive this compatibility hook.

#### Scenario: Standard install registers supported hooks
- **WHEN** the installer runs with Claude Code, Codex, or GitHub Copilot CLI configuration available
- **THEN** it registers one compatibility hook entry for each available supported Provider

#### Scenario: Migrated Codex entry already exists
- **WHEN** `~/.codex/hooks.json` already contains the compatible PostToolUse command migrated from Claude Code
- **THEN** installation preserves that entry without adding a duplicate

#### Scenario: Antigravity is installed
- **WHEN** the installer detects Antigravity
- **THEN** it does not register a broad shell PostToolUse hook for Antigravity

#### Scenario: Re-running install is idempotent
- **WHEN** the installer runs more than once
- **THEN** each supported Provider configuration contains at most one registration for the deployed hook

#### Scenario: Uninstall removes managed registrations
- **WHEN** the uninstaller runs
- **THEN** it removes the managed Claude Code, Codex, and GitHub Copilot CLI registrations and the deployed hook

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

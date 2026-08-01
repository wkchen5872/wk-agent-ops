## MODIFIED Requirements

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


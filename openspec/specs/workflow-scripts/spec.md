# workflow-scripts

## Purpose

Specifications for the branch-first workflow helper (`opsx-branch`) and its installation, completion, retirement safety, and documentation requirements.

---

## Requirements

### Requirement: workflow install.sh deploys hook as part of standard setup
`scripts/workflow/install.sh` SHALL deploy only `opsx-branch`, its zsh completion, and the existing branch compatibility hook. It SHALL retain the Agent-mediated branch-first contract for Claude Code, Codex, Antigravity, and GitHub Copilot CLI without adding a Session manager dependency.

#### Scenario: Running install.sh installs workflow entrypoints and fallback hooks
- **WHEN** workflow installation runs in a clean supported environment
- **THEN** opsx-branch and its completion are installed with the existing compatible fallback hooks
- **AND** wt-work, wt-resume, wt-done, pm-start, and wk-workflow-runtime are not installed

#### Scenario: Provider has no supported fallback hook
- **WHEN** a supported Provider has no suitable narrow PostToolUse integration
- **THEN** installation leaves that hook unregistered and retains the Agent-mediated branch guard

#### Scenario: Repeated installation
- **WHEN** installation runs twice
- **THEN** retained commands, completion, hook registrations, and shell initialization remain idempotent

### Requirement: Upgrade safely retires recognized legacy installations
The installer SHALL remove only recognized unmodified regular-file copies of retired commands, runtime, and completion at its known installation paths. It SHALL preserve and report modified, unknown, or symlink entries, leave unrelated files and workflow data untouched, and retain shared PATH and fpath configuration.

#### Scenario: Recognized old installation
- **WHEN** a known installation path contains an unmodified copy matching the shipped legacy reference
- **THEN** the installer removes that legacy copy and reports the removal
- **AND** existing branches, worktrees, Sessions, settings, and credentials remain untouched

#### Scenario: Customized or linked entry
- **WHEN** a legacy path contains modified or unknown content or a symlink including a dangling symlink
- **THEN** the installer preserves the entry and its target and reports manual cleanup is needed

#### Scenario: Absent legacy installation
- **WHEN** legacy installation entries are absent
- **THEN** installation succeeds without requiring legacy commands or altering unrelated entries

### Requirement: Current documentation describes the retained workflow boundary
Current documentation and installed Skill instructions SHALL describe branch preparation separately from user-selected Session and Worktree management. They SHALL remove runnable retired-command guidance and broken references while preserving general handoff, single-writer, review identity, and cleanup ownership rules. Historical archives and Work Item records SHALL remain unchanged.

#### Scenario: Reader follows current guidance
- **WHEN** a reader follows current installation or development guidance
- **THEN** no step requires a retired command
- **AND** retained branch-first instructions and document links resolve

### Requirement: Agent-mediated branch preparation guards OpenSpec planning actions
After a change ID is accepted or derived, the Agent SHALL run `opsx-branch <change-id>` before continuing an OpenSpec new, fast-forward, or continue action. The Agent SHALL continue the requested OpenSpec action only when branch preparation exits 0.

#### Scenario: New action prepares the branch before scaffolding
- **WHEN** an Agent has resolved the change ID for `openspec-new-change` or `opsx:new`
- **THEN** it runs `opsx-branch <change-id>` before `openspec new change <change-id>`
- **AND** it creates the scaffold only after branch preparation succeeds

#### Scenario: Fast-forward action prepares the branch before scaffolding
- **WHEN** an Agent has resolved the change ID for `openspec-ff-change` or `opsx:ff`
- **THEN** it runs `opsx-branch <change-id>` before creating the change or any artifact

#### Scenario: Continue action prepares the branch before reading status
- **WHEN** an Agent resolves an existing change ID for `openspec-continue-change` or `opsx:continue`
- **THEN** it runs `opsx-branch <change-id>` before reading status, instructions, or writing the next artifact

#### Scenario: Branch preparation fails
- **WHEN** `opsx-branch <change-id>` exits non-zero
- **THEN** the Agent stops the current OpenSpec action and reports the branch error
- **AND** it does not create or modify change artifacts

#### Scenario: Another Worktree owns the branch
- **WHEN** branch preparation reports an existing Worktree path for `feature/<change-id>`
- **THEN** the Agent reports that path and stops
- **AND** it does not automatically attach to that Worktree or create another writer

### Requirement: Supported Providers expose the same branch guard contract
Claude Code, Codex, Antigravity, and GitHub Copilot CLI integrations SHALL instruct the Agent to apply the same `opsx-branch` success gate. Provider-specific hooks MAY remain compatibility fallbacks but SHALL NOT be required for branch-first correctness.

#### Scenario: Provider follows Agent-mediated instructions
- **WHEN** a supported Provider executes an OpenSpec new, fast-forward, or continue entrypoint
- **THEN** it applies the same branch preparation and stop behavior regardless of hook availability

#### Scenario: Codex already has a migrated compatibility hook
- **WHEN** Codex has imported a compatible Claude Code PostToolUse registration
- **THEN** the Agent-mediated guard still runs before the OpenSpec action
- **AND** the later hook invocation is idempotent

#### Scenario: Compatibility hook is unavailable
- **WHEN** a Provider does not install, enable, or execute the compatibility hook
- **THEN** successful Agent-mediated branch preparation still places the OpenSpec action on `feature/<change-id>`

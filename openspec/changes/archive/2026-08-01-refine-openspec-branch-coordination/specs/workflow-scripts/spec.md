## MODIFIED Requirements

### Requirement: workflow install.sh deploys hook as part of standard setup
`scripts/workflow/install.sh` SHALL install `wt-work`, `wt-done`, `wt-resume`, `pm-start`, `opsx-branch`, and shell completion. It SHALL deploy the idempotent openspec-branch-creator hook as a compatibility fallback for Claude Code, Codex, and GitHub Copilot CLI while identifying the Agent-mediated `opsx-branch` transition as the branch-first contract for all supported Providers.

#### Scenario: Running install.sh installs workflow entrypoints and fallback hooks
- **WHEN** `bash scripts/workflow/install.sh` is executed
- **THEN** all five workflow commands and shell completion are installed
- **AND** compatible fallback hooks are registered without duplication
- **AND** the output identifies `opsx-branch` as the pre-action transition

#### Scenario: Provider has no supported fallback hook
- **WHEN** a supported Provider such as Antigravity has no suitable narrow PostToolUse integration
- **THEN** installation leaves that hook unregistered
- **AND** the Agent-mediated branch-first contract remains available

## ADDED Requirements

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

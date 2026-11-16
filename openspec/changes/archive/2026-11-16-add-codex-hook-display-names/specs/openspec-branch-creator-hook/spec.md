# Spec Delta

## ADDED Requirements

### Requirement: Codex branch hook has a display name

The branch compatibility hook installer SHALL register its Codex PostToolUse handler with the default `statusMessage` `OpenSpec 規劃分支檢查`. The field SHALL be on the handler alongside `type` and `command`. The existing command, matcher, timeout, branch coordination, and fail-soft behavior SHALL remain unchanged.

#### Scenario: First Codex installation is named

- **WHEN** the compatibility hook installer registers a new Codex handler
- **THEN** the handler has `statusMessage` equal to `OpenSpec 規劃分支檢查`
- **AND** the configuration contains one matching PostToolUse registration

### Requirement: Existing Codex branch hooks receive missing names

Installation SHALL fill absent, null, empty, or whitespace-only `statusMessage` values on an existing matching Codex branch handler, including an entry migrated from Claude Code. It SHALL preserve non-blank custom names, matcher groups, all other handler fields, unrelated hooks, and top-level settings. Repeated installation MUST NOT add duplicate registrations.

#### Scenario: A migrated entry lacks a name

- **WHEN** Codex configuration contains the matching branch command migrated from Claude Code without `statusMessage`
- **THEN** installation adds the default name to the existing handler
- **AND** its command, matcher, timeout, and other fields are preserved without adding another handler

#### Scenario: A blank name is repaired

- **WHEN** an existing branch handler has null, empty, or whitespace-only `statusMessage`
- **THEN** installation replaces only that value with the documented default

#### Scenario: A custom name survives repeated installation

- **WHEN** installation runs twice with an existing non-blank custom branch name and unrelated handlers
- **THEN** the custom name and unrelated configuration remain unchanged
- **AND** the second run leaves the JSON configuration semantically unchanged

### Requirement: Branch naming is isolated to Codex

The display-name change SHALL preserve the existing Claude Code and Copilot hook registration formats. Antigravity SHALL continue using the Agent-mediated branch guard without receiving a compatibility hook. The installer MUST NOT write Codex trust or enable state.

#### Scenario: Supported tools are installed together

- **WHEN** the installer runs with the supported tools configured
- **THEN** the Codex handler receives its name, Claude Code and Copilot retain their existing fields, and no Antigravity compatibility hook is added
- **AND** the installer leaves Codex trust and enable state to the user

# Spec Delta

## ADDED Requirements

### Requirement: Codex handoff hook has a display name

The handoff installer SHALL register its Codex Stop handler with the default `statusMessage` `Agent 交接派送`, on the handler alongside `type` and `command`. The existing hook command, matcher, timeout, and routing behavior SHALL remain unchanged.

#### Scenario: First handoff installation is named

- **WHEN** the handoff installer registers a new Codex Stop handler
- **THEN** that handler has `statusMessage` equal to `Agent 交接派送`
- **AND** the configuration contains one matching Stop registration

### Requirement: Existing Codex handoff hooks receive missing names

Installation SHALL fill absent, null, empty, or whitespace-only `statusMessage` values on the matching owned Codex handoff handler. It SHALL preserve non-blank custom names, all other handler and matcher-group fields, unrelated handlers, and top-level settings. Repeated installation MUST NOT add duplicate registrations.

#### Scenario: Existing handoff registration has no usable name

- **WHEN** the handoff installer finds an existing handler with absent, null, empty, or whitespace-only `statusMessage`
- **THEN** it adds the documented default name to that handler without replacing other fields

#### Scenario: Custom handoff name survives repeated installation

- **WHEN** installation runs twice with a non-blank custom handoff name and an unrelated Stop handler
- **THEN** the custom name and unrelated handler remain unchanged
- **AND** the second run leaves the JSON configuration semantically unchanged

### Requirement: Handoff naming preserves provider and trust boundaries

Adding a Codex handoff display name SHALL leave the Claude Code Stop registration format unchanged. The installer and its documentation SHALL tell the user to open a new Codex session and review new or changed hook definitions in `/hooks`. The installer MUST NOT modify Codex trust or enable state.

#### Scenario: Naming an installed hook needs review

- **WHEN** installation adds a name to an existing Codex handoff hook
- **THEN** it directs the user to review the changed hook after opening a new session
- **AND** Codex trust and enable state are left unchanged

#### Scenario: Claude Code remains compatible

- **WHEN** the handoff installer registers both supported providers
- **THEN** only the Codex handler receives the new default naming field
- **AND** the Claude Code handler retains its existing configuration fields and behavior

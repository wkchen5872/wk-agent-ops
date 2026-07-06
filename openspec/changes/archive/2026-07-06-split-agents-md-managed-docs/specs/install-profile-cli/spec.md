## ADDED Requirements

### Requirement: Managed vs seed doc ownership
install.sh SHALL classify each shipped doc by ownership. **Managed** docs (shared upstream
standards) SHALL be overwritten on every install so downstream repos pull updates by
re-running install.sh. **Seed** docs (project-fill files) SHALL be copied only if absent and
never overwritten. `docs/agent-protocol.md` and `docs/okf-conventions.md` are managed;
`docs/architecture.md` and `docs/conventions.md` are seed. Doc paths SHALL NOT change.

#### Scenario: Managed doc is overwritten on re-install
- **WHEN** a target already has a modified `docs/agent-protocol.md` and install.sh runs
- **THEN** `docs/agent-protocol.md` is overwritten with the template's current version

#### Scenario: Seed doc is preserved on re-install
- **WHEN** a target already has a `docs/architecture.md` with project content and install.sh runs
- **THEN** `docs/architecture.md` is left unchanged (not overwritten)

#### Scenario: First install seeds both kinds
- **WHEN** install.sh runs against a target with no `docs/`
- **THEN** both managed and seed docs are created from the template

### Requirement: Managed files carry a do-not-edit banner
Every managed doc shipped by install.sh SHALL carry a banner at the top indicating it is
managed by wk-agent-ops and that local edits are overwritten on install, so downstream editors
are not surprised by clobbered changes.

#### Scenario: Managed doc banner present
- **WHEN** a managed doc (e.g. `docs/agent-protocol.md`) is read
- **THEN** its first lines state it is managed upstream and that edits will be overwritten on install

#### Scenario: Seed doc has no managed banner
- **WHEN** a seed doc (e.g. `docs/architecture.md`) is read
- **THEN** it does not carry the managed banner (it is project-owned)

### Requirement: AGENTS.md remains copy-once
install.sh SHALL continue to copy `AGENTS.md` only when absent in the target, preserving the
downstream project's own additions. Protocol updates reach the project through the managed
`docs/agent-protocol.md`, not by overwriting `AGENTS.md`.

#### Scenario: Existing AGENTS.md is preserved but protocol doc updates
- **WHEN** a target already has an `AGENTS.md` and install.sh runs
- **THEN** `AGENTS.md` is not overwritten
- **AND** `docs/agent-protocol.md` is (re)written to the current template version

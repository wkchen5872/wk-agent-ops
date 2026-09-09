## MODIFIED Requirements

### Requirement: Codex custom-agent templates are project owned
The common profile SHALL provide Codex custom-agent templates named
`git-commit-writer-agent` and `doc-updater-agent`. Each template MUST define the
Codex-required `name`, `description`, and `developer_instructions` fields, and
the `name` value MUST match its suffixed filename.

#### Scenario: Common template inventory is inspected
- **WHEN** `template/common/.codex/agents/` is inspected
- **THEN** it contains `git-commit-writer-agent.toml` and `doc-updater-agent.toml`
- **AND** each file contains all required Codex custom-agent fields
- **AND** it does not contain the obsolete unsuffixed project-owned templates

### Requirement: Installed Codex custom agents match their templates
The common installer SHALL copy the project-owned Codex custom-agent templates
to `.codex/agents/` without content drift. It SHALL remove only the obsolete
project-owned `git-commit-writer.toml` and `doc-updater.toml` files during this
naming migration and MUST preserve unrelated `.codex/agents/` files.

#### Scenario: Common profile is installed
- **WHEN** the common profile is installed into a clean Git repository
- **THEN** `.codex/agents/git-commit-writer-agent.toml` matches its template byte-for-byte
- **AND** `.codex/agents/doc-updater-agent.toml` matches its template byte-for-byte

#### Scenario: Existing installation is upgraded
- **WHEN** the common installer runs in a repository containing the obsolete project-owned unsuffixed Codex agent files
- **THEN** those two obsolete files are removed
- **AND** the suffixed files are installed
- **AND** unrelated files under `.codex/agents/` remain unchanged

#### Scenario: Installer is run repeatedly
- **WHEN** the common installer is run more than once against the same target
- **THEN** the installed Codex custom-agent files remain identical to their templates

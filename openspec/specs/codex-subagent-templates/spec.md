# codex-subagent-templates Specification

## Purpose

Define project-owned Codex custom-agent templates and their required model configuration so installations remain reproducible and do not drift from this repository's maintained agent behavior.

## Requirements

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

### Requirement: Codex custom agents use workload-specific models
The Git Commit Writer custom agent SHALL set `model = "gpt-5.6-luna"` and `model_reasoning_effort = "medium"`. The Doc Updater custom agent SHALL set `model = "gpt-5.6-terra"` and `model_reasoning_effort = "medium"`.

#### Scenario: Git Commit Writer model configuration is validated
- **WHEN** the Git Commit Writer Codex template is inspected
- **THEN** its model is `gpt-5.6-luna`
- **AND** its reasoning effort is `medium`

#### Scenario: Doc Updater model configuration is validated
- **WHEN** the Doc Updater Codex template is inspected
- **THEN** its model is `gpt-5.6-terra`
- **AND** its reasoning effort is `medium`

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

### Requirement: GitHub copy agents use the Terra model
The GitHub PR and GitHub Issue Codex custom agents SHALL be project-owned templates that set `model = "gpt-5.6-terra"` and `model_reasoning_effort = "medium"`, and SHALL be installed identically to their templates.

#### Scenario: GitHub PR agent model configuration is validated
- **WHEN** the GitHub PR Codex template is inspected
- **THEN** its model is `gpt-5.6-terra`
- **AND** its reasoning effort is `medium`

#### Scenario: GitHub Issue agent model configuration is validated
- **WHEN** the GitHub Issue Codex template is inspected
- **THEN** its model is `gpt-5.6-terra`
- **AND** its reasoning effort is `medium`

# codex-subagent-templates Specification

## Purpose

Define project-owned Codex custom-agent templates and their required model configuration so installations remain reproducible and do not drift from this repository's maintained agent behavior.

## Requirements

### Requirement: Codex custom-agent templates are project owned
The common profile SHALL provide Codex custom-agent templates for `git-commit-writer` and `doc-updater`. Each template MUST define the Codex-required `name`, `description`, and `developer_instructions` fields.

#### Scenario: Common template inventory is inspected
- **WHEN** `template/common/.codex/agents/` is inspected
- **THEN** it contains `git-commit-writer.toml` and `doc-updater.toml`
- **AND** each file contains all required Codex custom-agent fields

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
The common installer SHALL copy the project-owned Codex custom-agent templates to `.codex/agents/` without content drift.

#### Scenario: Common profile is installed
- **WHEN** the common profile is installed into a clean Git repository
- **THEN** `.codex/agents/git-commit-writer.toml` matches its template byte-for-byte
- **AND** `.codex/agents/doc-updater.toml` matches its template byte-for-byte

#### Scenario: Installer is run repeatedly
- **WHEN** the common installer is run more than once against the same target
- **THEN** the installed Codex custom-agent files remain identical to their templates

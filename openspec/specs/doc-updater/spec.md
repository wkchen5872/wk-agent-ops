# Spec: doc-updater

## Purpose

The doc-updater agent/skill automatically updates documentation files based on code changes. It detects whether there are uncommitted changes or operates on recent commits, then analyzes diffs to determine which documentation files need updating and applies minimal targeted edits.

## Requirements

### Requirement: Detect mode based on git status
The doc-updater agent/skill SHALL first check `git status` to determine which mode to operate in.

#### Scenario: Uncommitted changes exist (Mode A)
- **WHEN** `git status` shows staged or unstaged changes
- **THEN** the agent SHALL operate in Mode A, using `git diff HEAD` as the source of changes to analyze

#### Scenario: No uncommitted changes (Mode B)
- **WHEN** `git status` shows a clean working tree
- **THEN** the agent SHALL operate in Mode B, using caller-provided N, asking
  when supported, or defaulting to 1 (range 1-10)

### Requirement: Accept optional archived change context
`doc-updater` SHALL accept optional `change_id` and `archive_path` inputs from a
coordinating workflow. When provided, it MUST validate and read the archived
proposal and delta specs before selecting documentation targets.

#### Scenario: Called by openspec-commit
- **WHEN** `doc-updater` receives a valid `archive_path`
- **THEN** it reads `<archive_path>/proposal.md`
- **AND** reads available `<archive_path>/specs/**/*.md`
- **AND** uses that context together with the Git diff

#### Scenario: Archive context is invalid
- **WHEN** an explicit `archive_path` does not exist
- **THEN** `doc-updater` stops and reports the invalid path without editing docs

### Requirement: Prefer actual changes over stated intent
OpenSpec proposal and spec context SHALL guide document discovery, but
`doc-updater` MUST inspect Git status and diff as the evidence of what was
implemented.

#### Scenario: Proposal and implementation differ
- **WHEN** the archived proposal names a component that has no corresponding
  implementation change
- **THEN** `doc-updater` does not document that component as implemented

### Requirement: Mode A — scan uncommitted changes and update docs
In Mode A, the doc-updater agent/skill SHALL inspect `git status --short` and
`git diff HEAD`, plus explicit archived change context when supplied. It SHALL
update relevant documentation files and leave those edits in the working tree
for the upcoming commit.

#### Scenario: New agent or skill file in changes
- **WHEN** the prepared `git diff HEAD` shows a new agent or skill under
  `.claude/` or `template/common/`
- **THEN** the agent SHALL update `AGENTS.md` with a matching entry when needed

#### Scenario: New user-facing feature in changes
- **WHEN** the diff and archived change context establish a substantive
  user-facing capability
- **THEN** the agent SHALL update `README.md` and/or the relevant `docs/*.md` file

#### Scenario: Mode A does not create a separate commit
- **WHEN** Mode A completes doc updates
- **THEN** it SHALL NOT create a Git commit
- **AND** the documentation changes remain available to the coordinator

### Requirement: Mode B — scan last N commits and update docs
In Mode B, the doc-updater agent/skill SHALL use a caller-provided N or ask the
user how many recent commits to scan when the host supports interactive
questions. It SHALL default to 1 when neither is available, limit N to 1-10,
scan those commits' diffs, update relevant documentation files, and leave the
changes uncommitted for review.

#### Scenario: No interactive question capability
- **WHEN** Mode B runs in a subagent without an interactive question tool
- **AND** the caller did not provide N
- **THEN** the agent SHALL scan only `git diff HEAD~1 HEAD`

#### Scenario: User specifies N commits
- **WHEN** the user selects N from 2 through 10
- **THEN** the agent SHALL scan `git diff HEAD~N HEAD`

#### Scenario: Mode B leaves changes in working tree
- **WHEN** Mode B completes doc updates
- **THEN** the agent SHALL NOT create a commit

#### Scenario: Mode B skip for all-docs commits
- **WHEN** all selected commits have a `docs:` subject prefix
- **THEN** the agent SHALL report a skip and make no changes

### Requirement: Analyze diff to determine documentation impact
The doc-updater agent/skill SHALL analyze the diff content and determine which documentation files need updating.

#### Scenario: New agent or skill file added
- **WHEN** diff shows a new `.claude/agents/*.md` or `.claude/skills/*/SKILL.md` file
- **THEN** the agent SHALL update `AGENTS.md` with a new entry in the existing format

#### Scenario: New user-facing feature
- **WHEN** diff shows new capability files with broad user impact
- **THEN** the agent SHALL update `README.md` and/or create/update the relevant `docs/*.md` file

#### Scenario: New dependency or environment variable
- **WHEN** diff shows a new dependency or env var reference
- **THEN** the agent SHALL update the dependencies section of `README.md`

#### Scenario: Template profile changes
- **WHEN** diff shows changes to `template/common/` structure or `install.sh`
- **THEN** the agent SHALL update `docs/template-profiles.md` and/or `README.md`

#### Scenario: No documentation impact
- **WHEN** diff shows only internal implementation changes with no user-facing impact
- **THEN** the agent SHALL output a message explaining why no update is needed and make no changes

### Requirement: Make only minimal targeted edits
The doc-updater agent SHALL edit only the relevant sections of each document and MUST NOT rewrite or restructure unaffected sections.

#### Scenario: Adding entry to AGENTS.md
- **WHEN** updating AGENTS.md for a new agent or skill
- **THEN** the agent SHALL insert only the new entry block after the existing entries, preserving all existing content

#### Scenario: Updating README.md
- **WHEN** updating README.md
- **THEN** the agent SHALL add a row to an existing table or append to an existing list, using Traditional Chinese to match the file's language

### Requirement: Dual-location file sync
The doc-updater agent and skill files SHALL exist in both the active location and the template location.

#### Scenario: Template source exists
- **WHEN** the change is implemented
- **THEN** both `template/common/.claude/agents/doc-updater.md` and `.claude/agents/doc-updater.md` SHALL contain identical content

#### Scenario: Skill template source exists
- **WHEN** the change is implemented
- **THEN** both `template/common/skills/doc-updater/SKILL.md` and `.claude/skills/doc-updater/SKILL.md` SHALL contain identical content

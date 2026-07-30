## ADDED Requirements

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

## MODIFIED Requirements

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
- **THEN** the agent SHALL update `README.md` and/or the relevant `docs/*.md`

#### Scenario: Mode A does not create a separate commit
- **WHEN** Mode A completes documentation updates
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
- **WHEN** Mode B completes documentation updates
- **THEN** the agent SHALL NOT create a commit

#### Scenario: Mode B skip for all-docs commits
- **WHEN** all selected commits have a `docs:` subject prefix
- **THEN** the agent SHALL report a skip and make no changes

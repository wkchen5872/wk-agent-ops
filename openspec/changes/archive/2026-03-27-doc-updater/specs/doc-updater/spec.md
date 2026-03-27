## ADDED Requirements

### Requirement: Detect mode based on git status
The doc-updater agent/skill SHALL first check `git status` to determine which mode to operate in.

#### Scenario: Uncommitted changes exist (Mode A)
- **WHEN** `git status` shows staged or unstaged changes
- **THEN** the agent SHALL operate in Mode A, using `git diff HEAD` as the source of changes to analyze

#### Scenario: No uncommitted changes (Mode B)
- **WHEN** `git status` shows a clean working tree
- **THEN** the agent SHALL operate in Mode B, asking the user how many recent commits to scan (default 1, range 1-10)

### Requirement: Mode A — scan uncommitted changes and update docs
In Mode A, the doc-updater agent/skill SHALL scan the current uncommitted changes (staged + unstaged) and update relevant documentation files, leaving the doc changes in the working tree to be included in the upcoming commit.

#### Scenario: New agent or skill file in staged changes
- **WHEN** `git diff HEAD` shows a new `.claude/agents/*.md` or `.claude/skills/*/SKILL.md` file
- **THEN** the agent SHALL update `AGENTS.md` with a new entry describing the agent/skill

#### Scenario: New user-facing feature in staged changes
- **WHEN** `git diff HEAD` shows substantive new capability files
- **THEN** the agent SHALL update `README.md` and/or the relevant `docs/*.md` file

#### Scenario: Mode A does not create a separate commit
- **WHEN** Mode A completes doc updates
- **THEN** the agent SHALL NOT create a git commit — the doc changes stay as uncommitted changes alongside the feature changes

### Requirement: Mode B — scan last N commits and update docs
In Mode B, the doc-updater agent/skill SHALL ask the user how many recent commits to scan (default 1, range 1-10), scan those commits' diffs, update relevant documentation files, and create a separate `docs:` commit.

#### Scenario: User accepts default (1 commit)
- **WHEN** Mode B is triggered and user does not specify N
- **THEN** the agent SHALL scan only the last commit (`git diff HEAD~1 HEAD`)

#### Scenario: User specifies N commits
- **WHEN** Mode B is triggered and user specifies N (2-10)
- **THEN** the agent SHALL scan the last N commits collectively (`git diff HEAD~N HEAD`)

#### Scenario: Mode B leaves changes in working tree
- **WHEN** Mode B completes doc updates
- **THEN** the agent SHALL leave all doc changes in the working tree and NOT create a git commit — the user reviews and commits manually

#### Scenario: Mode B skip for all-docs commits
- **WHEN** all N commits being scanned have type `docs:` as their subject prefix
- **THEN** the agent SHALL output a skip message and make no changes (prevents infinite loop)

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

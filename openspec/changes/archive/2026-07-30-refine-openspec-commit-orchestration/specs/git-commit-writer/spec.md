## MODIFIED Requirements

### Requirement: Generate commit message from openspec change context
`git-commit-writer` SHALL validate and directly use explicit `archive_path` and
`change_id` inputs when they are supplied. Standalone
auto-detection SHALL be used only when explicit context is absent.

#### Scenario: Archive path provided explicitly
- **WHEN** `archive_path` and `change_id` are passed by `openspec-commit`
- **THEN** the skill verifies that `<archive_path>` exists
- **AND** reads `<archive_path>/proposal.md`
- **AND** formats `<type>(<change_id>): <subject>`

#### Scenario: Explicit archive path is missing
- **WHEN** a supplied `archive_path` does not exist
- **THEN** the skill stops before staging or committing

#### Scenario: Standalone active change
- **WHEN** no explicit context is supplied
- **AND** exactly one active or uncommitted archived change is detected
- **THEN** the skill may use the detected change context

#### Scenario: Multiple standalone candidates
- **WHEN** no explicit context is supplied and multiple candidates are detected
- **THEN** the skill asks the user to select one when the host supports
  interactive questions
- **AND** otherwise stops and returns the candidates to its caller
- **AND** MUST NOT choose the first

### Requirement: Execute commit without confirmation
The skill SHALL execute `git add -A` immediately before reading the cached diff
and committing, without a separate confirmation prompt. It MUST stop when the
staged diff is empty.

#### Scenario: Successful commit
- **WHEN** the worktree contains intended feature, archive, and documentation
  changes
- **THEN** the skill runs `git add -A`
- **AND** derives the message from `git diff --cached`
- **AND** executes `git commit -m "<message>"`
- **AND** prints the short commit hash

#### Scenario: Empty staged diff
- **WHEN** `git add -A` produces no staged changes
- **THEN** the skill reports that there is nothing to commit and stops

#### Scenario: Pre-commit hook failure
- **WHEN** `git commit` fails due to a pre-commit hook
- **THEN** the skill fixes the issue
- **AND** reruns `git add -A` before retrying
- **AND** never uses `--no-verify`

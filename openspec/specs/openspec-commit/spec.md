# Spec: openspec-commit

## Purpose

TBD — A skill that finalizes an openspec change by archiving it and committing all related changes with a properly formatted Conventional Commits message.

## Requirements

### Requirement: Coordinate the completion workflow in order
`openspec-commit` SHALL invoke exactly one archive action, followed by
`doc-updater`, followed by `git-commit-writer`. It MUST stop before downstream
steps when archive fails.

#### Scenario: Successful ordered completion
- **WHEN** a selected OpenSpec change archives successfully
- **THEN** the workflow invokes `doc-updater` after archive
- **AND** invokes `git-commit-writer` only after documentation handling completes

#### Scenario: Archive failure
- **WHEN** `openspec-archive-change` fails or does not return an archive path
- **THEN** the workflow stops without invoking `doc-updater` or `git-commit-writer`

### Requirement: Preserve exact archive context
The workflow SHALL retain `change_id`, `archive_path`, spec sync status, and
archive warnings returned by the archive action. It MUST pass the exact
`archive_path` and `change_id` to downstream capabilities and MUST NOT select an
archive by newest modification time.

#### Scenario: Archive completes
- **WHEN** the archive action returns
  `openspec/changes/archive/YYYY-MM-DD-<change>/`
- **THEN** documentation and commit steps use that exact path
- **AND** no `ls -t` or equivalent newest-directory heuristic is used

### Requirement: Resume an interrupted completion workflow
`openspec-commit` SHALL detect an uncommitted archived change and resume from
documentation update when archive has already completed.

#### Scenario: Retry after documentation failure
- **WHEN** no matching active change exists
- **AND** Git status contains exactly one uncommitted archive candidate
- **THEN** the workflow reuses that archive and skips the archive action

#### Scenario: Multiple resume candidates
- **WHEN** Git status contains multiple uncommitted archive candidates
- **THEN** the workflow asks the user to select one and MUST NOT guess

### Requirement: Use provider-neutral OpenSpec actions
The workflow SHALL use `openspec-archive-change` as the portable archive
capability and treat provider-native OPSX commands/workflows as aliases to that
same action. It MUST invoke only one entry point.

#### Scenario: Claude Code execution
- **WHEN** the workflow runs in Claude Code
- **THEN** it may resolve the archive capability from `.claude/skills/` or the
  native `.claude/commands/opsx/archive.md` alias
- **AND** performs the archive action once

#### Scenario: Codex execution
- **WHEN** the workflow runs in Codex
- **THEN** it resolves `openspec-archive-change` from the available skill
  integration, including OpenSpec-generated `.codex/skills/`

#### Scenario: Antigravity execution
- **WHEN** the workflow runs in Antigravity
- **THEN** it may resolve the capability from `.agent/skills/` or the native
  `.agent/workflows/opsx-archive.md` alias
- **AND** performs the archive action once

### Requirement: Stage the complete implementation before documentation analysis
After archive succeeds, `openspec-commit` SHALL run `git add -A` before invoking
`doc-updater`, so `git diff HEAD` includes tracked, newly created, synced, and
archived content.

#### Scenario: Feature contains an untracked source file
- **WHEN** archive completes and the feature includes a new untracked file
- **THEN** the coordinator stages the worktree before documentation analysis
- **AND** `doc-updater` can inspect the new file through `git diff HEAD`

### Requirement: Execute git commit step
After archiving the change and updating docs, `openspec-commit` SHALL delegate
final staging and commit execution to `git-commit-writer` rather than performing
the commit inline. The coordinator SHALL pass the exact `archive_path`,
`change_id`, executing `tool_name`, and primary `assisting_model` in every
supported provider. It MUST pass the model responsible for the implementation,
not substitute the model of a commit-only sub-agent.

#### Scenario: Claude Code environment
- **WHEN** `openspec-commit` reaches the commit step in Claude Code
- **THEN** it invokes the Claude `git-commit-writer` agent with `archive_path`,
  `change_id`, `tool_name=Claude Code`, and the primary assisting model

#### Scenario: Codex or Antigravity environment
- **WHEN** `openspec-commit` reaches the commit step outside Claude Code
- **THEN** it invokes the portable `git-commit-writer` skill with `archive_path`,
  `change_id`, the current tool name, and the primary assisting model

#### Scenario: Commit succeeds
- **WHEN** `git-commit-writer` returns a commit hash
- **THEN** `openspec-commit` reports the exact archive, documentation result,
  and commit hash

### Requirement: Project-owned provider entrypoints delegate exactly once
The project-owned Claude Code `/opsx:commit` command and Antigravity
`/opsx-commit` workflow SHALL delegate to `openspec-commit` exactly once. Each
entrypoint MUST NOT execute archive, documentation update, or commit as separate
actions outside the delegated skill. Each entrypoint SHALL accept an optional
OpenSpec change name and pass it unchanged to `openspec-commit`.

#### Scenario: Claude Code command receives a change name
- **WHEN** a user invokes `/opsx:commit <change-name>` in Claude Code
- **THEN** the command invokes `openspec-commit` through the Skill tool exactly once
- **AND** passes `<change-name>` unchanged
- **AND** does not execute any completion step separately

#### Scenario: Antigravity workflow receives a change name
- **WHEN** a user invokes `/opsx-commit <change-name>` in Antigravity
- **THEN** the workflow activates `openspec-commit` exactly once
- **AND** passes `<change-name>` unchanged
- **AND** does not use Claude Code-specific `Skill tool` or `/opsx:apply` terminology

#### Scenario: Antigravity cannot activate a nested skill
- **WHEN** the Antigravity host cannot activate `openspec-commit` as a nested skill
- **THEN** the workflow follows the project-owned skill instructions in the current context
- **AND** still performs the completion workflow exactly once

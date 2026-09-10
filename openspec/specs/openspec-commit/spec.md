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
After archiving the change and updating docs, `openspec-commit` SHALL resolve
the executing `tool_name` and exact root-session `assisting_model` immediately
before delegating final staging and commit execution. It MUST NOT request or
require `assisting_model` before archive or documentation handling.

When the current root session performed the work and exposes an exact model
identity, the coordinator MUST use that identity automatically and MUST NOT ask
the user to repeat it. It SHALL continue using the exact current root-session
identity for later commits in the same session while the root model remains
unchanged. Provider-native documentation and commit subagents MUST NOT replace
or make the root-session attribution ambiguous.

If the work came from another session, the root model changed during the work,
or the exact root model identity is unavailable, the coordinator MUST request
the exact value immediately before commit delegation. A provider alias, generic
model-family label, system-description family, environment inference,
documentation lookup, session-log parser, Git history, or commit-only agent
identity MUST NOT be treated as proof of the root-session model.

In Claude Code and Codex the coordinator SHALL invoke the provider-native
`git-commit-writer-agent` by its exact agent name without supplying a spawn
model or reasoning-effort override; in every other provider it SHALL invoke the
portable `git-commit-writer` skill. It SHALL pass the exact `archive_path`,
`change_id`, `tool_name`, and resolved `assisting_model` as task input.
`assisting_model` is Git attribution metadata only and MUST NOT configure a
subagent runtime. If Claude Code or Codex cannot invoke the required subagent,
the workflow MUST stop without falling back to the portable skill.

#### Scenario: Codex or Antigravity environment
- **WHEN** `openspec-commit` reaches the commit step in Codex or Antigravity
- **THEN** Codex automatically uses the exact unchanged root-session model without asking when the current session performed the work
- **AND** Codex invokes `git-commit-writer-agent` by exact name without a spawn model or effort override
- **AND** Antigravity invokes the portable `git-commit-writer` skill with the resolved root-session attribution

#### Scenario: Claude Code environment
- **WHEN** the current Claude Code root session performed the work, its supported runtime or session interface exposes the exact model identity, and the model has not changed
- **THEN** `openspec-commit` automatically uses that exact model as `assisting_model`
- **AND** it does not ask the user to provide or confirm the model name

#### Scenario: Same session creates another commit
- **WHEN** the root session performs more work after a commit and its exact model remains unchanged
- **THEN** the next `openspec-commit` invocation uses the same current root-session identity automatically
- **AND** it does not require per-commit reconfirmation

#### Scenario: Documentation or commit subagents use other models
- **WHEN** provider-native documentation or commit subagents run with models different from the root session
- **THEN** the root-session model remains the `assisting_model`
- **AND** the subagent models do not create attribution ambiguity

#### Scenario: Other provider environment
- **WHEN** `openspec-commit` reaches the commit step outside Claude Code and Codex
- **THEN** it invokes the portable `git-commit-writer` skill with the exact archive and resolved root-session attribution context
- **AND** it requests the model only when the provider does not expose an exact root-session identity

#### Scenario: Generic family label is available
- **WHEN** only a generic family label such as `GPT-5` or a provider alias such as `sonnet` is available
- **THEN** `openspec-commit` treats the root-session model as unresolved
- **AND** requests an exact value only immediately before commit delegation

#### Scenario: Work came from another session
- **WHEN** the current session is only finishing work implemented in another session
- **THEN** `openspec-commit` does not attribute the work to the current session automatically
- **AND** requests the exact root-session model that governed the implementation

#### Scenario: Model changed after implementation
- **WHEN** the root session switched models during implementation and the attribution is ambiguous
- **THEN** `openspec-commit` does not attribute the work to the latest model automatically
- **AND** requests the exact attribution from the user

#### Scenario: Required commit subagent is missing
- **WHEN** Claude Code or Codex cannot invoke `git-commit-writer-agent`
- **THEN** the workflow stops before commit execution
- **AND** reports the missing provider configuration without invoking `git-commit-writer`

#### Scenario: Commit succeeds
- **WHEN** `git-commit-writer` returns a commit hash
- **THEN** `openspec-commit` reports the exact archive, documentation result, and commit hash

#### Scenario: Documentation runs before attribution is known
- **WHEN** the root-session model is unavailable before documentation handling
- **THEN** `openspec-commit` still completes archive and invokes `doc-updater-agent` or the portable `doc-updater` skill
- **AND** it requests missing attribution only immediately before the commit writer

#### Scenario: Primary and commit-writer models differ
- **WHEN** the root-session model is `gpt-5.6-sol` and the configured commit writer uses another model
- **THEN** `assisting_model=gpt-5.6-sol` is passed only as commit task metadata
- **AND** no subagent spawn model or reasoning effort is derived from that value

### Requirement: Route documentation updates by provider capability
`openspec-commit` SHALL invoke `doc-updater-agent` as a provider-native
subagent when running in Claude Code or Codex. For every other provider, it
SHALL invoke the portable `doc-updater` skill. A Claude Code or Codex execution
MUST stop and report a configuration error when its required subagent is
unavailable and MUST NOT silently fall back to the portable skill.

#### Scenario: Claude Code updates documentation
- **WHEN** `openspec-commit` reaches documentation handling in Claude Code
- **THEN** it invokes the `doc-updater-agent` subagent with the exact change and archive context
- **AND** it does not invoke the portable `doc-updater` skill

#### Scenario: Codex updates documentation
- **WHEN** `openspec-commit` reaches documentation handling in Codex
- **THEN** it invokes the `doc-updater-agent` custom agent with the exact change and archive context
- **AND** it does not invoke the portable `doc-updater` skill

#### Scenario: Another provider updates documentation
- **WHEN** `openspec-commit` reaches documentation handling outside Claude Code and Codex
- **THEN** it invokes the portable `doc-updater` skill available through the shared skills integration

#### Scenario: Required documentation subagent is missing
- **WHEN** Claude Code or Codex cannot invoke `doc-updater-agent`
- **THEN** the workflow stops before documentation editing or commit execution
- **AND** reports the missing provider configuration without invoking `doc-updater`

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

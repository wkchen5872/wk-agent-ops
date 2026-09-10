## MODIFIED Requirements

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

# Spec Delta

## MODIFIED Requirements

### Requirement: Execute git commit step
After archiving the change and updating docs, `openspec-commit` SHALL resolve
the executing `tool_name` and optional root-session `assisting_model` immediately
before delegating final staging and commit execution. It MUST NOT request or
require `assisting_model` before archive or documentation handling.

The coordinator SHALL preserve a user-supplied model name for this work verbatim.
Otherwise, when the current root session exposes a model
name, it MUST use that name automatically and MUST NOT ask for greater precision
or reconfirmation. It SHALL continue using the known current root-session
identity for later commits in the same session while the root model remains
unchanged. Provider-native documentation and commit subagents MUST NOT replace
or make the root-session attribution ambiguous.

Known family versions such as `GPT-5`, `GPT-5.6`, or `GPT-6` SHALL be accepted without
inventing a variant, version, or context size. Attribution records current
collaboration, not original code authorship. Existing changes from another
session MUST NOT cause omission of a known current model. After a root model
switch, use the currently known model rather than stale attribution.
Only if no current root-session model name is known, omit the
model from delegation and report the omitted trailer without blocking commit.
Tool names are not model names. Environment inference, documentation lookup,
session-log parsing, Git history, or commit-only agent identity MUST NOT be used
to guess a model name unavailable in the current context.
In a Pi root session (`PI_CODING_AGENT=true` with no `PI_SUBAGENT_PARENT_SESSION`)
the tool name SHALL be `Pi`, and the value of `PI_MODEL` read at the commit step
SHALL count as the model name available in the current context, recorded as the
model ID without the provider; this exception MUST NOT apply in any other tool
or in a Pi subagent.

In Claude Code and Codex the coordinator SHALL invoke the provider-native
`git-commit-writer-agent` by its exact agent name without supplying a spawn
model or reasoning-effort override; in every other provider it SHALL invoke the
portable `git-commit-writer` skill. It SHALL pass the exact `archive_path`,
`change_id`, `tool_name`, and any known `assisting_model` as task input.
`assisting_model` is Git attribution metadata only and MUST NOT configure a
subagent runtime. If Claude Code or Codex cannot invoke the required subagent,
the workflow MUST stop without falling back to the portable skill.

#### Scenario: Codex or Antigravity environment
- **WHEN** `openspec-commit` reaches the commit step in Codex or Antigravity
- **THEN** Codex automatically records the available current root-session model without asking, including when only committing pre-existing work
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
- **AND** it omits unknown model attribution and reports the omission without requesting user input

#### Scenario: Generic family label is available
- **WHEN** only a known family version such as `GPT-5`, `GPT-5.6`, or `GPT-6` is available
- **THEN** `openspec-commit` passes that name unchanged to the writer
- **AND** it does not invent a variant or request a more precise name

#### Scenario: Work came from another session
- **WHEN** the current session is only finishing work implemented in another session
- **THEN** `openspec-commit` records the available current root-session model as collaboration attribution
- **AND** it does not require identifying the original implementation model

#### Scenario: Model changed after implementation
- **WHEN** the root session switched models and the current model name is available
- **THEN** `openspec-commit` passes the currently known root-session model
- **AND** it does not reuse a stale model name or omit the known current model

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
- **AND** it delegates commit with any known model name, omitting and reporting unknown model attribution

#### Scenario: Primary and commit-writer models differ
- **WHEN** the root-session model is `gpt-5.6-sol` and the configured commit writer uses another model
- **THEN** `assisting_model=gpt-5.6-sol` is passed only as commit task metadata
- **AND** no subagent spawn model or reasoning effort is derived from that value

#### Scenario: Pi root session
- **WHEN** `openspec-commit` reaches the commit step in a Pi root session with `PI_MODEL=gpt-6.2-sol` and no user-supplied model
- **THEN** it invokes the portable `git-commit-writer` skill with `tool_name=Pi` and `assisting_model=gpt-6.2-sol`
- **AND** it does not ask the user for the model

#### Scenario: Pi model variable outside Pi
- **WHEN** `openspec-commit` runs in Codex and the environment contains `PI_MODEL`
- **THEN** it does not use that value as `assisting_model`

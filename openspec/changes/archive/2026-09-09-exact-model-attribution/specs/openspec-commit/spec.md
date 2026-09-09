## MODIFIED Requirements

### Requirement: Execute git commit step
After archiving the change and updating docs, `openspec-commit` SHALL resolve
the executing `tool_name` and exact primary implementation `assisting_model`
immediately before delegating final staging and commit execution. It MUST NOT
require `assisting_model` before archive or documentation handling. The
coordinator SHALL use an exact model identity exposed by the current provider
runtime only when the implementation occurred in that same unambiguous model
context. Codex MAY use exact current-turn runtime metadata. Claude Code MAY use
only an exact model identity exposed through its supported runtime or session
interface. A provider alias, generic model-family label, system-description
family, environment inference, documentation lookup, session-log parser, or
commit-only agent identity MUST NOT be treated as proof of the primary
implementation model. If the exact value is unavailable, or a model switch or
multi-model implementation makes the primary model ambiguous, the coordinator
MUST request it from the user immediately before commit delegation.

In Claude Code and Codex it SHALL invoke the provider-native
`git-commit-writer-agent` by its exact agent name without supplying a spawn
model or reasoning-effort override; in every other provider it SHALL invoke the
portable `git-commit-writer` skill. The coordinator SHALL pass the exact
`archive_path`, `change_id`, `tool_name`, and resolved `assisting_model` as task
input. It MUST treat `assisting_model` only as Git attribution metadata for the
primary implementation model and MUST NOT use it to configure any subagent
runtime. If Claude Code or Codex cannot invoke the required subagent, it MUST
stop and report the missing configuration without falling back to the portable
skill.

#### Scenario: Claude Code environment
- **WHEN** `openspec-commit` reaches the commit step in Claude Code and its supported runtime or session interface exposes the exact model used for the implementation
- **THEN** it uses that exact identity and invokes `git-commit-writer-agent` by exact name
- **AND** it passes the archive and attribution values as task input without a spawn model or effort override
- **AND** it does not invoke the portable `git-commit-writer` skill

#### Scenario: Codex or Antigravity environment
- **WHEN** `openspec-commit` reaches the commit step in Codex or Antigravity
- **THEN** Codex uses exact current-turn metadata only when it unambiguously identifies the implementation model and invokes `git-commit-writer-agent` by exact name without a spawn model or effort override
- **AND** Antigravity invokes the portable `git-commit-writer` skill
- **AND** either route receives the exact archive and resolved attribution context as task input

#### Scenario: Other provider environment
- **WHEN** `openspec-commit` reaches the commit step outside Claude Code and Codex
- **THEN** it invokes the portable `git-commit-writer` skill with `archive_path`, `change_id`, the current tool name, and an exact primary assisting model
- **AND** it requests the model from the user when the provider does not expose an exact identity

#### Scenario: Generic family label is available
- **WHEN** only a generic family label such as `GPT-5` or a provider alias such as `sonnet` is available
- **THEN** `openspec-commit` treats the primary implementation model as unresolved
- **AND** requests an exact value from the user immediately before commit delegation

#### Scenario: Model changed after implementation
- **WHEN** the current runtime model differs from the model that performed the implementation or the primary model is otherwise ambiguous
- **THEN** `openspec-commit` does not attribute the change to the latest model automatically
- **AND** requests the exact primary implementation model from the user

#### Scenario: Documentation runs before attribution is known
- **WHEN** the primary implementation model is unavailable before documentation handling
- **THEN** `openspec-commit` still completes archive and invokes `doc-updater-agent` or the portable `doc-updater` skill
- **AND** it requests missing attribution only immediately before the commit writer

#### Scenario: Required commit subagent is missing
- **WHEN** Claude Code or Codex cannot invoke `git-commit-writer-agent`
- **THEN** the workflow stops before commit execution
- **AND** reports the missing provider configuration without invoking `git-commit-writer`

#### Scenario: Commit succeeds
- **WHEN** `git-commit-writer` returns a commit hash
- **THEN** `openspec-commit` reports the exact archive, documentation result, and commit hash

#### Scenario: Primary and commit-writer models differ
- **WHEN** the primary implementation model is `gpt-5.6-sol` and the configured commit writer uses another model
- **THEN** `assisting_model=gpt-5.6-sol` is passed only as commit task metadata
- **AND** no subagent spawn model or reasoning effort is derived from that value

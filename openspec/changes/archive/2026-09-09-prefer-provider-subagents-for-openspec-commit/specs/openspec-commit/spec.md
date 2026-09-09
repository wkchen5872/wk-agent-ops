## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Execute git commit step
After archiving the change and updating docs, `openspec-commit` SHALL delegate
final staging and commit execution rather than performing the commit inline.
In Claude Code and Codex it SHALL invoke the provider-native
`git-commit-writer-agent`; in every other provider it SHALL invoke the portable
`git-commit-writer` skill. The coordinator SHALL pass the exact `archive_path`,
`change_id`, executing `tool_name`, and primary `assisting_model` through either
route. It MUST pass the model responsible for the implementation, not substitute
the model of a commit-only subagent. If Claude Code or Codex cannot invoke the
required subagent, it MUST stop and report the missing configuration without
falling back to the portable skill.

#### Scenario: Claude Code environment
- **WHEN** `openspec-commit` reaches the commit step in Claude Code
- **THEN** it invokes `git-commit-writer-agent` with `archive_path`, `change_id`, `tool_name=Claude Code`, and the primary assisting model
- **AND** it does not invoke the portable `git-commit-writer` skill

#### Scenario: Codex environment
- **WHEN** `openspec-commit` reaches the commit step in Codex
- **THEN** it invokes `git-commit-writer-agent` with `archive_path`, `change_id`, `tool_name=Codex`, and the primary assisting model
- **AND** it does not invoke the portable `git-commit-writer` skill

#### Scenario: Codex or Antigravity environment
- **WHEN** `openspec-commit` reaches the commit step in Codex or Antigravity
- **THEN** Codex invokes the provider-native `git-commit-writer-agent`
- **AND** Antigravity invokes the portable `git-commit-writer` skill
- **AND** either route receives the exact archive and attribution context

#### Scenario: Other provider environment
- **WHEN** `openspec-commit` reaches the commit step outside Claude Code and Codex
- **THEN** it invokes the portable `git-commit-writer` skill with `archive_path`, `change_id`, the current tool name, and the primary assisting model

#### Scenario: Required commit subagent is missing
- **WHEN** Claude Code or Codex cannot invoke `git-commit-writer-agent`
- **THEN** the workflow stops before commit execution
- **AND** reports the missing provider configuration without invoking `git-commit-writer`

#### Scenario: Commit succeeds
- **WHEN** the selected commit writer returns a commit hash
- **THEN** `openspec-commit` reports the exact archive, documentation result, and commit hash

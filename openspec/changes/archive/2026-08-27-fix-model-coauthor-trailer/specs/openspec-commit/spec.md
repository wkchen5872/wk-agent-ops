## MODIFIED Requirements

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

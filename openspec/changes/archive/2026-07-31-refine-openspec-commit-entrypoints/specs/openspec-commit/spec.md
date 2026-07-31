## ADDED Requirements

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

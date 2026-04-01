## ADDED Requirements

### Requirement: Launch persistent PM Master Session
The system SHALL provide a `pm-start` command that creates or resumes a named PM Claude session in the repository root directory.

#### Scenario: First-time launch
- **WHEN** user runs `pm-start` in any directory within the repo
- **THEN** system SHALL resolve the git repo root
- **AND** execute `claude --name "PM: <repo-basename>" "/opsx:new"` from the repo root
- **AND** the session name SHALL be deterministic: `"PM: <basename of repo root>"`

#### Scenario: Subsequent launch (session already exists)
- **WHEN** user runs `pm-start` again after a previous session
- **THEN** Claude's `--name` flag SHALL resume the existing named session
- **AND** the `/opsx:new` argument is passed but the session context is already loaded

#### Scenario: Running outside a git repo
- **WHEN** user runs `pm-start` outside a git repository
- **THEN** system SHALL print an error message
- **AND** exit with code 1

## MODIFIED Requirements

### Requirement: Resume agent session by feature name
The system SHALL provide `wt-resume <change-id> --agent <provider> [--session <id-or-name>] [--path <worktree-path>]` solely for resuming a session in the selected Provider. It SHALL use the same safe path validation as `wt-work`, SHALL NOT switch Provider identity, and SHALL NOT inject a new OpenSpec apply action.

#### Scenario: Claude interactive resume
- **WHEN** the user runs `wt-resume feature123 --agent claude` without `--session`
- **THEN** the system resolves the Worktree and opens Claude's native resume picker there

#### Scenario: Claude explicit resume
- **WHEN** the user supplies a Claude session ID or name
- **THEN** the system forwards it to Claude's native resume option from the resolved Worktree

#### Scenario: Codex interactive resume
- **WHEN** the user runs `wt-resume feature123 --agent codex` without `--session`
- **THEN** the system opens Codex's native resume picker from the resolved Worktree

#### Scenario: Codex explicit resume
- **WHEN** the user supplies a Codex session ID or name
- **THEN** the system invokes Codex's native resume command for that session from the resolved Worktree

#### Scenario: Antigravity resume
- **WHEN** the user selects Antigravity with an explicit conversation ID
- **THEN** the system invokes `agy` with that conversation in the resolved Worktree

#### Scenario: Antigravity alias resume
- **WHEN** the user selects `--agent agy`
- **THEN** the system uses the same `agy` resume behavior as `--agent antigravity`

#### Scenario: Copilot resume
- **WHEN** the user selects Copilot
- **THEN** the system preserves its supported interactive or explicit resume behavior in the resolved Worktree

#### Scenario: Removed Gemini value
- **WHEN** the user selects `gemini`
- **THEN** the system exits non-zero and lists the supported Provider values

#### Scenario: Missing change ID
- **WHEN** the user runs `wt-resume` without a change ID
- **THEN** the system prints usage guidance and exits non-zero

## ADDED Requirements

### Requirement: wt-work command replaces wt-new
The system SHALL provide a `wt-work <feature-name>` command that creates a new git worktree (if absent) or resumes an existing worktree (if present), and always passes `/opsx:apply <name>` as the initial prompt to the AI CLI agent.

#### Scenario: New worktree, no session specified
- **WHEN** user runs `wt-work feature123`
- **AND** `$REPO/.worktrees/feature123` does NOT exist
- **THEN** system SHALL create a `feature/feature123` branch and worktree at `$REPO/.worktrees/feature123`
- **AND** copy `.claude/settings.local.json` and `.env` to the worktree (if they exist)
- **AND** launch the agent with a new named session `"RD: feature123"` and prompt `/opsx:apply feature123`

#### Scenario: New worktree, with session specified
- **WHEN** user runs `wt-work feature123 --session a469f20a-a791-4c6f-af7a-5a0e599527f4`
- **AND** `$REPO/.worktrees/feature123` does NOT exist
- **THEN** system SHALL create the worktree as normal
- **AND** launch the agent with `--resume <session>` and prompt `/opsx:apply feature123`

#### Scenario: Existing worktree, no session specified
- **WHEN** user runs `wt-work feature123`
- **AND** `$REPO/.worktrees/feature123` already exists
- **THEN** system SHALL NOT create a new worktree or branch
- **AND** change directory to the worktree
- **AND** launch the agent resuming by session name `"RD: feature123"` with prompt `/opsx:apply feature123`

#### Scenario: Existing worktree, with session specified
- **WHEN** user runs `wt-work feature123 --session <session>`
- **AND** `$REPO/.worktrees/feature123` already exists
- **THEN** system SHALL change directory to the worktree
- **AND** launch the agent with `--resume <session>` and prompt `/opsx:apply feature123`

#### Scenario: Missing feature name argument
- **WHEN** user runs `wt-work` with no arguments
- **THEN** system SHALL print usage error and exit with code 1

#### Scenario: Branch exists but worktree directory missing
- **WHEN** user runs `wt-work feature123`
- **AND** branch `feature/feature123` exists
- **AND** `$REPO/.worktrees/feature123` does NOT exist
- **THEN** system SHALL print an error and exit with code 1

### Requirement: wt-work supports --session parameter
The system SHALL accept an optional `--session` / `-s` parameter that passes the session identifier directly to the AI CLI tool's resume mechanism, without format validation.

#### Scenario: Session forwarded to Claude
- **WHEN** user runs `wt-work feature123 --session my-session-name`
- **AND** agent is `claude`
- **THEN** system SHALL execute `claude --resume my-session-name "/opsx:apply feature123" --enable-auto-mode`

#### Scenario: Session forwarded to Copilot
- **WHEN** user runs `wt-work feature123 --session 6d4b8b78-14d6-4cbd-9658-3bb5d698d288`
- **AND** agent is `copilot`
- **THEN** system SHALL execute `copilot --resume=6d4b8b78-14d6-4cbd-9658-3bb5d698d288 --allow-all -i "/openspec-apply-change feature123"`

#### Scenario: Session forwarded to Gemini
- **WHEN** user runs `wt-work feature123 --session 3`
- **AND** agent is `gemini`
- **THEN** system SHALL execute `gemini --resume 3 -p "/opsx:apply feature123"`

### Requirement: wt-work supports --agent gemini
The system SHALL accept `gemini` as a valid value for the `--agent` parameter and launch Gemini CLI accordingly.

#### Scenario: New session with Gemini
- **WHEN** user runs `wt-work feature123 --agent gemini`
- **AND** worktree does NOT exist
- **THEN** system SHALL create the worktree
- **AND** execute `gemini -p "/opsx:apply feature123"`

#### Scenario: Resume session with Gemini, no session specified
- **WHEN** user runs `wt-work feature123 --agent gemini`
- **AND** worktree exists
- **THEN** system SHALL execute `gemini --resume -p "/opsx:apply feature123"`

#### Scenario: Invalid agent value
- **WHEN** user runs `wt-work feature123 --agent invalid`
- **THEN** system SHALL print an error listing valid agents and exit with code 1

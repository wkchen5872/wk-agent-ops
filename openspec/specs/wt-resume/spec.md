# Spec: wt-resume

## Purpose

Provides a `wt-resume <feature-name>` command that resumes an AI CLI agent session regardless of whether the local worktree directory still exists. Supports Claude, Copilot, and Gemini agents with optional session targeting via `--session`.

## Requirements

### Requirement: Resume agent session by feature name
The system SHALL provide a `wt-resume <feature-name>` command that resumes an AI CLI agent session. When `--session` is not specified, Claude and Copilot SHALL display an interactive selection list; Gemini SHALL auto-resume the latest session. When `--session` is specified, its value SHALL be forwarded directly to the tool without format validation.

#### Scenario: Resume with worktree present, no session (Claude)
- **WHEN** user runs `wt-resume feature123`
- **AND** agent is `claude`
- **AND** `$REPO/.worktrees/feature123` exists
- **THEN** system SHALL change directory to the worktree
- **AND** execute `claude --resume` (displays interactive session list)

#### Scenario: Resume without worktree, no session (Claude)
- **WHEN** user runs `wt-resume feature123`
- **AND** agent is `claude`
- **AND** `$REPO/.worktrees/feature123` does NOT exist
- **THEN** system SHALL execute `claude --resume` from the current directory

#### Scenario: Resume with session specified (Claude)
- **WHEN** user runs `wt-resume feature123 --session a469f20a-a791-4c6f-af7a-5a0e599527f4`
- **AND** agent is `claude`
- **THEN** system SHALL execute `claude --resume a469f20a-a791-4c6f-af7a-5a0e599527f4`

#### Scenario: Resume with session specified (Copilot)
- **WHEN** user runs `wt-resume feature123 --session 6d4b8b78-14d6-4cbd-9658-3bb5d698d288`
- **AND** agent is `copilot`
- **THEN** system SHALL execute `copilot --resume=6d4b8b78-14d6-4cbd-9658-3bb5d698d288 --allow-all`

#### Scenario: Resume without session (Copilot)
- **WHEN** user runs `wt-resume feature123 --agent copilot`
- **AND** no --session provided
- **THEN** system SHALL execute `copilot --resume --allow-all` (displays interactive session list)

#### Scenario: Resume without session (Gemini, auto latest)
- **WHEN** user runs `wt-resume feature123 --agent gemini`
- **AND** no --session provided
- **THEN** system SHALL execute `gemini --resume` (auto-resumes latest chat)

#### Scenario: Resume with session specified (Gemini)
- **WHEN** user runs `wt-resume feature123 --session 3 --agent gemini`
- **THEN** system SHALL execute `gemini --resume 3`

#### Scenario: Missing feature name argument
- **WHEN** user runs `wt-resume` with no arguments
- **THEN** system SHALL print a usage error and exit with code 1

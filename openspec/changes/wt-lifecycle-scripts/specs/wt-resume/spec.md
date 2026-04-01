## ADDED Requirements

### Requirement: Resume agent session by feature name
The system SHALL provide a `wt-resume <feature-name>` command that resumes a Claude agent session regardless of whether the local worktree directory still exists.

#### Scenario: Resume with worktree present
- **WHEN** user runs `wt-resume etf-nav-fetcher`
- **AND** `$REPO/.worktrees/etf-nav-fetcher` directory exists
- **THEN** system SHALL print a "Resuming in worktree…" message
- **AND** change directory to the worktree
- **AND** execute `claude --resume "RD: etf-nav-fetcher"`

#### Scenario: Resume without worktree (after wt-done)
- **WHEN** user runs `wt-resume feature123`
- **AND** `$REPO/.worktrees/feature123` directory does NOT exist
- **THEN** system SHALL print a "Worktree not found, resuming by session name…" message
- **AND** execute `claude --resume "RD: feature123"` from current directory

#### Scenario: Missing feature name argument
- **WHEN** user runs `wt-resume` with no arguments
- **THEN** system SHALL print a usage error and exit with code 1

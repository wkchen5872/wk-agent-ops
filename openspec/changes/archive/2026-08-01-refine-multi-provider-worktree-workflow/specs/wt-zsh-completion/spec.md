## MODIFIED Requirements

### Requirement: Tab-complete feature names for wt-* commands
The completion script SHALL derive change suggestions from `.worktrees/`, local `feature/*` branches, and registered Worktrees, de-duplicate the change IDs, and remain silent when no candidate exists.

#### Scenario: Complete a Project-managed change
- **WHEN** the user requests completion for `wt-work`, `wt-done`, or `wt-resume`
- **AND** `.worktrees/feature123` or local `feature/feature123` exists
- **THEN** `feature123` is suggested once

#### Scenario: Complete a Provider-native named-branch Worktree
- **WHEN** a registered external Worktree checks out `feature/feature123`
- **THEN** `feature123` is included without exposing unrelated branches

#### Scenario: No candidate
- **WHEN** no matching directory, feature branch, or registered Worktree exists
- **THEN** completion returns no suggestions and no error

## ADDED Requirements

### Requirement: Tab-complete supported Provider values
The system SHALL complete `--agent`／`-a` for `wt-work`, `wt-resume`, and `pm-start` with `claude`, `codex`, `antigravity`, `agy`, and `copilot`.

#### Scenario: Complete Provider values
- **WHEN** the user requests completion after `--agent`
- **THEN** the four Providers plus the `agy` alias are offered
- **AND** `gemini` is absent

### Requirement: Tab-complete Worktree path option
The system SHALL recognize `--path` for `wt-work` and `wt-resume` and complete paths from `git worktree list --porcelain`.

#### Scenario: Complete registered Worktree paths
- **WHEN** the user requests completion after `wt-work feature123 --path`
- **THEN** registered Worktree paths are offered

## REMOVED Requirements

### Requirement: Tab-complete --agent flag with gemini option
**Reason**: Gemini CLI is removed from the supported workflow Provider matrix.

**Migration**: Complete and use `antigravity` or `codex`; the remaining Claude and Copilot values are unchanged.

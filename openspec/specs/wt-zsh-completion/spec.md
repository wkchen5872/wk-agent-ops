# Spec: wt-zsh-completion

## Purpose

Provides an installed zsh completion script (`_wt`) for the workflow command matrix, deriving change IDs from Git's Worktree registry and completing the current Providers plus `--session`, `--path`, and `--base` options.

## Requirements

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

### Requirement: Tab-complete --session flag
The system SHALL recognize `--session` / `-s` as a valid flag for `wt-work` and `wt-resume`, providing a hint that a session ID or name is expected.

#### Scenario: Tab-complete --session for wt-work
- **WHEN** user types `wt-work feature123 --session <TAB>` in zsh
- **THEN** completion SHALL provide a description hint `"session ID or name"`

#### Scenario: Tab-complete --session for wt-resume
- **WHEN** user types `wt-resume feature123 -s <TAB>` in zsh
- **THEN** completion SHALL provide a description hint `"session ID or name"`

### Requirement: Completion script installed by install.sh
The `install.sh` script SHALL copy `_wt` to a directory on `$fpath` and run `hash -r` after installation. The script SHALL also install `wt-work` (replacing `wt-new`) and automatically remove any stale `wt-new` binary found in the same install directory.

#### Scenario: Install completion
- **WHEN** user runs `install.sh`
- **THEN** `_wt` SHALL be copied to `~/.local/share/zsh/site-functions/` (or equivalent fpath directory)
- **AND** `install.sh` SHALL print a reminder to reload the shell or run `source ~/.zshrc`

#### Scenario: Stale wt-new binary removed on install
- **WHEN** user runs `install.sh`
- **AND** `wt-new` exists in the install target directory (e.g., `~/.local/bin/wt-new`)
- **THEN** `install.sh` SHALL delete `wt-new` from that directory
- **AND** print `"✓ Removed stale binary: wt-new"`

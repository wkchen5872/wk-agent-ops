## ADDED Requirements

### Requirement: Tab-complete feature names for wt-* commands
The system SHALL provide a zsh completion script (`_wt`) that completes the first argument of `wt-new`, `wt-done`, and `wt-resume` with existing feature names derived from the `.worktrees/` directory.

#### Scenario: Tab-complete on wt-new
- **WHEN** user types `wt-new <TAB>` in zsh
- **THEN** completion SHALL list all directory names under `$REPO/.worktrees/`

#### Scenario: Tab-complete on wt-done
- **WHEN** user types `wt-done <TAB>` in zsh
- **THEN** completion SHALL list all directory names under `$REPO/.worktrees/`

#### Scenario: Tab-complete on wt-resume
- **WHEN** user types `wt-resume <TAB>` in zsh
- **THEN** completion SHALL list all directory names under `$REPO/.worktrees/`

#### Scenario: No worktrees exist
- **WHEN** `.worktrees/` directory is empty or does not exist
- **THEN** completion SHALL return no suggestions (no error)

### Requirement: Completion script installed by install.sh
The `install.sh` script SHALL copy `_wt` to a directory on `$fpath` and run `hash -r` after installation.

#### Scenario: Install completion
- **WHEN** user runs `install.sh`
- **THEN** `_wt` SHALL be copied to `~/.local/share/zsh/site-functions/` (or equivalent fpath directory)
- **AND** `install.sh` SHALL print a reminder to reload the shell or run `source ~/.zshrc`

## MODIFIED Requirements

### Requirement: Tab-complete feature names for wt-* commands
The system SHALL provide a zsh completion script (`_wt`) that completes the first argument of `wt-work`, `wt-done`, and `wt-resume` with existing feature names derived from the `.worktrees/` directory. The command `wt-new` SHALL be removed from completion (replaced by `wt-work`).

#### Scenario: Tab-complete on wt-work
- **WHEN** user types `wt-work <TAB>` in zsh
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

### Requirement: Tab-complete --agent flag with gemini option
The system SHALL complete `--agent` / `-a` values for `wt-work` and `wt-resume` with the list: `claude`, `copilot`, `gemini`, `codex`.

#### Scenario: Tab-complete agent values for wt-work
- **WHEN** user types `wt-work feature123 --agent <TAB>` in zsh
- **THEN** completion SHALL list `claude copilot gemini codex`

#### Scenario: Tab-complete agent values for wt-resume
- **WHEN** user types `wt-resume feature123 -a <TAB>` in zsh
- **THEN** completion SHALL list `claude copilot gemini codex`

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

## MODIFIED Requirements

### Requirement: A Pi role starts from settings written into its worktree
Before a Pi role session opens, its worktree SHALL receive `.pi/settings.json` setting Pi's default provider, model, and thinking level to the template's `provider`, `model`, and `effort`, which SHALL also be passed to the role's host. The file SHALL be ignored through the repository's local exclude file and MUST NOT make the worktree unclean. An existing file with identical content SHALL be reused; a different or tracked one SHALL be refused, not overwritten.

#### Scenario: Xirp ignores Pi launch options
- **WHEN** Pi's saved default is `openai-codex/gpt-6-sol` at `medium`, Xirp drops the Pi launch options, and the implement template declares `openai-codex`, `gpt-5.6-luna`, `low`
- **THEN** the implementer session runs `openai-codex/gpt-5.6-luna` at `low`

#### Scenario: Settings file keeps the worktree clean
- **WHEN** the settings file has been written into the implementer worktree
- **THEN** `git status --porcelain` in that worktree is empty and the file is not tracked

#### Scenario: Repository has its own Pi settings
- **WHEN** the role worktree already contains a different `.pi/settings.json`
- **THEN** the role is refused with a message naming the file, the file is unchanged, and no session opens

#### Scenario: Pi role on herdr
- **WHEN** the review role uses `host: herdr`, `harness: pi`, and declares `anthropic`, `claude-haiku-5-5`, `low`
- **THEN** the reviewer's worktree has the settings file and the herdr tab runs Pi on `anthropic/claude-haiku-5-5` at `low`

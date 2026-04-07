## ADDED Requirements

### Requirement: Archive event detection
The entropy-counter hook SHALL detect when an OpenSpec change is archived via the Bash tool.

#### Scenario: Archive command detected in Claude Code
- **WHEN** Claude Code's PostToolUse event fires for the Bash tool
- **AND** the `tool_input.command` field contains `openspec archive`
- **THEN** the hook proceeds to check the archive count

#### Scenario: Non-archive command ignored
- **WHEN** Claude Code's PostToolUse event fires for the Bash tool
- **AND** `tool_input.command` does not contain `openspec archive`
- **THEN** the hook exits 0 immediately without any action

#### Scenario: Hook never blocks AI CLI
- **WHEN** any error occurs inside the hook (missing jq, missing state file, unexpected input)
- **THEN** the hook exits 0 and the AI CLI session continues unaffected

### Requirement: Threshold-based notification
The entropy-counter hook SHALL notify the user when the archive count delta reaches the configured threshold.

#### Scenario: Threshold reached
- **WHEN** `(current_archive_count - watermark) >= ENTROPY_THRESHOLD`
- **THEN** a visible banner is printed to the terminal
- **AND** the banner includes current count, watermark, and threshold
- **AND** the banner instructs the user to run `/entropy-check`

#### Scenario: Threshold not reached
- **WHEN** `(current_archive_count - watermark) < ENTROPY_THRESHOLD`
- **THEN** the hook exits 0 silently without any output

#### Scenario: Custom threshold
- **WHEN** `ENTROPY_THRESHOLD` environment variable is set to an integer N
- **THEN** the hook uses N as the threshold instead of the default (5)

#### Scenario: First run (no watermark file)
- **WHEN** `openspec/.entropy-state` does not exist
- **THEN** watermark is treated as 0
- **AND** threshold check proceeds normally

### Requirement: Telegram notification (optional)
The entropy-counter hook SHALL optionally send a Telegram notification when threshold is reached.

#### Scenario: Telegram notification sent
- **WHEN** threshold is reached
- **AND** `~/.config/ai-notify/hooks/telegram-notify.sh` exists
- **AND** Telegram is configured and enabled
- **THEN** hook calls telegram-notify.sh with a notification event and message "Entropy check due: N changes since last review"

#### Scenario: Telegram not configured
- **WHEN** threshold is reached
- **AND** `~/.config/ai-notify/hooks/telegram-notify.sh` does not exist
- **THEN** only the terminal banner is shown, no error is produced

### Requirement: Installation
The entropy-counter hook SHALL be installable via a dedicated install script.

#### Scenario: Hook registered in Claude Code
- **WHEN** `scripts/workflow/entropy-counter/install.sh` is executed
- **THEN** the hook entry is added to `~/.claude/settings.json` under `hooks.PostToolUse`
- **AND** the installation is idempotent (running install.sh twice does not duplicate the entry)

#### Scenario: Hook registered in Gemini CLI
- **WHEN** `scripts/workflow/entropy-counter/install.sh` is executed
- **AND** `~/.gemini/settings.json` exists
- **THEN** the hook entry is added for Gemini CLI as well

#### Scenario: Hook uninstalled
- **WHEN** `scripts/workflow/entropy-counter/uninstall.sh` is executed
- **THEN** the hook entry is removed from `~/.claude/settings.json`
- **AND** the uninstall is idempotent (running uninstall.sh twice does not error)

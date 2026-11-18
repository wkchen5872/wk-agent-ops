# Spec Delta

## MODIFIED Requirements

### Requirement: 共用基礎庫 — registry.sh (idempotent hook 註冊)
`scripts/notify/lib/registry.sh` SHALL register notification hooks
idempotently for Claude Code and detected Codex and Antigravity installations,
and SHALL install the notification-owned Pi extension when Pi is detected.
It SHALL NOT register new Gemini CLI hooks. Setup, repair, and uninstall flows
SHALL remove only notification-owned legacy Gemini entries from
`~/.gemini/settings.json`. Copilot registration SHALL remain repository-local
and opt-in.

#### Scenario: 首次註冊 Claude Code hook
- **WHEN** registration runs and the owned Claude hooks are absent
- **THEN** one `Stop` and one `Notification` command are added without changing unrelated settings

#### Scenario: 重複註冊 Claude Code hook
- **WHEN** registration runs twice for the same deployed hook
- **THEN** the owned Claude entries are not duplicated

#### Scenario: Gemini CLI 不再註冊
- **WHEN** setup runs on a machine containing the Gemini CLI binary or legacy settings file
- **THEN** no Gemini `AfterAgent` or `Notification` hook is added

#### Scenario: 清除舊 Gemini hook
- **WHEN** setup, repair, or uninstall finds notification-owned commands in legacy `~/.gemini/settings.json`
- **THEN** those owned commands are removed while unrelated Gemini settings and hooks remain unchanged

#### Scenario: unregister_hook 清除全域 hooks
- **WHEN** global notification hooks are unregistered
- **THEN** owned Claude, Codex, Antigravity, and legacy Gemini entries and the owned Pi extension file are removed without changing unrelated entries

#### Scenario: 首次註冊 Copilot CLI hook
- **WHEN** `register_hook_copilot <hook_path>` runs and `.github/hooks/hooks.json` does not exist
- **THEN** a version 1 file is created with one `sessionEnd` and one `userPromptSubmitted` command

#### Scenario: 重複註冊 Copilot CLI hook
- **WHEN** Copilot registration runs twice
- **THEN** neither owned command is duplicated

#### Scenario: unregister_hook_copilot 清除
- **WHEN** Copilot hooks are unregistered
- **THEN** owned commands are removed while unrelated repository hooks remain unchanged

#### Scenario: 偵測到 Pi 時安裝 extension
- **WHEN** registration runs on a machine where the `pi` command or Pi agent directory exists
- **THEN** the notification-owned Pi extension is installed once in Pi's global extension directory

### Requirement: registry.sh 在 hook 指令中帶入 tool name
Global and repository-local registrations SHALL pass the canonical host name as
the hook's second argument so the shared hook does not infer host identity from
legacy environment variables.

#### Scenario: Claude registration includes tool name
- **WHEN** the Claude hook is registered
- **THEN** its command invokes the deployed hook with `"Claude Code"` as the second argument

#### Scenario: Codex and Antigravity registrations include tool names
- **WHEN** Codex or Antigravity hooks are registered
- **THEN** their commands invoke the deployed hook with `"Codex"` or `"Antigravity CLI"` respectively

#### Scenario: Copilot registration includes tool name
- **WHEN** Copilot hooks are registered
- **THEN** their commands invoke the deployed hook with `"Copilot CLI"` as the second argument

#### Scenario: Pi extension uses the Pi tool name
- **WHEN** the Pi extension sends an event to the deployed hook
- **THEN** it invokes the hook with `"Pi"` as the second argument

### Requirement: Cross-provider lifecycle preservation
Setup, repair, status, and uninstall SHALL manage only notification-owned
entries for Claude Code, Codex, Antigravity, Copilot, Pi, and legacy Gemini
cleanup. Active provider status SHALL cover Claude Code, Codex, Antigravity
completion, Antigravity approval, Copilot, and Pi without listing Gemini CLI as a
supported host or exposing credentials.

#### Scenario: Provider-aware setup
- **WHEN** setup detects Codex or Antigravity
- **THEN** it registers their completion hooks and safely attempts the Antigravity approval observer

#### Scenario: Status reports supported coverage
- **WHEN** notification status is requested
- **THEN** it reports Claude Code, Codex, Antigravity completion, Antigravity approval, Copilot, and Pi coverage without a Gemini support row

#### Scenario: Status reports approval conflict
- **WHEN** a different Antigravity status-line command prevents approval observation
- **THEN** status distinguishes unavailable approval observation from an installed observer

#### Scenario: Uninstall preserves unrelated settings
- **WHEN** notification uninstall runs
- **THEN** owned commands and state are removed while unrelated provider settings remain unchanged

#### Scenario: Status reports a Pi conflict
- **WHEN** a Pi extension file of the same name without the ownership marker prevents installation
- **THEN** status reports Pi notifications as unavailable because of the existing file

### Requirement: Notification privacy and bounded failure
Codex, Antigravity, and Pi notifications SHALL include only the CLI name, project,
session label, event type, and a generic tool or termination label. They SHALL
exclude raw commands, prompts, transcripts, tool arguments, and raw error text.
Telegram delivery failure SHALL not block the invoking CLI beyond the configured
short timeout.

#### Scenario: Codex approval payload contains a command
- **WHEN** a Codex approval payload includes a raw command or other tool arguments
- **THEN** the Telegram message identifies the requesting tool but does not contain those arguments

#### Scenario: Telegram is unavailable
- **WHEN** Telegram delivery times out or fails
- **THEN** the hook returns the provider's neutral control response and the AI CLI continues its native flow

#### Scenario: Pi failure carries an error message
- **WHEN** a Pi run settles with an error whose message contains a file path and an API response
- **THEN** the Telegram message reports a failure for `Pi` without that text

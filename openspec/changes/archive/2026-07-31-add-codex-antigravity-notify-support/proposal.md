## Why

The Telegram notification hook currently registers only Claude Code, Gemini CLI,
and a partial Copilot CLI integration. Codex receives no external notification,
while Antigravity is incorrectly treated as Gemini CLI even though it uses
different hook and state configuration files.

## What Changes

- Register Codex `Stop` and `PermissionRequest` hooks without changing Codex's
  stop or approval decisions.
- Register Antigravity `Stop` hooks for completion notifications and distinguish
  idle completion from error or intermediate termination.
- Add an opt-in Antigravity status observer that notifies only when
  `tool_confirmation_pending` transitions to true, preserves an existing status
  line command, and deduplicates repeated state updates.
- Normalize Codex and Antigravity payloads in the existing Telegram hook while
  avoiding disclosure of raw prompts, commands, transcripts, or tool input.
- Extend setup, update, status, and uninstall flows with idempotent
  Codex/Antigravity registration.
- Restore the already-specified Copilot `userPromptSubmitted` registration as a
  separate regression fix.
- Add replayable dry-run and isolated registry tests for the new events,
  conflict handling, failure behavior, and uninstall preservation.
- Update notification architecture and Telegram setup documentation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `telegram-notify-hook`: Extend native hook registration, event normalization,
  setup lifecycle, privacy guarantees, and non-blocking behavior to Codex and
  Antigravity; restore the missing Copilot action-required registration.
- `notify-test-harness`: Cover Codex and Antigravity completion/approval
  behavior, idempotent registration, conflict handling, and preserved native
  CLI decisions without live Telegram access.

## Impact

- Affected code: `scripts/notify/lib/registry.sh`,
  `scripts/notify/telegram/hook.sh`, notification setup/update/uninstall/status
  scripts, and their test harness.
- Affected user configuration: `~/.codex/hooks.json`,
  `~/.gemini/config/hooks.json`, and optionally
  `~/.gemini/antigravity-cli/settings.json`.
- Affected docs: `docs/notify/architecture.md` and
  `docs/notify/telegram.md`.
- No new runtime dependency or generic event-bus abstraction is introduced;
  existing Bash and `jq` patterns remain the implementation boundary.

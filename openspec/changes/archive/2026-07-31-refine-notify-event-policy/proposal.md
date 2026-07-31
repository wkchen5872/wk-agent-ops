## Why

The notification hook still models policy around legacy provider event names,
which makes `notify_only` ambiguous and produces inconsistent filtering across
completion, approval, and failure events. Gemini CLI consumer access has moved
to Antigravity CLI, so retaining active Gemini notification registration adds
maintenance cost outside this repository's intended support matrix.

## What Changes

- **BREAKING** Remove active Gemini CLI notification registration, detection,
  event handling, status reporting, tests, and documentation while cleaning up
  notification-owned legacy Gemini hook entries during migration.
- Replace the canonical `notify_only` value with `attention_required`; continue
  accepting the legacy value as an alias so existing installations do not fall
  back to noisy completion notifications.
- Normalize provider events into `completion`, `action_required`, and `failure`
  before applying the notification policy.
- Define `all` as sending all three categories and `attention_required` as
  sending action-required and failure notifications while suppressing only
  successful completion.
- Remove the separate install/update preference for Antigravity approval
  notifications. When Antigravity is detected, setup SHALL automatically
  register the approval observer when the custom status-line slot is available,
  preserve a conflicting command, and report that approval observation is
  unavailable.
- Keep Claude Code, Codex, Antigravity CLI, and Copilot CLI as the supported
  notification hosts, preserving each host's native control response and
  notification privacy guarantees.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `telegram-notify-hook`: Change the supported host matrix, notification-level
  vocabulary, event classification/filtering, Antigravity approval setup, and
  legacy migration behavior.
- `notify-test-harness`: Replace Gemini coverage and raw-event level tests with
  semantic policy, legacy-value migration, Antigravity approval, failure, and
  cleanup coverage.

## Impact

- Affected code: `scripts/notify/lib/registry.sh` and
  `scripts/notify/telegram/{hook,install,update,uninstall,test}.sh`.
- Affected user configuration: `NOTIFY_LEVEL` in
  `~/.config/ai-notify/config`, notification-owned entries in legacy
  `~/.gemini/settings.json`, and Antigravity's
  `~/.gemini/antigravity-cli/settings.json`.
- Affected specifications and documentation:
  `telegram-notify-hook`, `notify-test-harness`, `README.md`,
  `scripts/notify/README.md`, and `docs/notify/`.
- No new runtime dependency or notification-policy framework is introduced.

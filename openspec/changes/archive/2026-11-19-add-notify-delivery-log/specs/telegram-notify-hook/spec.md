# Spec Delta

## ADDED Requirements

### Requirement: Telegram deliveries can be logged without message content
When `NOTIFY_DELIVERY_LOG=true`, the hook SHALL append one line to `~/.config/ai-notify/state/deliveries.log` after each Telegram call: time, event key, template, whether Telegram accepted it, and `message_id`, never the message text, token, or chat ID. Nothing SHALL be logged when the setting is absent or false, in dry-run, or when no call is made. A logging failure SHALL not affect delivery. The log SHALL keep at most its newest 500 lines.

#### Scenario: Accepted delivery is logged
- **WHEN** logging is on and Telegram accepts a completion notification with `message_id` 42
- **THEN** the log gains one line with the completion event key, its template, `ok=true` and `message_id=42`, and without the message text or token

#### Scenario: Rejected or failed delivery is logged
- **WHEN** logging is on and Telegram answers `ok:false`, or curl fails without an answer
- **THEN** the log gains one line with `ok=false` and `message_id=-`

#### Scenario: Logging is off
- **WHEN** the setting is absent and a notification is delivered
- **THEN** no delivery log file is created

#### Scenario: Log stays bounded
- **WHEN** logging is on and the log already holds 500 lines
- **THEN** after the next delivery it holds the newest 500 lines, ending with the new one

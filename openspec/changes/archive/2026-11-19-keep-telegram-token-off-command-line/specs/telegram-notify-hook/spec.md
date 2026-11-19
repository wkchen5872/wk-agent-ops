# Spec Delta

## ADDED Requirements

### Requirement: Telegram credentials stay off process command lines
Every Telegram Bot API call made by the notification hook or the setup wizard SHALL pass the bot token and the chat ID to curl through its standard input, never as command-line arguments, so other users cannot read them from the process list. The request sent to Telegram SHALL stay the same. A token or chat ID with characters outside the Telegram formats SHALL not be sent.

#### Scenario: Notification is delivered
- **WHEN** the hook delivers a completion notification with token `123:abcDEF` and chat ID `12345`
- **THEN** curl's arguments contain neither value, and the configuration curl reads from standard input contains the `sendMessage` URL with the token and `chat_id=12345`

#### Scenario: Setup wizard checks the token
- **WHEN** the setup wizard validates a token, looks up the chat ID, and sends its test message
- **THEN** none of those curl calls has the token or chat ID in its arguments

#### Scenario: Token in the config holds a quote
- **WHEN** the configured token contains a double quote or a line break
- **THEN** the hook does not call curl and still returns the provider's neutral control response

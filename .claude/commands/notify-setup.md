# /notify-setup

Manage your AI CLI Telegram notification settings.

## Usage

When invoked without arguments, present an interactive menu. When invoked with a subcommand, execute that action directly.

## Subcommands

- `setup` — Run the interactive install wizard
- `update` — Update a specific config setting
- `test` — Send a test notification to verify the current setup
- `status` — Show current config (Bot Token masked)
- `uninstall` — Remove hooks and config entries

## Instructions
## Instructions

1. If no argument was provided after `/notify-setup`, show this menu and ask the user to choose:

   ```
   Telegram Notify — What would you like to do?

   1) setup      — First-time install (guided wizard)
   2) update     — Change token / chat_id / notify_level
   3) test       — Send a test Telegram message now
   4) status     — Show current config
   5) uninstall  — Remove hooks and config
   ```

   Wait for the user to choose, then proceed with the selected action.

2. **setup**: Run `bash scripts/notify/telegram/install.sh` in the terminal. Show all output to the user.

3. **update**: Run `bash scripts/notify/telegram/update.sh` interactively. If the user specified what to update (e.g., "update my token"), pass the argument directly:
   - token → `bash scripts/notify/telegram/update.sh token`
   - chat_id → `bash scripts/notify/telegram/update.sh chat_id`
   - notify_level → `bash scripts/notify/telegram/update.sh notify_level`

4. **test**: Send a test notification by running:
   ```bash
   echo '{"hook_event_name":"Stop"}' \
     | CLAUDE_PROJECT_DIR="$(pwd)" bash ~/.config/ai-notify/hooks/telegram-notify.sh stop
   ```
   Then confirm with the user whether they received the message.

5. **status**: Read `~/.config/ai-notify/config` and display:
   - `TELEGRAM_ENABLED`
   - `TELEGRAM_BOT_TOKEN` — show only the last 4 characters, mask the rest with `****`
   - `TELEGRAM_CHAT_ID`
   - `NOTIFY_LEVEL`

   If the config file does not exist, tell the user that Telegram Notify is not installed and suggest running `/notify-setup setup`.

6. **uninstall**: Run `bash scripts/notify/telegram/uninstall.sh`. Show all output.

## Notes

- All scripts are in `scripts/notify/telegram/` relative to the project root.
- If the user is not in the project root, adjust the path accordingly or `cd` to it first.
- After `setup` or `update`, always suggest running `test` to verify.

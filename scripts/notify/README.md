# Provider Extension Guide — scripts/notify/

This directory contains the shared infrastructure for all AI CLI notification providers.

---

## Adding a New Provider

To add a new notification provider (e.g., Line Notify, Slack), follow these steps:

### 1. Copy the directory structure

```
scripts/
  <provider-name>/
    hook.sh       # The notification hook called by AI CLI
    install.sh    # Interactive install wizard
    update.sh     # Update individual config keys
    uninstall.sh  # Remove hook and config entries
```

Use `scripts/notify/telegram/` as your reference implementation.

### 2. Implement `hook.sh`

The hook script is called by AI CLI with the event type as `$1` and a JSON payload on stdin.

**Required interface:**

```bash
#!/usr/bin/env bash
# $1 = event type: "stop" | "notification"
# stdin = JSON payload from AI CLI

# 1. Source shared config
source ~/.config/ai-notify/config 2>/dev/null || true

# 2. Read ENABLED flag (e.g., LINE_ENABLED)
[[ "${LINE_ENABLED}" != "true" ]] && exit 0

# 3. Read event type from $1 (with jq fallback for stdin)
# 4. Apply NOTIFY_LEVEL logic
# 5. Call your provider API silently (curl --silent --max-time 10 ... || true)
```

**Exit rules:**
- Always exit 0 (silent failure — never block AI CLI)
- No stdout/stderr unless debugging

### 3. Config key naming convention

All provider keys in `~/.config/ai-notify/config` must follow:

| Key | Description |
|-----|-------------|
| `{PROVIDER}_ENABLED` | `true` / `false` master switch |
| `{PROVIDER}_<CREDENTIAL>` | Provider-specific credential (e.g., `TELEGRAM_BOT_TOKEN`) |
| `NOTIFY_LEVEL` | Shared: `all` (default) or `notify_only` |

Examples:
- `TELEGRAM_ENABLED=true`
- `TELEGRAM_BOT_TOKEN="..."`
- `LINE_ENABLED=false`
- `LINE_NOTIFY_TOKEN="..."`

`NOTIFY_LEVEL` is global and shared across all providers:
- `all` — send both Stop (task complete) and Notification (action required) events
- `notify_only` — send only Notification events (suppress Stop)

### 4. Use shared libraries

Source these helpers in your scripts:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../notify/lib"

source "${LIB_DIR}/config.sh"   # read_config, write_config, update_config_key
source "${LIB_DIR}/registry.sh" # register_hook, unregister_hook
```

### 5. Deploy path

`install.sh` must copy `hook.sh` to:
```
~/.config/ai-notify/hooks/<provider-name>.sh
```

And call `register_hook` with that deployed path:
```bash
register_hook "${HOME}/.config/ai-notify/hooks/<provider-name>.sh"
```

---

## Directory Layout Reference

```
~/.config/ai-notify/
  config                      # Shell-sourceable key=value (chmod 600)
  hooks/
    telegram-notify.sh        # Deployed from scripts/notify/telegram/hook.sh
    <provider-name>.sh        # Your provider's deployed hook
```

---

## Testing Your Hook

```bash
# Test Stop event
echo '{"hook_event_name":"Stop"}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.config/ai-notify/hooks/<provider-name>.sh stop

# Test Notification event
echo '{"hook_event_name":"Notification","message":"Please approve this action"}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.config/ai-notify/hooks/<provider-name>.sh notification
```

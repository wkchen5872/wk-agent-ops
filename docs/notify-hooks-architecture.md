# Notify Hooks — Architecture

This document describes the architecture of the AI CLI notification hook system.

---

## Overview

The notification system allows AI CLI tools (Claude Code, Gemini CLI) to send real-time notifications when tasks complete or require user attention.

**Design principle:** The repository contains only scripts. All machine state (config files, deployed hooks, settings.json entries) is created exclusively by running `install.sh` — never at repository checkout time.

---

## Directory Structure

```
scripts/
  notify/
    lib/
      config.sh        # Shared: read/write ~/.config/ai-notify/config
      registry.sh      # Shared: register/unregister hooks in AI CLI settings
    telegram/
      hook.sh          # Notification hook (called by AI CLI at runtime)
      install.sh       # Interactive install wizard
      update.sh        # Update individual config keys
      uninstall.sh     # Remove hooks and config
    line/
      .placeholder     # Reserved for future Line Notify implementation
    README.md          # Provider extension guide

.claude/
  commands/
    notify-setup.md    # /notify-setup Claude Code command
```

**Runtime layout (created by install.sh):**

```
~/.config/ai-notify/
  config               # Shell-sourceable key=value (chmod 600)
  hooks/
    telegram-notify.sh # Deployed copy of scripts/notify/telegram/hook.sh

# Copilot CLI hooks (opt-in, created by install.sh if user accepts):
.github/
  hooks/
    hooks.json         # Copilot CLI hook config (version:1)
```

---

## Config Format

`~/.config/ai-notify/config` is a shell-sourceable key=value file:

```bash
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN="7123456789:ABCdef..."
TELEGRAM_CHAT_ID="987654321"
NOTIFY_LEVEL=all           # all | notify_only
# LINE_ENABLED=false       # Future extension
```

**Security:** The file is created with `chmod 600` and never committed to the repository.

**NOTIFY_LEVEL values:**
| Value | Behaviour |
|-------|-----------|
| `all` (default) | Notify on Stop (task complete) AND Notification (action required) |
| `notify_only` | Notify only on Notification events; Stop events are suppressed |

---

## Installation Flow

```
User runs: bash scripts/notify/telegram/install.sh
          (or: /notify-setup → setup in Claude Code)

Step 1  Guide user to create Telegram Bot via @BotFather
Step 2  Read and validate Bot Token (Telegram API call)
Step 3  Auto-detect Chat ID (getUpdates API call)
Step 4  Choose NOTIFY_LEVEL
Step 5  Write ~/.config/ai-notify/config (chmod 600)
Step 6  Deploy hook: copy hook.sh → ~/.config/ai-notify/hooks/telegram-notify.sh
Step 7  Register hooks in ~/.claude/settings.json (and ~/.gemini/settings.json if present)
Step 8  Optionally register Copilot CLI hooks in .github/hooks/hooks.json [y/N]
Step 9  Send test notification to confirm end-to-end
```

**Idempotent:** Running `install.sh` multiple times is safe. Existing config values are preserved unless overwritten, and `registry.sh` prevents duplicate hook entries.

---

## Hook Lifecycle

```
AI CLI event fires (e.g., task complete)
        │
        ▼
~/.claude/settings.json hooks.Stop[...] or hooks.Notification[...]
        │
        ▼
bash ~/.config/ai-notify/hooks/telegram-notify.sh <event-type>
  (stdin: JSON payload from AI CLI)
        │
        ├─ source ~/.config/ai-notify/config
        ├─ check TELEGRAM_ENABLED, credentials
        ├─ check NOTIFY_LEVEL gate
        ├─ detect tool name + project from env / stdin
        ├─ build message
        └─ curl --silent --max-time 10 Telegram API || true
           (always exits 0 — never blocks AI CLI)
```

---

## Data Formats

AI CLI 工具（Claude Code, Gemini CLI, Copilot CLI）透過 `stdin` 將 JSON payload 傳遞給 Hook 腳本。

### Standard JSON Payload (Incoming)

```json
{
  "hook_event_name": "Stop",     // 事件類型：Stop | Notification | sessionEnd | ...
  "message": "...",              // (選填) 通知詳細訊息，如等待授權的內容
  "project_dir": "/path/to/proj" // (選填) 專案路徑
}
```

*   **Claude Code**: 傳送 `Stop` 與 `Notification` 事件。
*   **Gemini CLI**: 傳送 `AfterAgent` 與 `Notification` 事件。
*   **Copilot CLI**: 傳送 `sessionEnd` 與 `userPromptSubmitted` 事件。

---

## Shared Libraries

### `scripts/notify/lib/config.sh`

| Function | Description |
|----------|-------------|
| `read_config` | Source the config file into current shell |
| `write_config KEY=VAL ...` | Create/overwrite config with given pairs (chmod 600) |
| `update_config_key KEY VAL` | Update a single key; leave others intact |
| `remove_config_keys_by_prefix PREFIX` | Remove all keys matching a prefix |

### `scripts/notify/lib/registry.sh`

| Function | Description |
|----------|-------------|
| `register_hook <hook_path>` | Add Stop + Notification hooks to Claude/Gemini settings (idempotent) |
| `unregister_hook <hook_path>` | Remove hook entries without affecting other hooks |
| `register_hook_copilot <hook_path>` | Write `sessionEnd` + `userPromptSubmitted` entries to `.github/hooks/hooks.json` (idempotent) |
| `unregister_hook_copilot <hook_path>` | Remove Copilot hook entries from `.github/hooks/hooks.json` |

All functions require `jq`.

---

## Copilot CLI Integration

Copilot CLI uses a different hook mechanism from Claude Code and Gemini CLI. Hooks are stored in a per-repo file rather than a global settings file.

### Hook file: `.github/hooks/hooks.json`

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      { "type": "bash", "command": "bash \"~/.config/ai-notify/hooks/telegram-notify.sh\" sessionEnd" }
    ],
    "userPromptSubmitted": [
      { "type": "bash", "command": "bash \"~/.config/ai-notify/hooks/telegram-notify.sh\" userPromptSubmitted" }
    ]
  }
}
```

### Event mapping

| Copilot CLI event | Mapped to | Message type |
|-------------------|-----------|-------------|
| `sessionEnd` | `stop` (task complete) | 🟢 Task Complete |
| `userPromptSubmitted` | `notification` (action required) | 🟠 Action Required |

### Detection in hook.sh

`hook.sh` detects Copilot CLI via the `GITHUB_COPILOT_SESSION_ID` environment variable. Detection order: Gemini CLI → Copilot CLI → Claude Code → "AI CLI".

### Setup

Copilot hook registration is **opt-in** during `install.sh` (step 8). The resulting `.github/hooks/hooks.json` can be committed to the repository so all machines with the notify hook installed benefit automatically.

To register after install:
```bash
bash scripts/notify/telegram/update.sh copilot-hooks
```

---

## How to Add a New Provider

See `scripts/notify/README.md` for the step-by-step provider extension guide.

Summary:
1. Copy `scripts/notify/telegram/` to `scripts/<provider-name>/`
2. Implement `hook.sh` with the standard interface
3. Use `{PROVIDER}_ENABLED` config key prefix
4. Deploy hook to `~/.config/ai-notify/hooks/<provider-name>.sh` from `install.sh`
5. Call `register_hook` / `unregister_hook` from shared library

---

## Rollback

```bash
# Full removal
bash scripts/notify/telegram/uninstall.sh

# Or in Claude Code
/notify-setup → uninstall
```

Uninstall removes hook entries from `settings.json`, `TELEGRAM_*` keys from config, and the deployed hook file. Other providers and settings are not affected.

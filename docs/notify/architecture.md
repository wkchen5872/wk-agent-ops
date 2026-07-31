---
type: Architecture
title: AI CLI Notification Hooks Architecture
description: Native host hook registration and Telegram notification data flow.
tags: [notifications, hooks, codex, antigravity, telegram]
timestamp: 2026-07-31T17:43:42+08:00
---

# Notify Hooks — Architecture

This document describes the architecture of the AI CLI notification hook system.

---

## Overview

The notification system allows Claude Code, Codex, Antigravity CLI, and Copilot
CLI to send Telegram notifications when an agent turn finishes, requires user
attention, or stops abnormally.

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

# Native user-level host configuration:
~/.codex/hooks.json                         # Codex Stop + PermissionRequest
~/.gemini/config/hooks.json                 # Antigravity named Stop hook
~/.gemini/antigravity-cli/settings.json     # Approval observer when statusLine is free
```

`~/.gemini/settings.json` is cleanup-only: setup, repair, and uninstall remove
notification-owned legacy Gemini commands but never register new ones.

---

## Config Format

`~/.config/ai-notify/config` is a shell-sourceable key=value file:

```bash
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN="7123456789:ABCdef..."
TELEGRAM_CHAT_ID="987654321"
NOTIFY_LEVEL=all           # all | attention_required
# LINE_ENABLED=false       # Future extension
```

**Security:** The file is created with `chmod 600` and never committed to the repository.

**NOTIFY_LEVEL values:**
| Value | Behaviour |
|-------|-----------|
| `all` (default) | Send completion, action-required, and failure events |
| `attention_required` | Send action-required and failure events; suppress successful completion |

The legacy `notify_only` value is read as `attention_required` and normalized
when setup or update next writes the config.

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
Step 7  Register Claude plus detected Codex and Antigravity hooks; attempt approval observation safely
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
Native AI CLI hook or Antigravity status state
        │
        ▼
bash ~/.config/ai-notify/hooks/telegram-notify.sh <event-type> [tool-name]
  (stdin: JSON payload from AI CLI)
        │
        ├─ source ~/.config/ai-notify/config
        ├─ TOOL_NAME = $2 arg (set by registry.sh) or "AI CLI"
        ├─ PROJECT_DIR from payload cwd/workspace, CLAUDE_PROJECT_DIR, or PWD
        ├─ SESSION_LABEL from session/conversation payload or Copilot env
        ├─ update Antigravity approval state and parse terminal reason
        ├─ classify completion / action_required / failure
        ├─ apply the semantic NOTIFY_LEVEL gate
        ├─ check TELEGRAM_ENABLED and credentials (skipped in dry-run)
        ├─ return the provider-neutral control response
        ├─ build message (title includes session label when available)
        └─ curl --silent --max-time 4 Telegram API || true
           (always exits 0; curl is bounded to four seconds)
```

---

## Data Formats

AI CLI 工具透過 `stdin` 將 JSON payload 傳遞給 Hook 腳本。

### Standard JSON Payload (Incoming)

```json
{
  "hook_event_name": "Stop",     // 事件類型：Stop | Notification | sessionEnd | ...
  "message": "...",              // (選填) 通知詳細訊息，如等待授權的內容
  "cwd": "/path/to/proj"         // (選填) 專案路徑
}
```

*   **Claude Code**: 傳送 `Stop` 與 `Notification` 事件。
*   **Codex**: 傳送 `Stop` 與 `PermissionRequest`；notification hook 回傳
    neutral `{}`，不代替使用者決定。
*   **Antigravity CLI**: `Stop` 提供 `fullyIdle` 與
    `terminationReason`；managed status line 提供
    `tool_confirmation_pending`。
*   **Copilot CLI**: 傳送 `sessionEnd` 與 `userPromptSubmitted` 事件。

---

## Shared Libraries

### `scripts/notify/lib/config.sh`

| Function | Description |
|----------|-------------|
| `normalize_notify_level VALUE` | Return `all` or `attention_required`, including the legacy alias |
| `read_config` | Source the config file into current shell |
| `write_config KEY=VAL ...` | Create/overwrite config with given pairs (chmod 600) |
| `update_config_key KEY VAL` | Update a single key; leave others intact |
| `remove_config_keys_by_prefix PREFIX` | Remove all keys matching a prefix |

### `scripts/notify/lib/registry.sh`

| Function | Description |
|----------|-------------|
| `register_hook <hook_path>` | Register Claude plus detected Codex and Antigravity hooks; clean owned legacy Gemini entries |
| `unregister_hook <hook_path>` | Remove owned global hook entries without affecting other hooks |
| `register_hook_copilot <hook_path>` | Write `sessionEnd` + `userPromptSubmitted` entries to `.github/hooks/hooks.json` (idempotent) |
| `unregister_hook_copilot <hook_path>` | Remove Copilot hook entries from `.github/hooks/hooks.json` |
| `register_hook_codex <hook_path>` | Add neutral `Stop` + `PermissionRequest` hooks to `~/.codex/hooks.json` |
| `register_hook_antigravity <hook_path>` | Add the named global Antigravity `Stop` hook |
| `register_hook_antigravity_statusline <hook_path>` | Add approval-state observation without overwriting another command |
| `show_hook_status <hook_path>` | Report provider registration without reading credentials |

All functions require `jq`.

---

## Codex Integration

Codex hooks live in `~/.codex/hooks.json`. The installer adds `Stop` for
completion and `PermissionRequest` for approval notifications. Both invoke the
deployed hook with a five-second native timeout. The hook returns `{}` and never
returns `allow`, `deny`, `block`, or `continue`, so Codex retains its normal
approval and stopping behavior.

Non-managed Codex command hooks have three independent runtime states:

1. configured in `~/.codex/hooks.json`;
2. trusted in `/hooks`;
3. enabled with an `[x]` checkbox in `/hooks`.

Both `Stop` and `PermissionRequest` must be trusted and enabled. `Trust:
Trusted` does not override an unchecked `[ ] Hook 1`; that hook remains
disabled. `show_hook_status` reports only whether the owned commands exist in
configuration because Codex does not expose trust and enablement through the
registry file.

The approval message contains only the canonical tool name. Raw commands,
arguments, prompts, descriptions, and transcript paths are not forwarded.

---

## Antigravity CLI Integration

Antigravity completion hooks live in `~/.gemini/config/hooks.json` under the
owned `telegram-notify` definition. `Stop` emits a completion only when
`fullyIdle=true`; `error` and `max_steps_exceeded` are reported as stopped, never
successful. The hook returns `{"decision":"stop"}`, which permits the documented
stop instead of re-entering the execution loop.

Antigravity approval observation uses
`~/.gemini/antigravity-cli/settings.json`. Setup and `fix-hooks` attempt it
automatically whenever Antigravity is detected:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"/Users/<user>/.config/ai-notify/hooks/telegram-notify.sh\" antigravity-statusline \"Antigravity CLI\""
  }
}
```

The observer notifies on the first `tool_confirmation_pending=true`, suppresses
repeated true states for that conversation, and resets after false even when
Telegram delivery is disabled. It prints a compact agent-state value so it
remains a valid status-line command. A different existing command is preserved
and reported as `Antigravity approval: unavailable (statusLine conflict)`.

---

## Copilot CLI Integration

Copilot CLI uses a repository-local hook file rather than global host settings.

### Hook file: `.github/hooks/hooks.json`

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      { "type": "command", "bash": "bash \"/Users/<user>/.config/ai-notify/hooks/telegram-notify.sh\" sessionEnd \"Copilot CLI\"" }
    ],
    "userPromptSubmitted": [
      { "type": "command", "bash": "bash \"/Users/<user>/.config/ai-notify/hooks/telegram-notify.sh\" userPromptSubmitted \"Copilot CLI\"" }
    ]
  }
}
```

### Event mapping

| Copilot CLI event | Mapped to | Message type |
|-------------------|-----------|-------------|
| `sessionEnd` | `stop` (task complete) | 🟢 Task Complete |
| `userPromptSubmitted` | `notification` (action required) | 🟠 Action Required |

### Tool name in hook.sh

`hook.sh` receives the tool name as `$2` CLI argument, hardcoded by `registry.sh` at registration time:

| Caller | `$1` (event) | `$2` (tool name) |
|--------|-------------|-----------------|
| Claude Code | `stop` / `notification` | `"Claude Code"` |
| Codex | `codex-stop` / `codex-permission` | `"Codex"` |
| Antigravity CLI | `antigravity-stop` / `antigravity-statusline` | `"Antigravity CLI"` |
| Copilot CLI | `sessionEnd` / `userPromptSubmitted` | `"Copilot CLI"` |

When `$2` is absent (old-format registered hooks), `TOOL_NAME` defaults to `"AI CLI"`. Run `fix-hooks` to upgrade:

```bash
bash scripts/notify/telegram/update.sh fix-hooks
```

### Setup

Copilot hook registration is **opt-in** during `install.sh` (step 8). The resulting `.github/hooks/hooks.json` can be committed to the repository so all machines with the notify hook installed benefit automatically.

To register after install:
```bash
bash scripts/notify/telegram/update.sh copilot-hooks
```

---

## How to Add a New Provider

See the [provider extension guide](/scripts/notify/README.md) for the step-by-step provider extension workflow.

Summary:
1. Copy `scripts/notify/telegram/` to `scripts/notify/<provider-name>/`
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

Uninstall removes owned Claude, Codex, and Antigravity hook entries, any
notification-owned legacy Gemini commands, Antigravity notification state,
`TELEGRAM_*` keys, and the deployed hook. It removes repository-local Copilot
entries only after separate confirmation. Unrelated hooks and settings remain
unchanged.

Before rolling back to a hook release that predates `attention_required`, set
the config value back to its legacy spelling, `notify_only`.

# Citations

[1] [OpenAI Codex Hooks](https://developers.openai.com/codex/hooks)
[2] [Google Antigravity Hooks](https://antigravity.google/docs/hooks)
[3] [Google Antigravity Status Line](https://antigravity.google/docs/cli/statusline)

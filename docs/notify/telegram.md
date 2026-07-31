---
type: Playbook
title: Telegram Notify Hook Setup
description: Install and operate Telegram notifications across supported AI CLIs.
tags: [telegram, notifications, hooks, codex, antigravity]
timestamp: 2026-07-31T15:57:50+08:00
---

# Telegram Notify Hook — Quick Setup

Get Telegram notifications when Claude Code, Gemini CLI, Codex, Antigravity
CLI, or Copilot CLI finishes a turn or needs your attention.

---

## Quick Install

### Option A: Inside Claude Code (Recommended)

```
/notify-setup
```

Select **setup** from the menu. Claude will run the interactive wizard in your terminal.

### Option B: Manual

```bash
bash scripts/notify/telegram/install.sh
```

The wizard guides you through:
1. Creating a Telegram Bot via @BotFather
2. Validating your Bot Token
3. Auto-detecting your Chat ID
4. Choosing a notification level
5. Deploying the hook and registering detected AI CLIs
6. Optionally observing Antigravity approval prompts
7. Optionally registering repository-local Copilot hooks

---

## What Gets Installed

| Item | Location |
|------|----------|
| Config (credentials) | `~/.config/ai-notify/config` (chmod 600) |
| Deployed hook script | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Claude Code hooks | `~/.claude/settings.json` → `hooks.Stop`, `hooks.Notification` |
| Gemini CLI hooks | `~/.gemini/settings.json` → `hooks.AfterAgent`, `hooks.Notification` |
| Codex hooks | `~/.codex/hooks.json` → `hooks.Stop`, `hooks.PermissionRequest` |
| Antigravity completion | `~/.gemini/config/hooks.json` → `telegram-notify.Stop` |
| Antigravity approval (opt-in) | `~/.gemini/antigravity-cli/settings.json` → `statusLine` |
| Copilot CLI hooks (opt-in) | `.github/hooks/hooks.json` → `sessionEnd`, `userPromptSubmitted` |

### Codex requires configuration, trust, and enablement

Codex command hooks pass through three independent states:

1. **Configured** — `Stop` and `PermissionRequest` exist in
   `~/.codex/hooks.json`.
2. **Trusted** — each command definition shows `Trust: Trusted` in `/hooks`.
3. **Enabled** — each `Hook 1` checkbox shows `[x]`, not `[ ]`.

Open `/hooks` after registration and verify both events. A trusted hook with an
unchecked `[ ] Hook 1` is still disabled and does not run. Changes made in the
`/hooks` panel are saved automatically.

`bash scripts/notify/telegram/update.sh status` verifies only that the owned
commands are configured. It cannot inspect Codex's trust or enabled state.

---

## NOTIFY_LEVEL

Control which events trigger a notification:

| Level | Stop event (task complete) | Notification event (action required) |
|-------|---------------------------|--------------------------------------|
| `all` (default) | ✅ Sends notification | ✅ Sends notification |
| `notify_only` | ❌ Silent | ✅ Sends notification |

**Change level after install:**

```bash
bash scripts/notify/telegram/update.sh notify_level
# or
/notify-setup → update
```

---

## Notification Format

Telegram 通知訊息採用統一的 Markdown 排版，結構如下：

### Output Layout (Markdown)

```
{STATUS_ICON} **{TITLE}** ({SESSION})

🤖 {TOOL_NAME}
📂 {PROJECT_NAME}
⏰ {TIMESTAMP}

{MESSAGE} #{HOOK_EVENT_NAME}
```

- **STATUS_ICON**: `🟢` (Task Complete) | `🟠` (Action Required) | `🔴` (Task Stopped) | `🤖` (Generic Event)
- **TITLE**: `Task Complete` | `Action Required` | `Task Stopped`
- **SESSION** *(optional)*: shown when session info is available
  - UUID `session_id` (Claude) → `#<first 8 chars>` e.g. `(#a1b2c3d4)`
  - Non-UUID `sessionId` (Copilot) → used as-is e.g. `(copilot-xyz)`
  - `GITHUB_COPILOT_SESSION_ID` env var → `#<first 8 chars>`
  - No session info → title has no parentheses
- **MESSAGE Fallback**:
  - Task Complete: `Process finished successfully`
  - Action Required: `Waiting for user interaction...`

Codex approval notifications include only the requesting tool name. Raw commands,
arguments, prompts, transcript paths, and Antigravity raw error text are never
included.

---

## Notification Examples

**Stop event (task complete):**
```
🟢 **Task Complete** (#a1b2c3d4)

🤖 Claude Code
📂 my-project
⏰ 2025-03-31 14:22:05

Process finished successfully #Stop
```

**Stop event (no session info):**
```
🟢 **Task Complete**

🤖 Claude Code
📂 my-project
⏰ 2025-03-31 14:22:05

Process finished successfully #Stop
```

**Notification event (action required):**
```
🟠 **Action Required**

🤖 Claude Code
📂 my-project
⏰ 2025-03-31 14:22:05

Please approve the file deletion #Notification
```

**Notification event (no message):**
```
🟠 **Action Required**

🤖 Claude Code
📂 my-project
⏰ 2025-03-31 14:22:05

Waiting for user interaction... #Notification
```

---

## Updating Settings

```bash
# Interactive menu
bash scripts/notify/telegram/update.sh

# Direct key update
bash scripts/notify/telegram/update.sh token
bash scripts/notify/telegram/update.sh chat_id
bash scripts/notify/telegram/update.sh notify_level
bash scripts/notify/telegram/update.sh fix-hooks
bash scripts/notify/telegram/update.sh antigravity-approval
bash scripts/notify/telegram/update.sh status

# Or in Claude Code
/notify-setup → update
```

---

## Testing

```bash
# Automated test suite (dry-run, no Telegram connection needed)
bash scripts/notify/telegram/test.sh

# Manual: test Stop event (Claude Code)
echo '{"hook_event_name":"Stop"}' \
  | bash ~/.config/ai-notify/hooks/telegram-notify.sh stop "Claude Code"

# Manual: test Notification event
echo '{"hook_event_name":"Notification","message":"Please approve this action"}' \
  | bash ~/.config/ai-notify/hooks/telegram-notify.sh notification "Claude Code"

# Manual: dry-run (outputs message to stdout, no HTTP request)
TELEGRAM_DRY_RUN=true bash scripts/notify/telegram/hook.sh stop "Claude Code"

# Codex approval fixture: prints Telegram message only, sends no request
printf '%s' '{"hook_event_name":"PermissionRequest","tool_name":"Bash","cwd":"'"$(pwd)"'"}' \
  | TELEGRAM_DRY_RUN=true bash scripts/notify/telegram/hook.sh codex-permission "Codex"

# Antigravity completion fixture
printf '%s' '{"terminationReason":"model_stop","fullyIdle":true,"conversationId":"demo","workspacePaths":["'"$(pwd)"'"]}' \
  | TELEGRAM_DRY_RUN=true bash scripts/notify/telegram/hook.sh antigravity-stop "Antigravity CLI"
```

Or in Claude Code: `/notify-setup → test`

---

## Rollback

```bash
bash scripts/notify/telegram/uninstall.sh
# or
/notify-setup → uninstall
```

Removes:
- `TELEGRAM_*` entries from `~/.config/ai-notify/config`
- Hook entries from `~/.claude/settings.json`
- Owned hook entries from `~/.codex/hooks.json` and `~/.gemini/config/hooks.json`
- The Antigravity `statusLine` only when it is notification-owned
- Antigravity notification state markers
- `~/.config/ai-notify/hooks/telegram-notify.sh`

Does **not** touch other config keys or unrelated hooks. Repository-local
Copilot hooks are changed only when the uninstall prompt is confirmed.

---

## Troubleshooting

**Not receiving notifications?**

1. Check registration: `bash scripts/notify/telegram/update.sh status`
2. Check `TELEGRAM_ENABLED=true`
3. Check `NOTIFY_LEVEL` — if `notify_only`, Stop events are suppressed
4. Test manually with the curl command above
5. Verify Bot Token: `curl https://api.telegram.org/bot<TOKEN>/getMe`

**Hook not firing in Claude Code?**

Check `~/.claude/settings.json` contains:
```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "bash \"/Users/<user>/.config/ai-notify/hooks/telegram-notify.sh\" stop \"Claude Code\"", "async": true, "timeout": 15}]}],
    "Notification": [{"hooks": [{"type": "command", "command": "bash \"/Users/<user>/.config/ai-notify/hooks/telegram-notify.sh\" notification \"Claude Code\"", "async": true, "timeout": 15}]}]
  }
}
```

If missing, re-run `bash scripts/notify/telegram/install.sh` (idempotent).

**Codex hooks installed but not firing?**

1. Run `bash scripts/notify/telegram/update.sh status` and confirm
   `Codex: registered`. This confirms configuration only.
2. Open `/hooks` in Codex.
3. Under both `PermissionRequest hooks` and `Stop hooks`, verify:

   ```text
   [x] Hook 1
   Trust  Trusted
   ```

   `[ ] Hook 1` means disabled even when `Trust` says `Trusted`; select the
   entry and press Space to enable it.
4. Exit the panel and run another turn. `Stop` fires when the turn finishes;
   `PermissionRequest` fires only when Codex actually opens an approval request.
5. If an already-open session still does not reload the setting, start a new
   Codex session and retry.

**Antigravity completion works but approval notification does not?**

Run:

```bash
bash scripts/notify/telegram/update.sh antigravity-approval
```

If a different `statusLine.command` already exists, setup leaves it unchanged.
Choose which status-line command to keep; the installer does not chain unknown
commands.

---

## See Also

- [Notify Hooks Architecture](/docs/notify/architecture.md) — full architecture
- [Provider Extension Guide](/scripts/notify/README.md) — adding a destination provider

# Citations

[1] [OpenAI Codex Hooks](https://developers.openai.com/codex/hooks)
[2] [Google Antigravity Hooks](https://antigravity.google/docs/hooks)
[3] [Google Antigravity Status Line](https://antigravity.google/docs/cli/statusline)

# Telegram Notify Hook — Quick Setup

Get Telegram notifications when Claude Code, Gemini CLI, or Copilot CLI finishes a task or needs your attention.

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
5. Deploying the hook and updating `~/.claude/settings.json`

---

## What Gets Installed

| Item | Location |
|------|----------|
| Config (credentials) | `~/.config/ai-notify/config` (chmod 600) |
| Deployed hook script | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Claude Code hooks | `~/.claude/settings.json` → `hooks.Stop`, `hooks.Notification` |
| Copilot CLI hooks (opt-in) | `.github/hooks/hooks.json` → `sessionEnd`, `userPromptSubmitted` |

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
{STATUS_ICON} **{TITLE}**

🤖 {TOOL_NAME}
📂 {PROJECT_NAME}
⏰ {TIMESTAMP}

{MESSAGE} #{HOOK_EVENT_NAME}
```

- **STATUS_ICON**: `🟢` (Task Complete) | `🔴` (Action Required) | `🤖` (Generic Event)
- **TITLE**: `Task Complete` | `Action Required`
- **MESSAGE Fallback**:
  - Task Complete: `Process finished successfully`
  - Action Required: `Waiting for user interaction...`

---

## Notification Examples

**Stop event (task complete):**
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

# Or in Claude Code
/notify-setup → update
```

---

## Testing

```bash
# Test Stop event manually
echo '{"hook_event_name":"Stop"}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.config/ai-notify/hooks/telegram-notify.sh stop

# Test Notification event
echo '{"hook_event_name":"Notification","message":"Please approve this action"}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.config/ai-notify/hooks/telegram-notify.sh notification
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
- `~/.config/ai-notify/hooks/telegram-notify.sh`

Does **not** touch: other config keys, other hooks, any project files.

---

## Troubleshooting

**Not receiving notifications?**

1. Check config exists: `cat ~/.config/ai-notify/config`
2. Check `TELEGRAM_ENABLED=true`
3. Check `NOTIFY_LEVEL` — if `notify_only`, Stop events are suppressed
4. Test manually with the curl command above
5. Verify Bot Token: `curl https://api.telegram.org/bot<TOKEN>/getMe`

**Hook not firing in Claude Code?**

Check `~/.claude/settings.json` contains:
```json
{
  "hooks": {
    "Stop": [{"type": "command", "command": "bash \"~/.config/ai-notify/hooks/telegram-notify.sh\" stop"}],
    "Notification": [{"type": "command", "command": "bash \"~/.config/ai-notify/hooks/telegram-notify.sh\" notification"}]
  }
}
```

If missing, re-run `bash scripts/notify/telegram/install.sh` (idempotent).

---

## See Also

- [Notify Hooks Architecture](notify-hooks-architecture.md) — full architecture, extension guide
- `scripts/notify/README.md` — adding a new notification provider

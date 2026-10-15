---
type: Playbook
title: Telegram Notify Hook Setup
description: Install and operate Telegram notifications across supported AI CLIs.
tags: [telegram, notifications, hooks, codex, antigravity]
timestamp: 2026-10-15T00:00:00+08:00
---

# Telegram Notify Hook — Quick Setup

Get Telegram notifications when Claude Code, Codex, Antigravity CLI, or
Copilot CLI finishes a turn, needs your attention, or stops abnormally.

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
4. 在繁體中文分組選單選擇通知類型，確認摘要後儲存
5. Deploying the hook and registering detected AI CLIs
6. Observing Antigravity approval prompts when its status-line slot is available
7. Optionally registering repository-local Copilot hooks

---

## What Gets Installed

| Item | Location |
|------|----------|
| Config (credentials) | `~/.config/ai-notify/config` (chmod 600) |
| Deployed hook script | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Claude Code hooks | `~/.claude/settings.json` → `hooks.Stop`, `hooks.Notification` |
| Codex hooks | `~/.codex/hooks.json` → `Stop`, `PermissionRequest`, question `PreToolUse` / `PostToolUse` |
| Shared runtime config helper | `~/.config/ai-notify/lib/config.sh` |
| Codex on-demand checker | `~/.config/ai-notify/hooks/codex-wait.py` |
| Optional isolated Python runtime | `~/.config/ai-notify/runtime/codex-wait/` |
| Antigravity completion | `~/.gemini/config/hooks.json` → `telegram-notify.Stop` |
| Antigravity approval (automatic when available) | `~/.gemini/antigravity-cli/settings.json` → `statusLine` |
| Copilot CLI hooks (opt-in) | `.github/hooks/hooks.json` → `sessionEnd`, `userPromptSubmitted` |

Setup and `fix-hooks` remove only notification-owned legacy Gemini hook
commands if they still exist. Gemini CLI is not an active notification host.

### Codex requires configuration, trust, and enablement

Codex command hooks pass through three independent states:

1. **Configured** — `Stop`, `PermissionRequest` and question `PreToolUse` / `PostToolUse` entries exist in
   `~/.codex/hooks.json`.
2. **Trusted** — each command definition shows `Trust: Trusted` in `/hooks`.
3. **Enabled** — each `Hook 1` checkbox shows `[x]`, not `[ ]`.

Open `/hooks` after registration and verify all four owned definitions. A trusted hook with an
unchecked `[ ] Hook 1` is still disabled and does not run. Changes made in the
`/hooks` panel are saved automatically.

`bash scripts/notify/telegram/update.sh status` verifies only that the owned
commands are configured. It cannot inspect Codex's trust or enabled state.

---

## 通知類型與設定

```bash
bash scripts/notify/telegram/update.sh types
```

使用編號切換、`h` 查看說明、`s` 顯示儲存摘要並確認，或 `q` 放棄。EOF 也會取消，取消不寫入設定。安裝與更新共用同一套畫面，Bot Token 不列入摘要。

| 分組 | 設定鍵 | 內容／預設 |
|---|---|---|
| 共用 | `NOTIFY_COMPLETION` | 工作結束；缺省沿用舊等級 |
| 共用 | `NOTIFY_ACTION_REQUIRED` | 既有操作提醒，包含 Codex PermissionRequest；缺省開啟 |
| 共用 | `NOTIFY_FAILURE` | 異常停止，目前僅 Antigravity 提供訊號；缺省開啟 |
| Codex 專用 | `NOTIFY_CODEX_HUMAN_APPROVAL` | 等待你授權；缺省關閉 |
| Codex 專用 | `NOTIFY_CODEX_USER_INPUT` | 等待你回答，僅結構化問題；缺省關閉 |

共用分類不代表每個工具都有所有事件。既有 PermissionRequest 不增加專屬開關；自動 reviewer 也可能處理這個事件，它本身不代表人工等待。

### 舊設定相容

保留 `NOTIFY_LEVEL=all` 與 `attention_required`；`notify_only` 是後者的舊名稱。未設定個別開關時，`attention_required` 只關閉成功結束通知；已設定的個別開關優先。環境變數可覆寫同名設定鍵。

`update.sh notify_level` 仍可使用，只調整三個共用開關，不改變 Codex 新項目。選單也接受舊版快速預設 `all`／`attention_required`，選取即確認該預設，保留新項目原選擇。

### Codex 按需檢查

```text
PermissionRequest hook
  ├─ 共用操作提醒開啟 → 原本的 PermissionRequest 通知
  └─ 任一 Codex 新項目開啟 → 啟動按需檢查器 → 查看目前 session 的 daemon 狀態

同步結構化問題 PreToolUse hook → 同一個按需檢查流程
非同步結構化問題 PostToolUse hook → accepted=true → 等待你回答通知（不需 daemon）
```

兩條分支互不依賴：關閉原本提醒仍可檢查 daemon；兩個新項目都關閉時完全不檢查。新標題分別是 `🔴 等待你授權` 與 `🟡 Waiting for Your Response`；問題通知內文為 `Codex has a question awaiting your response.`。`request_user_input_async` 不產生 daemon 等待旗標，改在工具成功送出題目後通知；這表示有題目待回覆，Codex 仍可繼續工作。

啟用新項目後，安裝／更新會部署 Python 3 檢查器與專用 venv 中的 `websocket-client`，不修改全域 Python、不安裝 LaunchAgent。hook 返回後，暫時檢查器透過 `codex app-server proxy` 唯讀觀察既有 daemon；同一 session 共用程序，工作輪次完成／取消後退出。依賴安裝失敗會顯示原因，既有通知仍可使用；以 `fix-hooks` 重試。

支援範圍與限制：

- 授權與同步問題需可由目前 `CODEX_HOME` 連線的既有本機 daemon；不啟動 daemon。非同步問題依原生成功事件通知，不需 daemon。
- 以明確等待旗標辨識，不靠靜默時間或問號。一般文字提問不偵測。
- 同一 session、同一種類、同段等待只嘗試通知一次，解除後重設；一秒 metadata 輪詢可能錯過更短的等待或中間解除。
- 不附原始命令、問題全文或 transcript。連線錯誤只保留一般狀態碼，不印原始例外。
- 狀態畫面區分設定、依賴、daemon 連線與本機端到端驗收；已勾選不代表 `/hooks` 已信任／啟用，也不代表人工授權區分已實測。

```bash
bash scripts/notify/telegram/update.sh status
bash scripts/notify/telegram/update.sh fix-hooks
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

- **STATUS_ICON**: `🟢` (Task Complete) | `🟡` (Action Required / Waiting for Your Response) | `🔴` (Task Stopped) | `🤖` (Generic Event)
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
🟡 **Action Required**

🤖 Claude Code
📂 my-project
⏰ 2025-03-31 14:22:05

Please approve the file deletion #Notification
```

**Notification event (no message):**
```
🟡 **Action Required**

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
bash scripts/notify/telegram/update.sh types
bash scripts/notify/telegram/update.sh notify_level
bash scripts/notify/telegram/update.sh fix-hooks
bash scripts/notify/telegram/update.sh copilot-hooks
bash scripts/notify/telegram/update.sh status

# Or in Claude Code
/notify-setup → update
```

---

## Testing

```bash
# Automated test suite (dry-run, no Telegram connection needed)
bash scripts/notify/telegram/test.sh
python3 -m unittest discover -s scripts/notify/tests -v

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
- Notification-owned legacy hook entries from `~/.gemini/settings.json`
- The Antigravity `statusLine` only when it is notification-owned
- Antigravity notification state markers
- Codex 按需程序（合作式停止）、自有狀態、檢查器與專用 venv；兩個新項目重設為關閉
- `~/.config/ai-notify/hooks/telegram-notify.sh`

Does **not** touch unrelated config keys or unrelated hooks. Repository-local
Copilot hooks are changed only when the uninstall prompt is confirmed.

To roll back to a release that predates `attention_required`, first set
`NOTIFY_LEVEL=notify_only` in `~/.config/ai-notify/config`; older hooks do not
recognize the canonical replacement.

---

## Troubleshooting

**Not receiving notifications?**

1. Check registration: `bash scripts/notify/telegram/update.sh status`
2. Check `TELEGRAM_ENABLED=true`
3. 用 `update.sh types` 檢查該類型開關；缺省時才沿用 `NOTIFY_LEVEL`
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
3. Under `PermissionRequest hooks`, `Stop hooks`, and the owned question `PreToolUse` / `PostToolUse` hooks, verify:

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
bash scripts/notify/telegram/update.sh fix-hooks
bash scripts/notify/telegram/update.sh status
```

Setup and `fix-hooks` attempt approval observation automatically. If status says
`Antigravity approval: unavailable (statusLine conflict)`, a different
`statusLine.command` already exists and remains unchanged. Choose which command
to keep; the installer does not chain unknown commands.

---

## See Also

- [Notify Hooks Architecture](/docs/notify/architecture.md) — full architecture
- [Provider Extension Guide](/scripts/notify/README.md) — adding a destination provider

# Citations

[1] [OpenAI Codex Hooks](https://developers.openai.com/codex/hooks)
[2] [Google Antigravity Hooks](https://antigravity.google/docs/hooks)
[3] [Google Antigravity Status Line](https://antigravity.google/docs/cli/statusline)

[4] [OpenAI Codex App Server](https://learn.chatgpt.com/docs/app-server)
[5] [websocket-client custom sockets](https://websocket-client.readthedocs.io/en/latest/examples.html#connecting-with-custom-sockets)

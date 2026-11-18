---
type: Playbook
title: Telegram Notify Hook Setup
description: Install and operate Telegram notifications across supported AI CLIs.
tags: [telegram, notifications, hooks, codex, antigravity]
generated: { by: claude-code/claude-sonnet-5-5, at: 2026-11-18T14:17:55+08:00 }
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
| Shared runtime helpers | `~/.config/ai-notify/lib/config.sh`、`template.sh`、`authorization.sh` |
| Event table | `~/.config/ai-notify/hooks/events.tsv` |
| Built-in message templates | `~/.config/ai-notify/hooks/templates/`（每次更新覆寫） |
| User template overrides (optional) | `~/.config/ai-notify/templates/<name>.md`（安裝、更新、uninstall 都不動） |
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

Open a new Codex session after registration, then verify all four owned definitions in `/hooks`.
A trusted hook with an unchecked `[ ] Hook 1` is still disabled and does not run. Changes made in the
`/hooks` panel are saved automatically.

Each owned handler carries a `statusMessage`, which `/hooks` shows as its name:

| Event | Default name |
|-------|--------------|
| `Stop` | `Telegram 完成通知` |
| `PermissionRequest` | `Telegram 操作確認與等待檢查` |
| question `PreToolUse` | `Telegram 同步問題等待檢查` |
| async-question `PostToolUse` | `Telegram 非同步問題通知` |

Install and repeated registration fill a missing, null, empty or whitespace-only
name in place and keep a non-blank custom name. `update.sh fix-hooks` removes and
recreates the owned handlers, so it resets custom names to these defaults; other
hooks stay intact. A new or changed name changes the hook definition: after
either path, open a new session and trust and enable the changed hooks again in
`/hooks`. The installer never changes Codex trust or enable state.

`bash scripts/notify/telegram/update.sh status` verifies only that the owned
commands are configured. It cannot inspect Codex's trust or enabled state.

---

## 通知類型與設定

```bash
bash scripts/notify/telegram/update.sh types
```

使用編號切換、`h` 查看說明、`s` 顯示儲存摘要並確認，或 `q` 放棄。EOF 也會取消，取消不寫入設定。安裝與更新共用同一套畫面，Bot Token 不列入摘要。

四個分類，各一個開關（括號為選單名稱）：

| 設定鍵 | 選單名稱 | 內容／預設 |
|---|---|---|
| `NOTIFY_COMPLETION` | 工作結束 | 缺省沿用 `NOTIFY_LEVEL`（`attention_required` 為關閉） |
| `NOTIFY_AUTHORIZATION` | 授權要求 | 等你授權；延遲通知，見下節；缺省開啟 |
| `NOTIFY_USER_INPUT` | 等待回應 | 等你回答或輸入；缺省開啟 |
| `NOTIFY_FAILURE` | 異常停止 | 目前僅 Antigravity 提供訊號；缺省開啟 |

分類不代表每個工具都有所有事件。選單已無「既有操作提醒」與兩個 Codex 專用項目。

### 舊設定相容

- 仍讀取舊鍵 `NOTIFY_ACTION_REQUIRED`、`NOTIFY_CODEX_HUMAN_APPROVAL`、`NOTIFY_CODEX_USER_INPUT`：授權來自 ACTION_REQUIRED + CODEX_HUMAN_APPROVAL，等待回應來自 ACTION_REQUIRED + CODEX_USER_INPUT。同一來源內，任一為 `true` 即開、否則任一為 `false` 即關、否則未定義。
- 解析順序：環境變數新鍵 → 環境變數舊鍵 → 設定檔新鍵 → 設定檔舊鍵 → 預設。只有精確的 `true`／`false` 算數。`handoff-route` 在環境變數設定 `NOTIFY_ACTION_REQUIRED=true` 仍有效。
- `NOTIFY_LEVEL` 保留 `all` 與 `attention_required`（舊名 `notify_only`），只決定工作結束的預設。
- 儲存分類選單時，一次原子寫入四個新鍵並移除三個舊鍵（mode 600，其他鍵不動）。`update.sh notify_level` 與選單的 all／attention_required 快速預設只寫 `NOTIFY_LEVEL` 與 `NOTIFY_COMPLETION`。
- 已接受的取捨：`ACTION_REQUIRED=true` 加 `CODEX_HUMAN_APPROVAL=false` 現在等於授權開啟，Codex 會送延遲授權通知；不要的話把「授權要求」關掉。

### 授權延遲通知

`NOTIFY_AUTHORIZATION_DELAY_SECONDS` 預設 30；`0` 立即通知；非數字或負值退回 30。只有等待在延遲後仍未解除才通知，同一段連續等待最多一次。

| 工具 | 起點 | 解除／靜默 |
|---|---|---|
| Claude Code | `Notification` 且 `notification_type=permission_prompt`；等待身分為 `transcript_path` 中最後一個沒有對應 `tool_result` 的 `tool_use` | 延遲前出現對應 `tool_result` 即靜默；紀錄不可讀則送「無法確認」通知；`Stop` 清除等待 |
| Antigravity | 狀態列回報 `tool_confirmation_pending` 為 true | 沒有請求識別碼：狀態列回報 false 或該對話 `Stop` 即清除（Telegram 關閉時亦然）；狀態列輸出不變 |
| Codex | `PermissionRequest` 只啟動 `codex-wait.py`，即使延遲為 0 也不在當下送出 | 見下 |

Codex 細節：

- daemon 可查詢該 Session：`waitingOnApproval` 持續超過延遲才送確認通知；旗標消失即重設；延遲 0 時第一次看到旗標就送。
  只有載入在 daemon 中的 Session（例如桌面 App 開的）才有這條路徑。
- 無法查詢執行狀態：daemon 連不上，或 daemon 連得上、但第一次查詢就回報該 Session `notLoaded`。
  **以終端機 `codex` 啟動的 Session 一律屬於後者**（2026-11-18 實測：人工等待核准的 40 秒間仍是 `notLoaded`、沒有旗標），
  所以終端機的 Codex 只會收到「無法確認」的通知，不會有確認的通知。看過 `active` 之後才變成 `notLoaded`，視為回合結束。
  檢查器保留請求到延遲過後，再讀 Codex session 紀錄（payload 的 `transcript_path`，否則 `$CODEX_HOME/sessions/*/*/*/rollout-*-<session_id>.jsonl`）。該呼叫已有 `*_call_output`，或出現 `task_complete`／`turn_aborted`，即靜默；否則或紀錄不可讀，送「無法確認」通知。已核准但執行超過延遲的命令也會收到「無法確認」通知（已接受的取捨）。同一輪稍後的新請求有自己的延遲。
- 同步結構化問題看到旗標即通知；非同步問題行為不變。

沒有識別碼的等待（Antigravity，或 Claude 找不到未完成的工具呼叫）會合併：重複的起點訊號不重啟延遲、不重送。尚未通知的等待不會過期。已通知的等待，只有在通知後至少 `NOTIFY_AUTHORIZATION_REARM_SECONDS`（預設 600，非數字或負值退回 600，自通知時起算）才由新起點重新武裝；時鐘為整秒解析度，不會提早，最多晚一秒。解除證據會立即重新武裝。已知限制：沒有解除訊號時，緊接著的第二次等待會被併入第一次。

機制：標記檔為 `~/.config/ai-notify/state/claude-<session>.pending` 與 `antigravity-<session>.pending`，各有 `<marker>.lock` 目錄記錄擁有者 PID；每段等待啟動一個背景檢查，只在標記仍帶有自己的等待身分時才動作。通知只含工具、專案、session 標籤、時間與通用工具標籤，不含命令、參數、提示或 transcript。

### Claude Notification 類型

- `permission_prompt` → 授權（延遲）。
- `idle_prompt`、`agent_needs_input`、`elicitation_dialog`、`elicitation_url_dialog`、無類型 → 等待回應（立即送出）。
- 其他類型（`auth_success`、`agent_completed` 等）→ 不送。

### Antigravity 結束原因

只在 `fullyIdle` 為 true 時處理 `terminationReason`（不分大小寫）：`NO_TOOL_CALL` 與舊值 `model_stop` → Task Complete；`USER_CANCELED` → 不通知；其餘為 Task Stopped，原因標籤：`ERROR`「error」、`MAX_INVOCATIONS`「max invocations reached」、`MAX_FORCED_INVOCATIONS`「max forced invocations reached」、`MAX_TOKEN_BUDGET_EXCEEDED`「token budget exceeded」、`TERMINAL_STEP_TYPE`「terminal step」、`TERMINAL_CUSTOM_HOOK`「stopped by a custom hook」、`INJECTED_RESPONSE`「injected response」、舊值 `max_steps_exceeded`「max steps exceeded」，其他「execution stopped」。不附原始錯誤文字；對應表在 `scripts/notify/telegram/events.tsv`。

### 範本與事件表

`events.tsv` 欄位為 key、category、template、reason label；`<prefix>:*` 為後備；category `none` 表示不送。表中沒有的事件維持通用的「AI CLI Event」訊息。

內建範本（`scripts/notify/telegram/templates/`）：completion、stopped、question、action-required、generic、authorization、authorization-unconfirmed，部署到 `~/.config/ai-notify/hooks/templates/`，每次更新覆寫。要自訂，在 `~/.config/ai-notify/templates/<name>.md` 放同名檔；檔案不存在、為空或不可讀時退回內建範本。

可用佔位符：`{title_suffix} {tool} {project} {time} {tag} {message} {reason} {request_tool} {delay}`。值會依 Telegram legacy Markdown 跳脫（`_ * \` [`）；整行只有佔位符且全部為空時，該行移除；未知佔位符原樣保留。不支援 eval、條件或迴圈。

工作結束、停止與等待訊息的內建文字不變。新增文字：授權為「🔴 **等待你授權** … `{tool} 等待你授權超過 {delay} 秒（{request_tool}）`」；無法確認為「🟡 **授權狀態無法確認** … `{tool} 可能在等待授權，無法確認（已超過 {delay} 秒沒有結果，{request_tool}）`」。

### 狀態清理

每次 Codex 檢查啟動時，會移除超過 7 天且鎖已釋放的通知自有狀態：`codex-<24 hex>.{lock,json,request.json}`（一起移除，且僅在沒有檢查器持有 flock 時）、以及鎖目錄沒有存活 PID 的 `claude-*.pending`／`antigravity-*.pending`。其他檔案不動。

### Codex 按需檢查

```text
PermissionRequest hook
  └─ 授權要求或等待回應開啟 → 啟動按需檢查器 → 依延遲規則通知（見上節）

同步結構化問題 PreToolUse hook → 同一個按需檢查流程
非同步結構化問題 PostToolUse hook → accepted=true → 等待你回答通知（不需 daemon）
```

PermissionRequest 本身不會當下送出通知，只啟動檢查器；授權要求與等待回應都關閉時完全不檢查。標題分別是 `🔴 等待你授權` 與 `🟡 Waiting for Your Response`；問題通知內文為 `Codex has a question awaiting your response.`。`request_user_input_async` 不產生 daemon 等待旗標，改在工具成功送出題目後通知；這表示有題目待回覆，Codex 仍可繼續工作。

啟用授權要求或等待回應後，安裝／更新會部署 Python 3 檢查器與專用 venv 中的 `websocket-client`，不修改全域 Python、不安裝 LaunchAgent。hook 返回後，暫時檢查器透過 `codex app-server proxy` 唯讀觀察既有 daemon；同一 session 共用程序，工作輪次完成／取消後退出。依賴安裝失敗會顯示原因，既有通知仍可使用；以 `fix-hooks` 重試。

支援範圍與限制：

- 確認授權與同步問題需要既有本機 daemon 能查詢該 Session；不啟動 daemon。終端機啟動的 Codex 不在 daemon 中，同步問題的旗標也看不到。
  無法查詢時，授權改讀 session 紀錄，無法確認則送「授權狀態無法確認」。非同步問題依原生成功事件通知，不需 daemon。
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

- **STATUS_ICON**: `🟢` (Task Complete) | `🟡` (Action Required / Waiting for Your Response / 授權狀態無法確認) | `🔴` (Task Stopped / 等待你授權) | `🤖` (Generic Event)
- **TITLE**: `Task Complete` | `Action Required` | `Task Stopped`
- **SESSION** *(optional)*: shown when session info is available
  - UUID `session_id` (Claude) → `#<first 8 chars>` e.g. `(#a1b2c3d4)`
  - Non-UUID `sessionId` (Copilot) → used as-is e.g. `(copilot-xyz)`
  - `GITHUB_COPILOT_SESSION_ID` env var → `#<first 8 chars>`
  - No session info → title has no parentheses
- **MESSAGE Fallback**:
  - Task Complete: `Process finished successfully`
  - Action Required: `Waiting for user interaction...`

Authorization notices include only a generic tool label (the requesting tool name). Raw commands,
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

## 更新與回復

`update.sh status` 多一段「授權延遲與範本」：`授權延遲：N 秒`，以及 `使用者範本：<名稱>` 或「無」。

升級：執行 `bash scripts/notify/telegram/update.sh`（或 `fix-hooks`）重新部署即可。hook 註冊不變，Codex 不需重新信任；既有設定檔不需修改。回復到前一版 hook 時重新部署舊版；選單儲存已移除的舊鍵，需在舊版選單重新設定。

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
- Codex 按需程序（合作式停止）、自有狀態、檢查器與專用 venv；僅移除內建範本與事件表，`~/.config/ai-notify/templates/` 的使用者範本保留
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
3. 用 `update.sh types` 檢查該類型開關；缺省時工作結束才沿用 `NOTIFY_LEVEL`。授權通知有延遲（預設 30 秒），先等過 `NOTIFY_AUTHORIZATION_DELAY_SECONDS`
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

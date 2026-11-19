---
type: Playbook
title: Telegram Notify Hook Setup
description: Install and operate Telegram notifications across supported AI CLIs.
tags: [telegram, notifications, hooks, codex, antigravity, pi]
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-19T17:44:06+08:00 }
---

# Telegram Notify Hook — Quick Setup

Get Telegram notifications when Claude Code, Codex, Antigravity CLI, Pi, or
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
7. Installing the Pi extension when Pi is detected (open Pi sessions need `/reload`)
8. Optionally registering repository-local Copilot hooks

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
| Pi extension (when Pi is detected) | `${PI_CODING_AGENT_DIR:-~/.pi/agent}/extensions/ai-notify.ts`（first line is the ownership marker; see [Pi](/docs/hooks/pi-hooks.md)） |
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

## 架構與流程圖

完整事件資料流與 30 秒延遲授權狀態機請參閱：
- [AI CLI 通知架構與延遲授權流程圖 (SVG)](../diagrams/notify-architecture.svg)
- [Notify Hooks Architecture 詳細架構手冊](/docs/notify/architecture.md)

---

## 通知類型與設定

```bash
bash scripts/notify/telegram/update.sh types
```

使用編號切換、`h` 查看說明、`s` 顯示儲存摘要並確認，或 `q` 放棄。EOF 也會取消，取消不寫入設定。安裝與更新共用同一套畫面，Bot Token 不列入摘要。

### 四大核心分類開關

| 設定鍵 | 選單名稱 | 說明／預設 |
|---|---|---|
| `NOTIFY_COMPLETION` | 工作結束 | 任務完成；缺省沿用 `NOTIFY_LEVEL`（`attention_required` 為關閉，`all` 為開啟） |
| `NOTIFY_AUTHORIZATION` | 授權要求 | 等你核准工具或越界存取；套用 30 秒延遲確認，缺省開啟 |
| `NOTIFY_USER_INPUT` | 等待回應 | 等你回答問題或輸入；立即通知，缺省開啟 |
| `NOTIFY_FAILURE` | 異常停止 | 工具異常中斷或錯誤；缺省開啟 |

### 三大交接迴圈（Agent Handoff）進度開關

| 設定鍵 | 選單名稱 | 說明／預設 |
|---|---|---|
| `NOTIFY_HANDOFF_IMPLEMENT` | 實作交件 | 實作者完成實作並提交交件單；缺省開啟 |
| `NOTIFY_HANDOFF_REVIEW` | 審查結果 | 審查者提出退回修正或通過結論；缺省開啟 |
| `NOTIFY_HANDOFF_FINISH` | 收尾完成 | 收尾角色完成封存、更新文件與 commit；缺省開啟 |

> **🚨 停點安全保護（不可關閉）**：
> 當交接迴圈因任何原因停下需要人類處理時（如 blocked、達輪數上限、worktree 不乾淨、或審查通過等候手動執行 `handoff-finish`），系統會強制發送 `handoff-action-required` 通知，**此類停點訊號不可被關閉**，確保迴圈絕不靜默掛起。
> 交件單通知會自動標記 Agent 身分，格式如：`Agent Handoff (Claude / claude-opus-5-5 / high)`。

### 交接迴圈通知

`scripts/handoff/handoff-route`（交接迴圈的 Stop hook）以 `handoff` 事件送出結構化資料（kind、change、round、verdict、commit、next、detail、agent、session_id、cwd），由本 hook 查表、套開關與範本。選單第 5–7 項：

| 設定鍵 | 選單名稱 | 範本 | 內容 |
|---|---|---|---|
| `NOTIFY_HANDOFF_IMPLEMENT` | 交件單實作完成 | `handoff-implement` | 實作交件已交給審查者 |
| `NOTIFY_HANDOFF_REVIEW` | 交件單每輪審查 | `handoff-review` | 退回已交給實作者，或通過且自動收尾 |
| `NOTIFY_HANDOFF_FINISH` | 交件單收尾 | `handoff-finish` | 收尾完成 |
| （無） | 需要你處理 | `handoff-attention` | 迴圈停下等你；Telegram 啟用時一律送出 |

- 三個鍵缺少時為開，不受 `NOTIFY_LEVEL` 影響；儲存選單時與四個分類一起寫入。
- 需要你處理不受任何開關或 `NOTIFY_LEVEL` 影響；對照表列或範本缺少時以內建文字送出。
- 標題為 `Agent Handoff (<工具> / <模型> / <effort>)` 加上 Session 標籤，取不到的部分省略。
- 新版 `telegram-notify.sh` 含一行 `# ai-notify-capability: handoff-events`，交接端以此判斷是否送 `handoff` 事件；沒有這一行（舊版或已回退）時，需要你處理改走一般通知（`notification` 事件加 `NOTIFY_ACTION_REQUIRED=true`），進度通知不送。

### 舊設定相容

- 仍讀取舊鍵 `NOTIFY_ACTION_REQUIRED`、`NOTIFY_CODEX_HUMAN_APPROVAL`、`NOTIFY_CODEX_USER_INPUT`：授權來自 ACTION_REQUIRED + CODEX_HUMAN_APPROVAL，等待回應來自 ACTION_REQUIRED + CODEX_USER_INPUT。同一來源內，任一為 `true` 即開、否則任一為 `false` 即關、否則未定義。
- 解析順序：環境變數新鍵 → 環境變數舊鍵 → 設定檔新鍵 → 設定檔舊鍵 → 預設。只有精確的 `true`／`false` 算數。舊版 `handoff-route` 在環境變數設定 `NOTIFY_ACTION_REQUIRED=true` 仍有效；新版遇到不支援交件單事件的通知腳本時也走這條路徑。
- `NOTIFY_LEVEL` 保留 `all` 與 `attention_required`（舊名 `notify_only`），只決定工作結束的預設。
- 儲存分類選單時，一次原子寫入四個新鍵與三個交件單鍵並移除三個舊鍵（mode 600，其他鍵不動）。`update.sh notify_level` 與選單的 all／attention_required 快速預設只寫 `NOTIFY_LEVEL` 與 `NOTIFY_COMPLETION`。
- 已接受的取捨：`ACTION_REQUIRED=true` 加 `CODEX_HUMAN_APPROVAL=false` 現在等於授權開啟，Codex 會送延遲授權通知；不要的話把「授權要求」關掉。

### 授權延遲通知

`NOTIFY_AUTHORIZATION_DELAY_SECONDS` 預設 30；`0` 立即通知；非數字或負值退回 30。只有等待在延遲後仍未解除才通知，同一段連續等待最多一次。

| 工具 | 起點 | 解除／靜默 |
|---|---|---|
| Claude Code | `Notification` 且 `notification_type=permission_prompt`；等待身分為 `transcript_path` 中最後一個沒有對應 `tool_result` 的 `tool_use` | 延遲前出現對應 `tool_result` 即靜默；紀錄不可讀則送「無法確認」通知；`Stop` 清除等待 |
| Antigravity | 狀態列回報 `tool_confirmation_pending` 為 true | 沒有請求識別碼：狀態列不再回報 true（1.5.10 在核准或拒絕後直接省略該欄位）或該對話 `Stop` 即清除（Telegram 關閉時亦然）；取消與拒絕不會觸發 `Stop`；狀態列輸出不變 |
| Codex | `PermissionRequest` 只啟動 `codex-wait.py`，即使延遲為 0 也不在當下送出 | 見下 |

Codex 細節：

- daemon 可查詢該 Session：`waitingOnApproval` 持續超過延遲才送確認通知；旗標消失即重設；延遲 0 時第一次看到旗標就送。
  只有載入在 daemon 中的 Session（例如桌面 App 開的）才有這條路徑。
- 無法查詢執行狀態：daemon 連不上，或 daemon 連得上、但第一次查詢就回報該 Session `notLoaded`。
  **以終端機 `codex` 啟動的 Session 一律屬於後者**（2026-11-18 實測：人工等待核准的 40 秒間仍是 `notLoaded`、沒有旗標），
  所以終端機的 Codex 只會收到「無法確認」的通知，不會有確認的通知。看過 `active` 之後才變成 `notLoaded`，視為回合結束。
  檢查器保留請求到延遲過後，再讀 Codex session 紀錄（payload 的 `transcript_path`，否則 `$CODEX_HOME/sessions/*/*/*/rollout-*-<session_id>.jsonl`）。該呼叫已有 `*_call_output`，或出現 `task_complete`／`turn_aborted`，即靜默；否則或紀錄不可讀，送「無法確認」通知。已核准但執行超過延遲的命令也會收到「無法確認」通知（已接受的取捨）。同一輪稍後的新請求有自己的延遲。
- 同步結構化問題看到旗標即通知；非同步問題行為不變。

沒有識別碼的等待（Antigravity，或 Claude 找不到未完成的工具呼叫）會合併：重複的起點訊號不重啟延遲、不重送。尚未通知的等待不會過期。已通知的等待，只有在通知後至少 `NOTIFY_AUTHORIZATION_REARM_SECONDS`（預設 600，非數字或負值退回 600，自通知時起算）才由新起點重新武裝；時鐘為整秒解析度，最多可能提早不到一秒。解除證據會立即重新武裝。已知限制：沒有解除訊號時，緊接著的第二次等待會被併入第一次。

機制：標記檔為 `~/.config/ai-notify/state/claude-<session>.pending` 與 `antigravity-<session>.pending`，各有 `<marker>.lock` 目錄記錄擁有者 PID；每段等待啟動一個背景檢查，只在標記仍帶有自己的等待身分時才動作。標記只在持有鎖時修改：清除的目標在解除訊號到達時就固定；若鎖被存活的程序持有，改由背景等鎖，且只清除該段等待，不會刪掉期間換上的新等待。延遲為 0 時同樣先判斷：紀錄讀不到送「Approval Status Unknown」，已解除則不送。授權通知不帶 `{message}`、`{reason}`，使用者範本也一樣。Codex 無法查詢時，同一段等待在同一回合只通知一次，而且只依紀錄內容判斷：紀錄讀不到不算任何證據（已通知過就不再通知）；讀得到且沒有未完成的呼叫才算解除；當初在讀不到時通知的等待，依通知當時的紀錄大小判斷之後的呼叫是原等待（只補身分）或新請求（再通知）。每個請求只依自己的期限結算自己的呼叫；不同的呼叫 ID 一律是新的等待；授權通知關閉時不會被記成已通知。通知只含工具、專案、session 標籤、時間與通用工具標籤，不含命令、參數、提示或 transcript。

### Claude Notification 類型

- `permission_prompt` → 授權（延遲）。例外：紀錄中等待的工具是 `AskUserQuestion` 時屬於提問，立即送出「Waiting for Your Response」，
  受「等待回應」開關控制。Claude 約在提問出現 6 秒後才發這則通知（2026-11-18 真實驗收發現）。
- `idle_prompt`、`agent_needs_input`、`elicitation_dialog`、`elicitation_url_dialog`、無類型 → 等待回應（立即送出）。
- 其他類型（`auth_success`、`agent_completed` 等）→ 不送。

### Antigravity 結束原因

只在 `fullyIdle` 為 true 時處理 `terminationReason`（不分大小寫）：`NO_TOOL_CALL` 與舊值 `model_stop` → Task Complete；`USER_CANCELED` → 不通知；其餘為 Task Stopped，原因標籤：`ERROR`「error」、`MAX_INVOCATIONS`「max invocations reached」、`MAX_FORCED_INVOCATIONS`「max forced invocations reached」、`MAX_TOKEN_BUDGET_EXCEEDED`「token budget exceeded」、`TERMINAL_STEP_TYPE`「terminal step」、`TERMINAL_CUSTOM_HOOK`「stopped by a custom hook」、`INJECTED_RESPONSE`「injected response」、舊值 `max_steps_exceeded`「max steps exceeded」，其他「execution stopped」。不附原始錯誤文字；對應表在 `scripts/notify/telegram/events.tsv`。

### Pi 結束原因與等待回應

Pi extension 只送自己算出的 `stop_reason`：`pi-stop:completed` → Task Complete；`pi-stop:error` → Task Stopped，原因標籤「error」；`pi-stop:aborted` 與未列出的值 → 不通知；`pi-question`（執行中開啟 UI 提示）→ Waiting for Your Response。三個分類開關與 `NOTIFY_LEVEL` 照常作用；不附錯誤原文或提示內容。事件來源與通知範圍見 [Pi Extension Integration](/docs/hooks/pi-hooks.md)。

### 範本與事件表

`events.tsv` 欄位為 key、category、template、reason label；`<prefix>:*` 為後備；category `none` 表示不送。表中沒有的事件維持通用的「AI CLI Event」訊息。

內建範本（`scripts/notify/telegram/templates/`）：completion、stopped、question、action-required、generic、authorization、authorization-unconfirmed、handoff-implement、handoff-review、handoff-finish、handoff-attention，部署到 `~/.config/ai-notify/hooks/templates/`，每次更新覆寫。要自訂，在 `~/.config/ai-notify/templates/<name>.md` 放同名檔；檔案不存在、為空或不可讀時退回內建範本。

可用佔位符：`{title_suffix} {tool} {model_suffix} {model_family_suffix} {project} {time} {tag} {message} {reason} {request_tool} {delay}`；交件單範本另有 `{agent} {change} {round} {verdict} {commit} {next} {detail}`（`{verdict}` 顯示為「🔁 審查退回」或「🟢 審查通過」）。值會依 Telegram legacy Markdown 跳脫（`_ * \` [`）；整行只有佔位符且全部為空時，該行移除；未知佔位符原樣保留。不支援 eval、條件或迴圈。

#### 工具行的 model

含 `{tool}` 的 7 個內建範本（completion、question、stopped、action-required、authorization、authorization-unconfirmed、generic）工具行為 `🤖 {tool}{model_suffix}`；交件單範本不顯示。拿得到 model 時例如 `🤖 Claude Code (Opus 5.5)`、`🤖 Codex (gpt-6.1-terra)`、`🤖 Pi (gpt-6.1-sol)`；拿不到時只顯示工具名稱，沒有空括號。

- 來源：hook payload 的 `model` 字串優先（Codex hook 輸入必填；Pi 由 extension 帶入 `ctx.model.id`；其他工具有就用）。沒有且工具為 Claude Code 時，讀 `transcript_path` 最後 400 行中最後一則 assistant 紀錄的 `message.model`，略過 `<` 開頭的值（例如 `<synthetic>`）。這個紀錄格式未載於 Claude Code 官方文件，且可能落後一輪：剛用 `/model` 切換後的第一則通知可能顯示前一個 model。
- 清理：去掉結尾的 `[...]`（例如 `[1m]`），只保留英數與 `._:/-`，最多 64 字元；清理後為空視同沒有 model。
- 顯示：Claude ID 顯示為家族名加版本（`claude-opus-5-5` → `Opus 5.5`、`claude-sonnet-4-5-20250929` → `Sonnet 4.5`、`claude-opus-4-20250514` → `Opus 4`、`claude-3-5-sonnet-20241022` → `Sonnet 3.5`），別名 `opus`／`sonnet`／`haiku`／`fable` 只顯示家族名；其他 ID 原樣顯示。
- `{model_suffix}` 含版本（` (Opus 5.5)`），`{model_family_suffix}` 不含版本（` (Opus)`；非 Claude ID 與 `{model_suffix}` 相同）；沒有 model 時兩者都是空字串。
- 使用者自訂範本不會自動加上 model，要自己加入。不想顯示版本時，在 `~/.config/ai-notify/templates/completion.md` 等檔案把工具行寫成：

  ```text
  🤖 {tool}{model_family_suffix}
  ```

  Claude Code 用 `claude-opus-5-5` 時顯示 `🤖 Claude Code (Opus)`。

工作結束、停止與等待訊息的內建文字不變。新增文字：授權為「🔴 **Waiting for Your Approval** … `{tool} has been waiting for your approval for over {delay} seconds ({request_tool})`」；無法確認為「🟡 **Approval Status Unknown** … `{tool} may be waiting for approval, but this could not be confirmed (no result after {delay} seconds, {request_tool})`」。兩個授權範本於 2026-11-18 改為英文。

### 狀態清理

每次 Codex 檢查啟動時，會移除超過 7 天且鎖已釋放的通知自有狀態：`codex-<24 hex>.{lock,json,request.json}`（一起移除，且僅在沒有檢查器持有 flock 時）、以及鎖目錄沒有存活 PID 的 `claude-*.pending`／`antigravity-*.pending`。其他檔案不動。

### Codex 按需檢查

```text
PermissionRequest hook
  └─ 授權要求或等待回應開啟 → 啟動按需檢查器 → 依延遲規則通知（見上節）

同步結構化問題 PreToolUse hook → 同一個按需檢查流程
非同步結構化問題 PostToolUse hook → accepted=true → 等待你回答通知（不需 daemon）
```

PermissionRequest 本身不會當下送出通知，只啟動檢查器；授權要求與等待回應都關閉時完全不檢查。標題分別是 `🔴 Waiting for Your Approval`（無法確認時為 `🟡 Approval Status Unknown`）與 `🟡 Waiting for Your Response`；問題通知內文為 `Codex has a question awaiting your response.`。`request_user_input_async` 不產生 daemon 等待旗標，改在工具成功送出題目後通知；這表示有題目待回覆，Codex 仍可繼續工作。

啟用授權要求或等待回應後，安裝／更新會部署 Python 3 檢查器與專用 venv 中的 `websocket-client`，不修改全域 Python、不安裝 LaunchAgent。hook 返回後，暫時檢查器透過 `codex app-server proxy` 唯讀觀察既有 daemon；同一 session 共用程序，工作輪次完成／取消後退出。依賴安裝失敗會顯示原因，既有通知仍可使用；以 `fix-hooks` 重試。

支援範圍與限制：

- 確認授權與同步問題需要既有本機 daemon 能查詢該 Session；不啟動 daemon。終端機啟動的 Codex 不在 daemon 中，同步問題的旗標也看不到。
  無法查詢時，授權改讀 session 紀錄，無法確認則送「Approval Status Unknown」。非同步問題依原生成功事件通知，不需 daemon。
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

🤖 {TOOL_NAME}{MODEL}
📂 {PROJECT_NAME}
⏰ {TIMESTAMP}

{MESSAGE} #{HOOK_EVENT_NAME}
```

- **STATUS_ICON**: `🟢` (Task Complete) | `🟡` (Action Required / Waiting for Your Response / Approval Status Unknown) | `🔴` (Task Stopped / Waiting for Your Approval) | `🤖` (Generic Event)
- **TITLE**: `Task Complete` | `Action Required` | `Task Stopped`
- **MODEL** *(optional)*: ` (<model>)` when the model is known, e.g. ` (Opus 5.5)`; see 工具行的 model above
- **SESSION** *(optional)*: shown when session info is available
  - UUID `session_id` (Claude) → `#<first 8 chars>` e.g. `(#a1b2c3d4)`
  - Non-UUID `sessionId` (Copilot) → used as-is e.g. `(copilot-xyz)`
  - `GITHUB_COPILOT_SESSION_ID` env var → `#<first 8 chars>`
  - No session info → title has no parentheses
- **MESSAGE Fallback**:
  - Task Complete: `Process finished successfully`
  - Action Required: `Waiting for user interaction...`

Authorization notices include only a generic tool label (the requesting tool name). Raw commands,
arguments, prompts, transcript paths, Antigravity raw error text, and Pi prompt or error text are never
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

# Proposal

## Why

Telegram 通知目前只接 Claude Code、Codex、Antigravity 與 Copilot。使用者也用 Pi 開發，但 Pi 沒有可登記指令的 hook 設定檔，
只有 extension 事件，所以在 Pi 工作時收不到工作結束、等待回應或異常停止的通知。

交接迴圈的通知（實作完成、每輪審查、收尾、需要你處理）由 `handoff-route` 自己送出，已在 main；Pi 角色要觸發 `handoff-route`
屬於 `add-pi-handoff-agent`，不在本 change。

## What Changes

- **Pi 通知 extension**：新增 `scripts/notify/pi/ai-notify.ts`，安裝到 `~/.pi/agent/extensions/ai-notify.ts`，把 Pi 事件轉給既有的
  `telegram-notify.sh`，工具名稱為 `Pi`、Session 標籤取 Pi 的 Session ID：
  - `agent_settled`、未中止、最後一則回覆不是錯誤 → 工作結束（`completion`）。
  - `agent_settled`、最後一則回覆以錯誤結束 → 異常停止（`failure`），不含錯誤原文。
  - `agent_settled`、使用者中止（例如 Esc）→ 不通知。
  - `ui_prompt_start`（例如 pstack `ask_user_question` 的選單）→ 等待回應（`user_input`），立即送出，同一段等待只送一次。
- **只通知互動的主 session**：沒有 UI 的執行（`pi -p`、JSON、RPC 模式）與 pstack subagent（帶 `PI_SUBAGENT_PARENT_SESSION`）不通知。
- **不影響 Pi**：通知在背景執行，任何錯誤或 Telegram 失敗都不阻擋、不改變 Pi 的流程。
- **事件表與通知腳本**：`events.tsv` 新增 Pi 事件；`hook.sh` 依 payload 的停止原因組出事件鍵（與 Antigravity 相同方式）。
- **安裝與移除**：偵測到 Pi 時，通知 installer、修復與移除流程管理這個 extension 檔案；只移除帶有本專案擁有標記的檔案。
  `status` 列出 Pi 的覆蓋狀態。
- 不支援授權要求：Pi 本身沒有授權機制。只用文字提問、沒有開 UI 的情況不偵測（與 Codex 相同）。
- **通知顯示 model（所有工具）**：只顯示 `🤖 Pi` 分不出 Pi 用的是哪個 model，所以工具行在拿得到 model 時補上，例如
  `🤖 Claude Code (Opus 5.5)`、`🤖 Codex (gpt-6.1-terra)`、`🤖 Pi (Opus 5.5)`、`🤖 Pi (gpt-6.1-sol)`。
  - 來源：Codex 取 hook payload 的 `model`；Pi 由 extension 帶入 `ctx.model.id`；Claude Code 的 Stop payload 沒有 model，
    改讀 Session 紀錄中最後一則 assistant 訊息的 model；其他工具的 payload 有 `model` 就用。拿不到時只顯示工具名稱，與現在相同。
  - Claude model 顯示為家族名加版本（`claude-opus-5-5` → `Opus 5.5`）；其他 model 顯示原始 ID。
  - 範本新增 `{model_suffix}`（含版本，例如 ` (Opus 5.5)`）與 `{model_family_suffix}`（不含版本，例如 ` (Opus)`），
    內建範本的工具行改為 `🤖 {tool}{model_suffix}`；不想顯示版本時，在使用者範本改用 `{model_family_suffix}` 即可。

支援的 AI CLI：Claude Code、Codex、Antigravity、Copilot CLI（行為不變）、Pi（新增；以 extension 取代 hook 設定檔）。

驗收條件：

- 在 Pi TUI 中完成一輪對話，收到一則 `Pi` 的工作結束通知，標題帶 Pi Session 標籤。
- pstack `ask_user_question` 跳出選單時，立即收到一則等待回應通知；同一個選單不重複通知。
- Pi 重試後仍以錯誤結束，收到異常停止通知，內容沒有錯誤原文。
- 按 Esc 中止、`pi -p` 執行、pstack subagent 結束，都不通知。
- 三個通知分類開關與 `NOTIFY_LEVEL` 對 Pi 事件的效果與其他工具相同。
- 安裝兩次只有一份 extension；移除後檔案消失；使用者自己的同名但沒有擁有標記的檔案不被覆寫或刪除。
- Telegram 停用或失敗時 Pi 照常運作。
- 工具行帶 model：Claude Code 顯示 `Claude Code (Opus 5.5)` 這類家族名加版本、Codex 與 Pi 用 GPT 時顯示原始 ID；
  拿不到 model 時只顯示工具名稱，沒有空括號；使用者範本改用 `{model_family_suffix}` 後只顯示 `(Opus)`。

## Capabilities

### New Capabilities

- `pi-notify-hook`: Pi extension 的事件對應、通知範圍（互動主 session）、失敗隔離，以及 extension 檔案的安裝與移除。

### Modified Capabilities

- `telegram-notify-hook`: registry 在偵測到 Pi 時安裝 extension、以 `Pi` 作為工具名稱；生命週期管理與 status 涵蓋 Pi；隱私規則涵蓋 Pi 通知；
  所有工具的通知在拿得到 model 時於工具行顯示 model，範本提供含版本與不含版本兩個欄位。

## Impact

- 程式：新增 `scripts/notify/pi/ai-notify.ts`；修改 `scripts/notify/telegram/events.tsv`、`scripts/notify/telegram/hook.sh`、
  `scripts/notify/lib/registry.sh`、`scripts/notify/telegram/update.sh`（status）、`scripts/notify/telegram/uninstall.sh`；
  model 顯示修改 `scripts/notify/lib/template.sh`（新增兩個參數）與 `scripts/notify/telegram/templates/` 中含 `{tool}` 的 7 個範本。
- 使用者自訂範本（`~/.config/ai-notify/templates/`）不會自動加上 model，要自己加入 `{model_suffix}`。
- 測試：`scripts/notify/telegram/test.sh`（dry-run 與暫時 HOME 的安裝測試）。
- 文件：`docs/hooks/index.md`（支援矩陣）、新增 `docs/hooks/pi-hooks.md`、`docs/notify/telegram.md`、`scripts/notify/README.md`。
- 使用者環境：`~/.pi/agent/extensions/` 新增一個檔案；已開啟的 Pi session 需 `/reload` 或重開。
- 依賴：Pi 的 extension 事件 `agent_end`、`agent_settled`、`ui_prompt_start` 與 `ctx.model`（Pi 1.5.2 文件）；Codex hook 輸入的
  `model` 欄位（openai/codex `codex-rs/hooks/schema/generated/*.command.input.schema.json` 列為必填）；Claude Code Session 紀錄中
  assistant 訊息的 `message.model`（官方文件未記載，見 design.md 決策 6）。

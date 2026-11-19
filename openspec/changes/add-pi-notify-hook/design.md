# Design

## Context

動機見 proposal.md；行為以 specs 為準。影響做法的現況：

- 通知端是單一部署腳本 `~/.config/ai-notify/hooks/telegram-notify.sh`：第一個參數是事件、第二個是工具名稱，stdin 為 JSON；
  `events.tsv` 把事件鍵對應到分類與範本；`hook.sh` 從 JSON 讀 `session_id`、`cwd`。Antigravity 的停止事件以
  `antigravity-stop:<原因>` 查表，未列出的原因有萬用列。
- `registry.sh` 的 `register_hook` 依偵測結果為 Claude Code、Codex、Antigravity 寫入各自的設定檔；`unregister_hook` 只移除自己的項目。
- Pi 沒有可登記指令的 hook 設定檔，只能用 extension：放在 `~/.pi/agent/extensions/*.ts` 會自動載入（`PI_CODING_AGENT_DIR`
  可改變根目錄）。本機已有 `herdr-agent-state.ts` 以同樣方式回報 Pi 狀態，可作為先例。
- Pi 1.5.2 extension 事件（`docs/extensions.md`）：
  - `agent_end` 帶本次低階執行的 `messages`；之後 Pi 仍可能重試、壓縮後重試或接續佇列訊息。
  - `agent_settled` 是最終停止，帶 `aborted`。
  - `ui_prompt_start`／`ui_prompt_end` 包住 `ctx.ui.select/confirm/input/editor/custom`，重疊的提示合併成一段。pstack 的
    `ask_user_question` 使用 `ui.select`。
  - assistant 訊息的 `stopReason` 有 `stop`、`length`、`toolUse`、`error`、`aborted` 等值。
  - `pi.exec` 不能傳 stdin；extension 可直接使用 Node 的 `child_process`。
- pstack 的 subagent 是 `pi --mode rpc` 子程序，環境帶 `PI_SUBAGENT_PARENT_SESSION`。
- 範本只做 `{name}` 取代（`scripts/notify/lib/template.sh`），沒有條件判斷；整行都是空 placeholder 才會被刪。`{title_suffix}` 的值
  自帶前導空白與括號，空值時整段消失。工具行目前是 `🤖 {tool}`，只有工具名稱。
- model 的取得方式（2026-11-19 查證）：
  - Codex：hook 輸入的 `model` 在 Stop、PermissionRequest、UserPromptSubmit 的 schema 都列為必填
    （openai/codex `codex-rs/hooks/schema/generated/*.command.input.schema.json`）。
  - Pi：extension 可讀 `ctx.model`（目前使用的 model，含 `id`、`provider`），換 model 時觸發 `model_select`（Pi 1.5.2 `docs/extensions.md`）。
  - Claude Code：官方文件寫明只有 SessionStart 可能帶 `model`，且 `/clear` 或還原 Session 後可能省略；換 model 由
    PostModelSwitch 的 `to_model` 通知；沒有 `$CLAUDE_MODEL`；`transcript_path` 可能落後最新一輪
    （https://code.claude.com/docs/en/hooks）。Session 紀錄中每則 assistant 訊息帶 `message.model`（例如 `claude-opus-5-5`），
    會隨 `/model` 切換而變；此格式未記載於官方文件。`hook.sh` 已以 `claude_pending_call` 讀同一份紀錄。

## Goals / Non-Goals

**Goals:**

- Pi 的通知與其他工具共用同一個通知腳本、開關、範本與隱私規則。
- extension 只做事件轉接；分類規則留在 `events.tsv`，可用既有 dry-run 測試。

**Non-Goals:**

- 不做授權要求通知（Pi 沒有授權機制）。
- 不偵測只用文字提問的情況。
- 不處理交接通知與 Pi 觸發 `handoff-route`（`add-pi-handoff-agent`）。
- 不支援專案層級 `.pi/extensions/`；只裝在全域目錄，與其他工具的 user-level 安裝一致。

## Decisions

### 1. 事件流

```
Pi 主 session（ctx.mode 為 tui，且沒有 PI_SUBAGENT_PARENT_SESSION）
  |
  +-- agent_start ----------------> running = true
  +-- agent_end(messages) --------> lastStop = 最後一則 assistant 的 stopReason
  +-- agent_settled(aborted) -----> running = false
  |       aborted            -> 送 pi-stop，stop_reason=aborted（表中為 none，不送）
  |       lastStop == error  -> 送 pi-stop，stop_reason=error
  |       其他               -> 送 pi-stop，stop_reason=completed
  |
  +-- ui_prompt_start ------------> running 為真時送 pi-question；閒置時不送
                 |
                 v
  spawn("bash", [hook, event, "Pi"])，stdin 寫入 JSON 後關閉，detached + unref
  JSON：{hook_event_name, session_id, cwd, stop_reason, model}（model 取 ctx.model?.id，沒有時省略）
                 |
                 v
  telegram-notify.sh --> events.tsv --> 開關 --> 範本 --> Telegram
```

- `stop_reason` 只有 extension 自己產生的三個值，不轉送 Pi 的原始訊息或錯誤內容，從源頭符合隱私規則。
- `agent_end` 可能出現多次（重試），只保留最後一次的結果；在 `agent_settled` 才送出，所以重試成功只會有一則完成通知。
- `session_id` 取 `ctx.sessionManager.getSessionId()`（UUID），通知腳本既有的格式化會顯示成 `#前八碼`。
- 替代方案：在 `agent_end` 送完成通知。不採用——Pi 自動重試或接續時會提早或重複通知。

### 2. 通知範圍

- 用 `ctx.mode === "tui"` 判斷是否互動：print、JSON 模式沒有 UI；RPC 模式的 `ctx.hasUI` 也是真，但驅動它的客戶端可能沒有畫面，
  所以不用 `hasUI`（審查 `pi-notify-review01-r01/F-01`）；pstack subagent 另以 `PI_SUBAGENT_PARENT_SESSION` 排除（它是 RPC
  子程序，且父 session 會取消子 agent 的 UI 提示）。
- 等待回應只在執行中送出（`agent_start` 到 `agent_settled` 之間）：使用者閒置時自己打開的選單（例如 `/pstack-agents`）
  人就在畫面前，不需要通知。
- 同一段等待只送一次：依靠 Pi 已把重疊提示合併成一段 `ui_prompt_start`。
- Xirp 前景開啟的 Pi session 已確認是 TUI：程序鏈為 `tmux new-session -d -s xirp-<id>` → Xirp node（`@chirp/squab`）→ `pi`，
  沒有 `-p` 或 `--mode` 參數，所以 `ctx.mode` 為 `tui`、會通知（2026-11-18 於本 change 規劃 session 查證）。交接迴圈以
  `session:create` 且 `background: true` 開啟的 Pi session 推測相同但尚未查證，列為 task；若不是 TUI，依規則不通知，屆時再議。

### 3. 事件表與通知腳本

- `events.tsv` 新增：
  - `pi-stop:completed` → completion／completion
  - `pi-stop:error` → failure／stopped，理由標籤 `error`
  - `pi-stop:aborted` → none
  - `pi-stop:*` → none（未知值不送）
  - `pi-question` → user_input／question
- `hook.sh` 新增一行：事件為 `pi-stop` 時，事件鍵改為 `pi-stop:<stop_reason>`（只保留小寫英文字母），寫法同 `antigravity-stop`。
  其餘（開關、`NOTIFY_LEVEL`、Session 標籤、範本、dry-run）完全沿用。
- 替代方案：extension 直接送 Telegram。不採用——要重做設定讀取、開關、範本與憑證處理。

### 4. 安裝、擁有標記與移除

- 來源 `scripts/notify/pi/ai-notify.ts`；第一行為固定的擁有標記（例如 `// managed by wk-agent-ops ai-notify`）。
- 偵測：`command -v pi` 或 Pi agent 目錄（`${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}`）存在。
- `register_hook` 加入 `register_pi_extension`：目標不存在或為帶標記的一般檔案時複製覆蓋；存在但沒有標記，或是符號連結（含斷鏈）時不動並在 stderr 警告
  （審查 `pi-notify-review01-r01/F-02`）。
  `fix-hooks` 走同一個函式。`unregister_hook` 加入 `unregister_pi_extension`：只刪帶標記的一般檔案，符號連結不動。
- `update.sh status` 列出 Pi：已安裝、未偵測到 Pi、或被同名檔案擋住。
- 安裝提示：已開啟的 Pi session 需 `/reload` 或重開。
- extension 內以 `${HOME}/.config/ai-notify/hooks/telegram-notify.sh` 為通知腳本路徑，不存在時直接返回。

### 5. 與交接 extension 的關係

- `add-pi-handoff-agent` 的 `wk-handoff.ts` 也監聽 `agent_settled`，但由交接 installer 管理。兩個檔案各自安裝與移除，
  互不依賴，與 Claude Code 上 notify 與 handoff 各登記一個 Stop hook 相同。交接角色交件時會同時收到工作結束與交接進度兩則通知，
  與 Claude、Codex 現況一致（使用者先前已接受）。

### 6. 工具行顯示 model

```
payload 的 model（字串）──有──┐
          │ 沒有              │
          v                   v
Claude Code？── 是 ──> Session 紀錄最後一則 assistant 的 message.model
          │ 否                │
          v                   v
       無 model          清理 → 顯示名稱 → model_suffix / model_family_suffix
```

- 來源優先序：payload 的 `model` 字串（Codex 必填、Pi 由 extension 帶入、其他工具有就用）；沒有且工具為 Claude Code 時，讀
  `transcript_path` 最後 400 行中最後一則帶 `message.model` 的 assistant 紀錄，略過 `<` 開頭的值（例如合成訊息的 `<synthetic>`）。
  其餘情況沒有 model。
- 清理：去掉結尾的 `[...]`（例如 `[1m]`），只留 `[:alnum:]._:/-`，最多 64 字元；清理後為空視同沒有 model。
- 顯示名稱：
  - Claude ID `claude-<家族>-<主>-<次>[-日期]` → `<家族首字大寫> <主>.<次>`；`claude-<家族>-<主>[-日期]` → `<家族> <主>`；
    舊式 `claude-<主>-<次>-<家族>[-日期]` 同樣處理；只有家族名的別名（`opus`、`sonnet` 等）→ `Opus`，沒有版本。
  - 其他 ID 原樣顯示，含版本與不含版本相同（例如 `gpt-6.1-terra`）。
- 範本參數：`model_suffix` = ` (<家族> <版本>)`、`model_family_suffix` = ` (<家族>)`，沒有 model 時兩者皆為空字串，
  寫法同 `title_suffix`。7 個含 `{tool}` 的內建範本把工具行改為 `🤖 {tool}{model_suffix}`；交接範本不變（由 `handoff-route`
  另外帶 agent 資訊）。值照常經過 `notify_escape`。
- 替代方案：Claude Code 改登記 SessionStart 與 PostModelSwitch，把 model 記到狀態檔。不採用——要多登記兩個 hook 與一份狀態，
  SessionStart 在 `/clear` 後仍可能沒有 model；讀紀錄只多一個 jq 查詢，且與既有 `claude_pending_call` 同一份資料。
- 替代方案：範本用 `({model})` 加條件判斷。不採用——範本引擎刻意不支援條件；空括號會出現在拿不到 model 的通知。

### 7. TDD 策略與測試邊界

- 先在 `scripts/notify/telegram/test.sh` 寫失敗的 dry-run 測試：`pi-stop` 的 completed／error／aborted／未知值、`pi-question`；
  標題的工具名稱 `Pi` 與 Session 標籤；四個分類開關與 `NOTIFY_LEVEL=attention_required` 對 Pi 事件的效果；error 的 payload
  夾帶額外文字時訊息中不出現。
- model 顯示的失敗測試（同一支 `test.sh`，dry-run）：Codex payload `model` → `Codex (gpt-6.1-terra)`；Pi payload → `Pi (Opus 5.5)`；
  Claude Code 由紀錄取得 → `Claude Code (Opus 5.5)`，紀錄最後是 `<synthetic>` 時取前一則真實 model；沒有 model → 工具行沒有括號；
  使用者範本用 `{model_family_suffix}` → `(Opus)`；`[1m]` 後綴與非法字元被清掉；Claude ID 的三種格式與別名各一案。
- registry 測試在暫時 HOME：有 Pi 時安裝一份且與來源相同、安裝兩次仍一份、同名無標記檔案不被覆寫且有警告、移除只刪帶標記檔案、
  沒有 Pi 時不建立檔案、status 三種狀態；既有 Claude、Codex、Antigravity、Copilot 測試維持通過。
- extension 本身：以 `pi -e scripts/notify/pi/ai-notify.ts --help` 之類不呼叫模型的方式做載入檢查；事件行為以真實演練確認
  （完成、提問、Esc 中止、`pi -p` 不通知、subagent 不通知、錯誤後重試），結果記入 Work Item。真實演練會呼叫模型，
  使用訂閱登入的 provider（例如 `openai-codex`）以免消耗 API 額度。

## Risks / Trade-offs

- [Pi extension API 改版] → 只用文件列出的事件與欄位；載入或執行錯誤都被吞掉，最壞情況是沒有通知，不影響 Pi。
- [Xirp 背景開啟的 Pi session 可能不是 TUI] → 前景 session 已確認是 TUI；背景 session 由 task 1.1 查證，結果不符時另議，不在本 change 預先放寬。
- [其他 extension 在執行中開提示（例如授權確認）也會被當成等待回應] → 目前沒有安裝授權 extension；日後需要時可依提示種類改分類。
- [同名檔案衝突] → 只認擁有標記，衝突時不安裝並在 status 顯示。
- [Telegram 很慢] → detached 子程序，Pi 不等待；通知腳本既有的短 timeout 限制執行時間。
- [Claude Code 紀錄格式未記載、可能落後一輪] → 讀不到就不顯示 model，不影響通知；剛用 `/model` 切換後的第一則通知可能顯示前一個
  model。日後 Stop payload 提供 model 時改用 payload（來源優先序已先看 payload）。
- [Claude 命名規則改變] → 不符合已知格式的 ID 原樣顯示，不會錯誤縮寫。

## Migration Plan

1. 合併後執行 `bash scripts/notify/telegram/update.sh fix-hooks`（或重跑 install）安裝 Pi extension；已開啟的 Pi session `/reload`。
2. 不影響其他工具的既有登記；`events.tsv` 新增的列對舊版腳本無作用。
   重跑 install 或 `fix-hooks` 部署新的通知腳本與範本後，所有工具的工具行開始顯示 model；使用者自訂範本要自己加入 `{model_suffix}`。
3. 回退：執行 uninstall，或刪除帶標記的 `~/.pi/agent/extensions/ai-notify.ts`；通知腳本中的 Pi 事件列不會被其他工具觸發。

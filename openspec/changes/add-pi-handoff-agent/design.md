# Design

## Context

動機見 proposal.md；行為以 specs 為準。影響做法的現況：

- 交接核心全在 shell：`scripts/handoff/lib/handoff.sh` 的 `ho_template_check` 只接受 `claude`、`codex`；`ho_xirp_create` 以
  `xirp api send session:create` 開 Session，effort 鍵依工具為 `effort` 或 `reasoning_effort`。`handoff-start` 的覆寫格式為
  `claude|codex:<model>:<effort>`。`loop.yaml` 只存 review 與 finish 範本。
- 路由由 Claude Code／Codex 的 Stop hook 觸發 `handoff-route`，它讀 stdin JSON 的 `cwd`，失敗一律安靜結束。
- `add-handoff-notifications`（另一個 worktree，實作中）把路由結果分成「已交付」「人工停點（寫入 `.routed`）」「可重試失敗
  （不寫入）」三類，並為通知加上 Agent 資訊。本 change 在它封存後實作，沿用這三類。
- 已在本機查證：
  - Xirp `agents:list` 有 `pi` harness；`settings:getAgentDefaults` 中 Pi 的原生選項為 `provider`、`thinking`。
    Xirp 的 Pi 模型清單只有不含 provider 的 ID。
  - `pi auth check --provider <p> --json` 回傳 `status` 與 `authType`，不輸出 secret；本機 `openai-codex` 為 `oauth`，
    `openai`、`anthropic` 為 `api_key`。
  - `pi --list-models <id>` 依 provider 列出可用模型（`gpt-6.2-sol` 同時列在 `openai` 與 `openai-codex`）。
  - Pi 在 shell 工具的環境提供 `PI_PROVIDER`、`PI_MODEL`、`PI_REASONING_LEVEL`、`PI_SESSION_ID`，值在每個指令開始時解析，
    `/model` 換模型後立即反映。
  - Pi extension 事件：`agent_end` 之後 Pi 仍可能重試、壓縮後重試或接續佇列訊息；`agent_settled` 才是最終停止。
  - pstack 的 Pi `agent` 工具（`resolveModel`）：子程序帶 `PI_SUBAGENT_PARENT_SESSION`；未指定模型時用父 Session 的模型；
    別名（opus、fable、sonnet、haiku）在父 provider 為 `anthropic`、`openai`、`openai-codex` 時解析成同 provider 的模型，
    調高模型或 effort 不換 provider。會換 provider 的只有：明確的別家 `provider/id`、`pstack-models.md` 的 `pi models:`、
    父 provider 不在對照表內時退回 anthropic。本 repo 的 `.claude/agents/`、`.codex/agents/` 不會被 pstack 在 Pi 上讀取。
- task 1.2 實測（2026-11-19，Xirp 0.68.0、Pi 1.5.2）：
  - Xirp 的 `buildPiArgs` 以 `provider`、`model`、`thinking` 組成 `--provider`、`--model`、`--thinking`，鍵名與本設計相同；
    但 `resolveAgentLaunchOptions` 只對測試過的版本套用選項（`TESTED_VERSIONS.pi` 為 0.83.0 起、major 小於 1）。Pi 1.5.2
    被判為未測試版本，三個選項整組被丟掉，Session 以 Pi 自己的儲存預設啟動。
  - Pi 專案設定 `.pi/settings.json` 的 `defaultProvider`、`defaultModel`、`defaultThinkingLevel` 覆蓋使用者設定；實測在
    全域預設為 `openai-codex/gpt-6-sol medium` 時，專案設定讓 Session 跑在 `openai-codex/gpt-5.6-luna low`。
  - 目錄中有 `.pi/settings.json` 或目前目錄（或上層）有 `.agents/skills` 時，Pi 啟動前要求信任決定；不信任就不載入專案設定。
    wk-agent-ops 的 installer 會在每個 repo 放 `.agents/skills`，所以每個交接 worktree 都會觸發。全域 extension 的
    `project_trust` handler 可回傳 `{trusted:"yes"}` 取代互動提示，不帶 `remember` 時只對該程序有效（實測不寫入 `trust.json`）。
  - 使用者已存的信任決定在 `~/.pi/agent/trust.json`，以最近的上層目錄為準；交接 worktree 與主 worktree 同層，不被主 worktree 的決定涵蓋。

## Goals / Non-Goals

**Goals:**

- Pi 角色在任何關口與宣告不符時停下，不在使用者不知情時使用錯的 provider、模型或計費方式。
- 判斷邏輯集中在可用 bash 測試的 shell 腳本；Pi extension 只負責接事件、套結果。
- Claude Code 與 Codex 角色的行為與資料格式不變。

**Non-Goals:**

- 不攔截、不改寫任何角色內的 subagent 呼叫（pstack 或其他 extension）。pstack 預設不換 provider；改動它的機制副作用大、
  難以測試（使用者決定）。會換 provider 的三種情況只寫入文件。
- 不處理本 repo `.claude/agents/`、`.codex/agents/` 在 Pi 上不生效的問題。
- 不估算或限制用量、費用；只確認來源。
- 不支援 `--api-key` 這類 runtime 憑證覆寫，也不處理 `models.json` 自訂 provider 的計費判斷（認證類型不是 `oauth`／`api_key` 即停下）。

## Decisions

### 1. 三個關口，同一套驗證

```
roles.yaml / --impl / --review 覆寫
      |
      v
[1] handoff-start：一個 worktree 最多一個 Pi 角色、extension 已安裝、
    主 worktree 已被信任、所有 Pi 角色 ho_pi_verify ------- 任一失敗：不開 Session、不建 worktree
      |                                                   anthropic+oauth+subscription：印提醒
      v
ho_pi_settings：角色 worktree 寫入 .pi/settings.json（info/exclude 忽略）
      |
      v
xirp session:create agent:{agentName:pi, options:{model, provider, thinking}}
      |
      v
Pi 啟動：wk-handoff extension 對交接 worktree 回答信任 → 載入 .pi/settings.json
      |
      v
Pi 角色工作
      |
      v
handoff-write：記錄 agent 區塊（PI_* + pi auth check）
      |
      v
Pi agent_settled --> wk-handoff extension --> handoff-route
      |
      v
[2] 路由前比對交件單 agent 區塊與 loop.yaml 範本 --------- 不符：人工停點（通知、寫入 .routed）
      |
      v
[3] hook 開 Pi 審查／收尾前再驗證並寫入設定 ------------ 失敗：可重試失敗（通知一次、不寫入 .routed）
```

- `ho_pi_verify <provider> <model> <effort> <billing>` 放在 `handoff.sh`，`handoff-start` 與 `handoff-route` 共用。檢查順序：
  欄位格式 → `pi --list-models <model>` 的輸出中必須有 provider 與 model 兩欄完全相同的一列 → 若 effort 不是 `off`，該列的
  thinking 欄必須為 `yes` → `pi auth check --provider <p> --json` 的 `status` 為 `ready` 且 `authType` 對應宣告的 billing。
  失敗時輸出一行說明（哪個角色、哪一項、宣告值與實際值），回傳非零。
- 對應表只有兩列：`oauth` ↔ `subscription`、`api_key` ↔ `api`。其他 `authType`、JSON 讀不到、`pi` 不存在，一律視為不符。
- 替代方案：讀 `~/.pi/agent/auth.json` 的 `type`。不採用——憑證可能來自環境變數或 extension，`pi auth check` 用的是 Pi 自己的解析順序，
  也不必讀含 secret 的檔案。

### 2. Pi Session 以角色 worktree 的專案設定開啟

- Xirp 目前不套用 Pi 1.x 的啟動選項（見 Context），所以 provider、model、thinking 改由角色 worktree 的 `.pi/settings.json`
  指定：開 Pi Session 前，`ho_pi_settings <worktree> <provider> <model> <effort>` 寫入
  `{"defaultProvider":…, "defaultModel":…, "defaultThinkingLevel":…}`。
- `ho_xirp_create` 的 `pi` 分支仍在 `agent.options` 帶 `{model, provider, thinking}`：Xirp 日後支援 Pi 1.x 時以命令列參數套用，
  值與專案設定相同，不會互相矛盾。
- 這個檔案不能讓 worktree 變髒（路由前的乾淨檢查會擋下）：寫入前把 `/.pi/settings.json` 加進 repo 的 `info/exclude`
  （`git rev-parse --git-path info/exclude`，每個 repo 只加一次），不改專案的 `.gitignore`。
- 已有 `.pi/settings.json` 時：內容與要寫的完全相同就沿用（開啟失敗後的重試）；不同或被 Git 追蹤就拒絕開啟，說明該檔案，
  不覆蓋。repo 自帶 Pi 專案設定時不能用 Pi 角色，列為已知限制。
- 一個 worktree 最多一個 Pi 角色（使用者決定）：實作 worktree 由實作角色使用；審查、收尾角色 `worktree: shared` 時與實作者同一個
  worktree，`new` 時各自是 `<impl>-review`、`<impl>-finish`。`handoff-start` 依此計算每個 worktree 的 Pi 角色數，超過一個即拒絕，
  指出角色並要求把其中的 Pi 審查或收尾改成 `worktree: new`。一個 Pi 角色與 Claude Code、Codex 角色共用 worktree 不受限。
  因此同一份 `.pi/settings.json` 只服務一個角色，Session 執行中不會被改寫。
- 背景開啟的 Pi Session 由 Pi extension 回答信任提示（決策 8），否則會停在互動提示。
- `ho_template_check` 接受 `pi`，Pi 角色必填 `provider`、`billing`，非 Pi 角色設了這兩欄即拒絕（與 `profile` 只限 Codex 同一模式）。
- `handoff-start` 覆寫格式新增 `pi:<provider>/<model>:<effort>:<billing>`；claude／codex 格式不變。
- `loop.yaml` 新增 `implement_template`（以 `ho_copy_template` 複製，欄位加入 `provider`、`billing`），路由比對實作交件單時才有依據。
- `handoff-start` 先驗證所有 Pi 角色，再建 worktree、開 Session（現在的順序是先建 worktree）。

### 3. 交件單記錄 Agent 身分

- `handoff-write` 在 `PI_CODING_AGENT=true` 且 `PI_PROVIDER` 有值時，於交件單加上兩層的 `agent` 區塊：
  `harness: pi`、`provider`、`model`、`effort`、`billing`、`session`。值取自 `PI_*` 環境變數與 `pi auth check`，不接受參數，
  模型無法改寫。取不到的值寫 `unknown`，交件單照寫——拒寫會讓迴圈無聲停住，寫 `unknown` 則由關口 [2] 停下並通知。
- 不從 Xirp 取：Xirp 的 Pi 模型不含 provider，無法分辨 `openai` 與 `openai-codex`。
- 交件單必須由角色 Session 自己寫：若由 subagent 寫，`PI_*` 是 subagent 的值，可能與範本不同而停下（安全方向的失敗）；SKILL.md 寫明。
- `handoff-author` 新增 `--tool Pi`，讀 `PI_SESSION_ID`；`ho_author` 對 `pi` 輸出 `Pi`。

### 4. 路由前比對（關口 2）與開啟前驗證（關口 3）

- 交件單的 `role` 對應 `loop.yaml` 的 `implement_template`／`review_template`／`finish_template`；只有該範本 `harness: pi` 時比對。
  比對 provider、model、effort、billing 四項，加上 agent 區塊存在且無 `unknown`。
- 比對不符屬於「人工停點」：使用者要修正設定後讓 Agent 寫新的交件單，同一張不需要重試，所以寫入 `.routed`，只通知一次。
- 開啟前驗證失敗屬於「可重試失敗」：原因（例如憑證被換掉）修好後同一張交件單應該能繼續，所以不寫入 `.routed`，
  沿用 `add-handoff-notifications` 的 `.notified` 只通知一次。
- 比對放在既有的 HEAD／乾淨檢查之後、依角色路由之前；Claude Code、Codex 範本完全跳過。

### 5. Pi extension 只做轉接

- `scripts/handoff/pi/wk-handoff.ts` 由 `install.sh` 複製到 `~/.pi/agent/extensions/wk-handoff.ts`（Pi 自動載入全域 extension；
  重跑 installer 覆寫同一個檔案，所以只有一份）。
- `agent_settled`：若環境有 `PI_SUBAGENT_PARENT_SESSION`（pstack 子程序）就略過；否則以 `pi.exec` 執行
  `bash ~/.config/wk-workflow/handoff/handoff-route`，stdin 給 `{"hook_event_name":"Stop","cwd":<ctx.cwd>,"session_id":<Pi session id>}`。
  `handoff-route` 本來就在背景處理並一律成功結束；extension 自己也吞掉所有錯誤。
- 不用 `agent_end`：Pi 自動重試或續跑時會提早交接，審查者可能看到還在變動的 worktree。
- `project_trust`：以 `pi.exec` 執行 `bash ~/.config/wk-workflow/handoff/handoff-pi-trust <event.cwd>`，結束碼 0 回傳
  `{trusted:"yes"}`（不帶 `remember`），其他結果與任何錯誤都回傳 `{trusted:"undecided"}`，交回 Pi 原本的信任流程（決策 8）。
- 替代方案：把路由與信任判斷寫成 TypeScript。不採用——規則已經在 shell 且有測試，兩份實作會分歧。

### 6. 不鎖定角色內的 subagent

- pstack 在 Pi 上的別名解析本來就跟著父 Session 的 provider，調高模型（例如 `opus` → `fable`）或 effort 都留在同一個 provider；
  provider 相同時 Pi 用同一份憑證，計費方式也相同。
- 本 change 不攔截 `agent` 呼叫：改寫或阻擋會改變 pstack 的模型選擇與錯誤回退行為，影響所有 pstack 技能且難以測試（使用者決定）。
- 已知會換 provider 的三種情況寫入 `scripts/handoff/README.md`：明確的別家 `provider/id`、`pstack-models.md` 的 `pi models:` 設定、
  角色 provider 不是 `anthropic`、`openai`、`openai-codex` 時別名退回 anthropic。使用者自行避免。
- 替代方案：用 extension 的 `tool_call` 改寫別名，或讓 subagent 啟動時自我檢查 provider。暫不採用，理由如上；若日後確實需要，
  另開 change 處理。

### 7. Anthropic 提醒

- 只在 `handoff-start` 的驗證中印出（stderr，`⚠️` 前綴），涵蓋之後才開的審查與收尾角色；Pi 自身的 `warnings.anthropicExtraUsage`
  只在互動模式顯示，交接迴圈不能依賴它。宣告與實際不符時走拒絕，不印提醒。

### 8. 只對交接 worktree 自動信任

- 使用者決定由 extension 自動信任交接 worktree，不要求事先信任上層資料夾。
- `handoff-pi-trust <dir>`（shell，與路由腳本一起安裝）在下列條件全部成立時結束碼為 0：
  1. `<dir>` 所在的 Git 頂層 T 是 linked worktree（不是主 worktree M）；
  2. T 底下有某個 `.agent-handoff/<change>/loop.yaml`，其 `implementer.worktree`、`reviewer.worktree` 或 `finish.worktree` 等於 T，
     且該檔案未被 Git 追蹤（clone 下來的 repo 無法靠提交 `loop.yaml` 取得信任）；
  3. 使用者已信任 M：`~/.pi/agent/trust.json` 中離 M 最近的上層目錄（含 M 本身）的決定為 `true`。
- 第 3 點讓 worktree 沿用主 repo 的信任決定：沒被使用者信任過的 repo 不會因為開了交接迴圈而被信任。不符合時回傳 `undecided`，
  Pi 照原本的流程詢問或拒絕。
- 背景 Session 若停在提示會讓迴圈無聲卡住，所以關口 [1] 與 [3] 對 Pi 角色檢查 `~/.pi/agent/extensions/wk-handoff.ts` 存在、
  M 已被信任；不成立就拒絕並說明（安裝 extension、在主 worktree 以 Pi 執行 `/trust`）。
- 替代方案：要求使用者信任 worktree 的上層資料夾。不採用——範圍涵蓋該資料夾下所有專案（使用者決定）。

### 9. TDD 策略與測試邊界

- 全部在 `tests/test_agent_handoff.sh`，以暫時 HOME、假的 `xirp`（記錄 `session:create` 的 JSON）與假的 `pi`
  （依環境變數回傳 `auth check` JSON 與 `--list-models` 表格）執行，不碰真實憑證或網路。
- 先寫失敗測試：
  - 範本驗證：缺欄位、非法 billing／effort、非 Pi 設 provider、別名模型、模型只在另一個 provider 下。
  - 憑證對應：oauth／api_key 四種組合、`not_ready`、未知 authType、`pi` 不存在；anthropic+oauth+subscription 有提醒、其他沒有。
  - `handoff-start`：任一 Pi 角色失敗時沒有 `session:create`、沒有新 worktree；成功時 JSON 帶 `provider`、`thinking`；覆寫格式。
  - `handoff-write`：Pi 環境下的 agent 區塊、`pi auth check` 失敗寫 `unknown`、非 Pi 環境沒有 agent 區塊。
  - `handoff-author --tool Pi`。
  - `ho_pi_settings`：寫入內容、`info/exclude` 只加一次、worktree 維持乾淨、相同內容沿用、不同內容或被追蹤時拒絕。
  - worktree 規則：兩個 Pi 角色共用 worktree 時拒絕、一個 Pi 角色與 Claude／Codex 共用時通過。
  - `handoff-pi-trust`：三個條件各自不成立時非零、全部成立時為 0；以暫時 HOME 的 `trust.json` 驗證最近上層規則。
  - `handoff-route`：四項各自不符、缺 agent 區塊、`unknown`，皆通知一次並寫入 `.routed`；相符則照常路由；開審查前驗證失敗不寫入、
    修好後重試成功；Claude／Codex 範本不受影響（既有測試維持通過）。
- extension 本身是轉接層，不寫 TypeScript 單元測試；以真實驗收確認：Pi 角色交件後 `routing.log` 有一筆、subagent 停下沒有。
  結果記入 Work Item。

## Risks / Trade-offs

- [Xirp 不套用 Pi 1.x 的啟動選項] → 改用角色 worktree 的 `.pi/settings.json`；Xirp 日後套用時值相同。設定沒生效時，
  關口 [2] 仍會因交件單不符而停下。
- [`/.pi/settings.json` 加進 repo 的 `info/exclude`，主 worktree 也會忽略這個路徑] → 只影響本機；repo 自己追蹤的
  `.pi/settings.json` 不受 exclude 影響，且這種 repo 會被拒絕使用 Pi 角色。
- [extension 自動信任會讓交接 worktree 載入 repo 內的 `.pi` 資源與 `.agents/skills`] → 只在主 repo 已被使用者信任、`loop.yaml`
  未被追蹤時成立，信任範圍與使用者在主 repo 的決定相同。
- [`--worktree here` 的 checkout 在迴圈結束後仍留著 `.pi/settings.json`] → `handoff-cleanup` 移除它保留的 worktree 中由迴圈寫入的
  `.pi/settings.json`，避免之後一般的 Pi Session 沿用角色設定。
- [`pi auth check` 是檢查當下的狀態，Session 啟動後憑證仍可能被換] → 交件時再查一次並記入交件單，路由前比對；最壞情況是一輪的用量，不會連續接棒。
- [Pi 依模型能力夾住 thinking 等級，例如範本 `max` 但模型只到 `high`] → 關口 [1] 擋掉不支援 thinking 的模型；仍被夾住時交件單 effort 不符而停下，
  訊息指出宣告與實際，使用者改範本即可。這是「一律停下」的預期代價。
- [角色內的 subagent 在三種例外下會用到別的 provider 與計費] → 不影響交件單比對（記錄的是角色 Session），只影響用量來源；
  README 列出例外，交接角色內不要明確指定別家模型，也不要設 `pi models:`。
- [全域 extension 也會在非交接的 Pi Session 觸發 `handoff-route`] → 與 Claude／Codex 的 Stop hook 相同：沒有 `loop.yaml` 就立即結束。

## Migration Plan

1. `add-handoff-notifications` 封存並合併後才開始實作（它改寫 `handoff-route` 與通知流程）。
2. 部署：重跑 `scripts/handoff/install.sh` 安裝 Pi extension；已開啟的 Pi Session 需 `/reload` 或重開才會路由。
   使用 Pi 角色的 repo 需先在主 worktree 以 Pi 執行過 `/trust`（或已在 `trust.json` 被信任）。
   重跑 `scripts/skills/install.sh` 更新 `handoff-write`、`handoff-author` 與範例範本。
3. 既有 `roles.yaml`（只有 claude／codex）不需修改；進行中的迴圈沒有 `implement_template`，其實作交件單不做 Pi 比對（只有 Pi 範本才比對）。
4. 回退：刪除 `~/.pi/agent/extensions/wk-handoff.ts` 即停止 Pi 路由；舊版 shell 腳本會拒絕 `harness: pi` 的範本，不會誤開。

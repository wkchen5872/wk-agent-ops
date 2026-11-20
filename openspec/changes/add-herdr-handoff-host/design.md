# Design

## Context

動機見 proposal.md 的 Why。設計依據來自本機的 herdr spike（herdr 0.9.5，隔離 session `handoff-spike`）與 herdr v0.9.5 的文件和原始碼。

現況：
- `scripts/handoff/lib/handoff.sh` 的 `ho_xirp_*` 函式直接呼叫 `xirp`；`ho_open_role`、`ho_finish_open`、`ho_finish_retry`、
  `handoff-route` 的傳訊、`handoff-cleanup` 的刪除都直接呼叫這些函式。
- 交件單、Stop hook、Pi 觸發器、`handoff-route` 的判讀邏輯都和 Xirp 無關，這次不動。
- 啟動檢查散在 `handoff-start`（約 20 個 `die`）、`ho_template_check`、`ho_pi_ready`、`ho_finish_check`，`handoff-role` 又照著再跑一次。

spike 確認的 herdr 行為：
- `worktree open --workspace <主 repo ws> --path <wt>` 會建立掛在主 repo 之下的 linked workspace，而且是冪等的。
- `agent start <name> --kind <k> --pane <id> -- <原生參數>` 可以帶模型和 effort；剛建立的 pane 會先回 `agent_pane_busy`。
- 第一次進入新資料夾，Claude Code 和 Codex 會跳出信任對話框，`agent start` 回 `agent_not_ready`。
- `agent get` 的 `agent_session.value` 是原生 Session ID（Pi 是 session 檔案路徑），由 herdr 的整合 hook 非同步回報。
- `agent prompt` 在 agent 忙碌時也會送出，Claude 會排隊處理；agent 是 blocked 時回 `agent_blocked`，什麼都不送。
- pane 內有 `HERDR_ENV`、`HERDR_SESSION`、`HERDR_SOCKET_PATH`、`HERDR_PANE_ID`；從 Xirp shell 啟動的 server，pane 內還會帶著 `CHIRP_SESSION_ID`。
- `pane close` 會結束 pane 裡的 agent；server 重啟時，herdr 會自動 resume 仍開著的 pane 裡的 agent。

## Goals / Non-Goals

**Goals:**
- 現有的 Xirp 行為一行都不變，既有測試全部原樣通過。
- 新增 host 時只需要實作四個動作和一組檢查，不必修改 start、route、finish、cleanup 的流程。
- 同一個迴圈可以混用 host（例如實作者用 xirp、審查者用 herdr）。

**Non-Goals:**
- 不替使用者操作信任對話框、權限確認或任何互動畫面。
- 不改用 herdr 的事件 API（`events.subscribe`）取代 Stop hook；那需要常駐的監督程序。
- 不支援從 Xirp 搬到 herdr 這種「已開啟的角色更換 host」；`handoff-role` 只在角色尚未開啟時可用，這個限制不變。

## Decisions

### D1：host 是逐角色的設定，記在 loop.yaml
`roles.yaml` 頂層 `host`（預設 `xirp`）與 `herdr_session`，角色可以用 `host:` 覆寫。`handoff-start` 把每個角色實際採用的
`host` 寫進 `loop.yaml` 該角色的範本區段；之後 route、finish、cleanup 一律從 `loop.yaml` 讀 host，不從環境變數推測。
- 不採用「從環境自動偵測」：spike 證實 herdr pane 會帶著 Xirp 的變數（S-09），環境不可靠；而且使用者要求設定 xirp 卻找不到時要直接失敗。
- host 是機器的屬性，而 `roles.yaml` 本來就是每台機器一份、被 Git 忽略的檔案，所以不新增專案層級的設定檔。

### D2：host 介面是四個函式加一個檢查，以 case 分派
`ho_host_open <host> …`、`ho_host_message`、`ho_host_exists`、`ho_host_close`，以及 `ho_host_check`（給 doctor 用）。
每個函式依 host 名稱 `case` 到 `ho_xirp_*` 或 `ho_herdr_*`。
- 不採用「每個 host 一個獨立腳本、動態載入」：目前只有兩個 host，bash 的 case 最直接；第三個 host 出現時再考慮。
- session 識別以單一字串存在 `loop.yaml` 既有的 `<role>.session` 欄位：xirp 是 Xirp session ID，herdr 是 pane ID。
  herdr 另外記 `<role>.herdr_session`（herdr session 名稱）與 `<role>.native_session`（原生 Session ID，可能晚一點才拿到）。

### D3：herdr 的 workspace 配置
- 找主 repo 的 workspace：`workspace list` 中 `worktree.checkout_path` 等於主 worktree 的那一個；找不到就
  `workspace create --cwd <主 worktree> --label <repo 名稱> --no-focus` 自動開啟。
- 迴圈的 workspace：
  - 實作者 worktree 是 `new` 時，`worktree open --workspace <主 repo ws> --path <實作者 worktree> --label <change-id> --no-focus`。
  - 實作者用主 worktree（`--worktree here`）時，直接使用主 repo 的 workspace。
- 角色的位置：
  - 每個角色一個 tab，tab 名稱用範本的 `name`（例如 `claude - impl - add-export`）。
  - 迴圈新建的 workspace，第一個角色使用它的 root pane，並把 tab 改名；其他角色用 `tab create`。
  - `review.worktree: new` 或 `finish.worktree: new` 的角色，各自用自己 worktree 的 linked workspace。
- 所有建立動作都帶 `--no-focus`，不搶使用者的畫面焦點。
- `loop.yaml` 記錄迴圈建立的 workspace ID（`herdr.workspaces`），cleanup 只關閉這些 workspace，以及迴圈在主 repo workspace 裡開的 tab。

### D4：herdr 開 session 的步驟
1. 決定 herdr session：在 herdr pane 裡（`HERDR_ENV=1`）沿用 `HERDR_SESSION`；否則用 `roles.yaml` 的 `herdr_session`，沒寫就用 default。
   之後每個 herdr 指令都明確帶 `--session`。
2. 依 D3 取得 pane。
3. `agent start`：遇到 `agent_pane_busy` 時每秒重試，最多 `HANDOFF_CREATE_WAIT` 秒。原生參數如下：
   - claude：`--model <m> --effort <e> --name <name>`
   - codex：`-m <m> -c model_reasoning_effort=<e>`，有 profile 時加 `-p <profile>`
   - pi：`--provider <p> --model <m> --thinking <e>`；`.pi/settings.json` 照常寫入，和 Xirp 的行為一致
4. 第一則 prompt 用 `agent prompt <pane> <prompt> --timeout <ms>` 另外送，不放在 `agent start` 的參數裡。
   macOS 終端機對單行輸入有長度上限，而角色的 prompt 可能超過。
5. 輪詢 `agent get <pane>` 取得 `agent_session.value`，寫進 `native_session`；等不到時留空，下一次傳訊再補。
- agent 名稱用 `<role>-<短雜湊>`：herdr 要求名稱符合 `[a-z][a-z0-9_-]{0,31}`，而且 agent 結束就會清掉，所以只當方便用的標籤，識別一律用 pane ID。

### D5：卡住時沿用既有的 retry
`agent start` 回 `agent_not_ready`，或 `agent prompt` 回 `agent_blocked` 時：
- 已經拿到的 pane 照樣記進 `loop.yaml`，並另外記 `<role>.pending_prompt: true`。
- route 的結果是 `retry`：發一次 attention 通知，說明「請到 herdr 的 <workspace>/<tab> 處理畫面上的對話框，再執行 `handoff-route --foreground`」，交件單不標為已處理。
- 下次重試時看到 pane 已存在、`pending_prompt` 為真，就只補送 prompt，不再開新的 pane。
- 不採用「自動按 Enter 接受信任」：信任資料夾是安全決定，必須由人來做。

### D6：傳訊前確認 pane 裡仍是同一個 agent
`ho_herdr_message` 先跑 `agent get <pane>`，確認 agent 的 kind 等於角色的 harness；`native_session` 已知時，
`agent_session.value` 也要相同。不符或 pane 不存在，就當作傳送失敗，進入既有的 retry 流程。
`agent prompt` 一律帶 `--timeout`，不帶 `--wait`：route 只需要確認送出，而且 timeout 不代表沒送到，不能盲目重送。

### D7：Xirp 變數只在非 herdr pane 採用
`handoff-author` 與 `handoff-route` 只在 `HERDR_ENV` 不等於 `1` 時讀 `CHIRP_SESSION_ID`。
Xirp 的 session 不會在 herdr pane 裡執行，所以 herdr pane 裡的 `CHIRP_*` 一定是從啟動 server 的 shell 繼承來的。

### D8：routing log 的模型
xirp 照舊用 Xirp 回報的模型；Pi 照舊取自交件單；herdr 不回報模型，所以改取 `loop.yaml` 角色範本的模型，記成 `model=<model>(template)`，讓讀者知道這是設定值而不是實際觀察到的值。

### D9：handoff-doctor 與共用檢查
- 每一項檢查是一個函式，輸出一行 `<ok|warn|fail> <area> <message>`。
  `ho_preflight <loop-or-roles-file> <roles…>` 依序呼叫這些檢查，回傳是否有 `fail`。
- `handoff-doctor [change-id]` 沒帶 change 時檢查 `roles.yaml` 的三個角色；帶 change 時檢查該迴圈 `loop.yaml` 裡生效的角色。
  輸出所有結果，有 `fail` 就以非零狀態結束。
- `handoff-start`、`handoff-role`、`handoff-finish` 在開任何 session 前跑 `ho_preflight`，有 `fail` 就印出 `fail` 那幾行並拒絕。
  原本的參數錯誤、分支、worktree 狀態等和環境無關的檢查保留在各指令裡。
- 檢查項目：

| 區 | 項目 | 等級 |
|---|---|---|
| base | git、jq、main worktree、`roles.yaml` 存在且可解析 | fail |
| host | xirp：CLI、repo 已登錄 Xirp project；herdr：CLI、指定 session 的 server 在跑、`herdr status` 可連線 | fail |
| harness | 角色用到的 CLI 已安裝（印出版本） | fail |
| harness | 觸發器：Claude Code `~/.claude/settings.json` 與 Codex `~/.codex/hooks.json` 已註冊 `handoff-route`；Pi 擴充已安裝 | fail |
| harness | Codex hook 是否已在 `/hooks` 信任無法從外部確認，印出提醒 | warn |
| harness | herdr host 的角色：herdr 對該 harness 的整合 hook 已安裝（`herdr integration status`），否則拿不到原生 Session ID | warn |
| role | 範本欄位（沿用 `ho_template_check`）；Pi 的模型、憑證、計費與信任（沿用 `ho_pi_ready`） | fail |
| role | Claude Code、Codex 的模型沒有可靠的清單可查，標示「未驗證」 | ok |
| notify | Telegram 通知器沒設定 | warn |

## Risks / Trade-offs

- [herdr 還在 1.0 以前，CLI 或 JSON 欄位可能改變] → 只用 spike 驗證過的指令與欄位；`handoff-doctor` 印出 herdr 版本；
  測試用假的 `herdr` 固定這些介面，herdr 改版時只需要更新一處。
- [herdr server 重啟會自動 resume 仍開著的 agent] → cleanup 一定先關 pane 或 workspace，再移除 worktree。
- [信任對話框讓每個新 worktree 的第一次開啟都卡住] → D5 的 retry 流程，加上 README 說明可以事先信任 worktree 的上層目錄。
- [原生 Session ID 由 herdr 的整合 hook 非同步回報，可能拿不到] → `native_session` 允許留空；傳訊前的確認只在已知時比對；doctor 對缺少的整合發出 warn。
- [互動彈窗（例如 Codex 的額度提醒）會讓 `agent prompt` 被拒絕] → 視同 blocked，走 D5 的 retry。
- [host 抽象化可能改壞 Xirp 行為] → 先把 Xirp 搬進 host 介面並讓既有測試全數通過，之後才加 herdr。

## Migration Plan

- 既有的 `roles.yaml` 沒有 `host`，會以 `xirp` 運作，不需要任何遷移。
- 執行中的迴圈，`loop.yaml` 沒有 host 欄位，一律視為 `xirp`。
- `install.sh` 多安裝 `handoff-doctor`；`roles.example.yaml` 加上 `host`、`herdr_session` 的說明，只在 `roles.yaml` 不存在時複製，不覆寫使用者的檔案。
- 回復：退回本 change 的 commit 即可；`loop.yaml` 多出的欄位舊版會忽略。

## TDD 策略與測試邊界

- 測試檔：`tests/test_agent_handoff.sh`。沿用現有做法，在 PATH 前面放假的 `xirp`；新增假的 `herdr`，記錄收到的參數，
  依情境回傳 JSON（成功、`agent_pane_busy`、`agent_not_ready`、`agent_blocked`、`server_not_running`）。
- 步驟一（重構）：把 Xirp 搬進 host 介面時不新增測試，以既有測試全數通過作為行為不變的證據。
- 步驟二起（新行為）：每個任務先寫失敗的測試，再實作。涵蓋 doctor 的各區檢查、herdr 的開啟／傳訊／確認／關閉、D5 的 retry、D7 的變數忽略、混用 host。
- 不在自動測試範圍：真實 herdr 與真實 agent 的互動。以一次真實迴圈手動驗收，結果記在 Work Item `WI-20261120-handoff-session-hosts`。

# Design

## Context

動機見 proposal.md 的 Why。依據是 Work Item `WI-20261120-handoff-session-hosts` 的 herdr-app spike A-01～A-10，
實測版本為 `hc` 0.1.21 與 `herdr-app` CLI。

現況：
- `scripts/handoff/lib/handoff.sh` 有 host 分派：`ho_host_open`、`ho_host_message`、`ho_host_exists`、`ho_host_close`、
  `ho_host_check`，目前有 `xirp`、`herdr` 兩個分支；`ho_preflight` 是共用的環境檢查（`handoff-doctor`、start、role、finish）。
- herdr TUI host 的經驗可以直接沿用：以 pane 為身分、交件單維持未處理的 retry、unconfirmed 檔，以及不替使用者回答對話框。

spike 確認的 herdr-app 行為：
- 只有透過 app 開的 terminal 會出現在 app 裡（A-01、A-03）。`herdr-app do space.new`／`tab.new` 會回傳 `{space, tab, terminal}`。
- app 由登入 shell 啟動 agent，所以 nvm 的 `node` 和 `pi` 都找得到；`hc run` 不會（A-06）。
- 第一則 prompt 用 `--task` 交給 app，由 app 等 agent 準備好之後再送（A-04）。
- Claude、Pi 會自己回報 OSC 7501 狀態與 `turn`（A-07）。`hc send` 回傳 `started`；agent 還沒回報狀態前送出，訊息會遺失（A-08）。
- `space.close --confirmed true` 會結束裡面的 terminal，並從排版移除（A-09）。
- `herdr-app status` 對著執行中的視窗回報；app 沒開時的回應，尚未實測。

## Goals / Non-Goals

**Goals:**
- `herdr-app` 角色的 session 出現在 Herdr app 裡：一個迴圈一個 space，每個角色一個 tab。
- 「app 有沒有開」是環境檢查的一部分，沒開就在開任何 session 之前失敗。
- `xirp`、`herdr` 的行為與測試完全不變。

**Non-Goals:**
- 不讀寫 app 內部的排版文件（core 文件 `herdr-app`）。
- 不支援 herdr-core 的遠端機器（`--machine`）。
- 不在 app 沒開時改用 `hc run` 在畫面外執行。

## Decisions

### D1：host 值是 `herdr-app`
`herdr` 已經代表終端機版，而且已有迴圈在用；app 版用獨立的值 `herdr-app`，兩者可以並存，也可以在同一個迴圈裡依角色混用。

### D2：開啟走 `herdr-app`，其餘走 `hc`
- 開啟只能用 `herdr-app do`（A-01：`hc run` 開的看不到；A-06：`hc run` 沒有登入 shell 的 PATH）。
- 傳訊、確認、清理用 `hc`：它有 terminal 位址、`started`、`state`，比操作視窗更穩定，也不會搶焦點。
- `herdr-app` 只用 `space.new`、`tab.new`、`space.close`、`tab.close`、`status` 這五個指令，都在它的公開指令清單裡（`herdr-app commands`）。

### D3：space 與 tab 的配置
- 角色的 worktree 還沒有迴圈開的 space：`space.new --name <change-id>`（審查或收尾用自己的 worktree 時，名稱是 `<change-id> review`／`<change-id> finish`），
  `--folder <worktree> --tab <範本 name> --argv <JSON> --task <prompt> --focus false`。
- 同一個 worktree 已經有迴圈開的 space：`tab.new --space <id> --name <範本 name> --argv … --task … --focus false`。
- `loop.yaml` 記錄每個角色的 `session`（terminal 位址）、`happ_space`、`happ_tab`，以及迴圈開的 space 清單 `herdr_app.spaces`。
- `--argv` 依 harness 組成（與 herdr TUI 相同的參數）：
  - claude：`["claude","--model",m,"--effort",e,"--name",name]`
  - codex：`["codex","-m",m,"-c","model_reasoning_effort=e"]`，有 profile 時加 `-p`
  - pi：`["pi","--provider",p,"--model",m,"--thinking",e]`，並照常寫入 `.pi/settings.json`

### D4：第一則 prompt 交給 app 的 `--task`
由 app 等 agent 準備好之後再送，所以不需要自己判斷就緒時機（A-04、A-08）。
開啟後輪詢 `hc get`，最多 `HANDOFF_CREATE_WAIT` 秒：
- `turn` 增加，或 `status.state` 是 `working`：視為已送達。
- 是 `blocked`：照 D6 處理。
- 等不到：當作送出結果不明，存成 unconfirmed 檔、發一次通知，不重送（沿用 herdr TUI 的規則）。

### D5：之後的傳訊用 `hc send`
- 送出前先 `hc get`：`state` 必須是 `live`、foreground 的程式必須是該角色的 harness，而且 `status.state` 是 `idle` 或 `done`。
  不符合就算傳送失敗，走既有的 retry。
- `hc send <t> <text>` 回傳 `started: true`：送達。
- hc 因為 `blocked` 拒絕：照 D6 處理。
- 其他結果：送出結果不明，存成 unconfirmed 檔、發一次通知，不重送。

### D6：卡在對話框
`status.state` 是 `blocked` 時（`kind` 是 permission、question 或 auth），不替使用者回答，發一次 attention 通知，
寫出 space 與 tab 名稱（取自 terminal 的 `where` label），交件單維持未處理；處理完後用 `handoff-route --foreground` 重試。

### D7：app 是否開著，屬於環境檢查
`ho_host_check` 的 `herdr-app` 分支依序檢查，任何一項失敗都是 `fail host`，並附上處理方式：
1. `herdr-app` 與 `hc` 指令存在；
2. herdr-core 在跑：`hc server status` 成功；
3. Herdr app 視窗在跑：`herdr-app status` 成功並回傳 JSON；否則提示「請先開啟 Herdr app」。

start、role、finish 經由 `ho_preflight` 共用這套檢查，所以 app 沒開時，任何 session 都不會開啟。
hook 在派送時若遇到 app 沒開（`herdr-app do` 失敗），沿用 `open-failed` 的 retry 與 attention 通知。

### D8：關閉
cleanup 對迴圈開的 space 執行 `space.close --id <id> --confirmed true`；角色是加在迴圈以外的 space 時，改用 `tab.close`。
接著對每個角色的 terminal 執行 `hc rm`，清除已結束的 terminal。關閉要在移除 worktree 之前完成；關閉沒有成功時，不移除 worktree（沿用 herdr TUI 的 F-01 規則）。

### D9：routing log 的停止端
在 terminal 內（有 `HC_TERMINAL_ID`）記為 `session=herdr-app:<HC_TERMINAL_ID>`。模型與 herdr TUI 相同，取自範本並標示 `(template)`。

## Risks / Trade-offs

- [`herdr-app` CLI 與 hc 都在 1.0 以前，可能改版] → 只用 spike 驗證過的指令與欄位；doctor 印出版本；測試以假的 `herdr-app`／`hc` 固定介面。
- [app 沒開時 `herdr-app status` 的實際回應未測] → 列為實作 task：關閉 app 實測一次並記錄；判斷規則是「非 0 結束或沒有 JSON」就視為沒開。
- [同仁的 app 不一定有 agent 狀態整合，`status` 可能是 null] → 沒有狀態時，D4 只能等 `turn`；仍然等不到就走送出結果不明的流程，並在 doctor 印出 warn。
- [space 名稱與使用者既有的 space 撞名] → 以 ID 為準，名稱只是顯示用。

## Migration Plan

- 只新增 host 值，現有 `roles.yaml` 與 `loop.yaml` 不需要變更。
- 回復：退回本 change 的 commit。

## TDD 策略與測試邊界

- 測試檔：`tests/test_agent_handoff.sh`，新增 `herdr-app` 區段；新增假的 `herdr-app`（記錄 `do` 指令，回傳 `{space, tab, terminal}`，可切換「app 沒開」）
  與假的 `hc`（`get`、`send`、`rm`、`server status`，可切換 `blocked`、`started:false`、`turn` 不變）。
- 每個需求先寫失敗的測試：doctor 對 app 沒開、core 沒開、指令不存在的 `fail host`；開啟的指令序列與 `loop.yaml` 紀錄；
  `--task` 之後的確認（`turn` 增加、`blocked`、等不到）；`hc send` 的 `started` 與拒絕；cleanup 的關閉順序；混用 host；既有 `xirp`／`herdr` 測試不變。
- 不在自動測試範圍：真實 app 的整個迴圈，以一次真實演練驗收，結果記在 Work Item。

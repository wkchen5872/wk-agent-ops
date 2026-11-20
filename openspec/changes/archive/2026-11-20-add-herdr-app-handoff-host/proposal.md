# Proposal

## Why

`add-herdr-handoff-host` 支援的 herdr 是終端機版（herdr TUI）。公司同仁主要用的是 Herdr 桌面 app，它背後是另一套
runtime：herdr-core（`hc`）。終端機版的 server 不會出現在 app 裡，所以同仁開的交接迴圈看不到。

spike 已確認 app 有正式的方式可以開出看得到的 session（`herdr-app do space.new`／`tab.new`）。開出的 terminal 可以用 `hc` 傳訊、查狀態與清理。

## What Changes

- 新增 host `herdr-app`：`roles.yaml` 的 `host` 可以設為 `xirp`、`herdr`（終端機版）或 `herdr-app`（桌面 app），個別角色也能覆寫。
  `herdr` 維持指終端機版，現有設定與迴圈不受影響。
- `herdr-app` host 的四個動作：
  - 開啟：迴圈的第一個 `herdr-app` 角色用 `herdr-app do space.new` 開一個 space，資料夾是角色的 worktree，名稱是 change ID；
    之後的角色在同一個 worktree 時，用 `tab.new --space` 加 tab，在自己的 worktree 時，開自己的 space。
    tab 名稱用範本的 `name`，一律 `--focus false`。agent 與模型、effort 由 `--argv` 指定，第一則 prompt 用 `--task` 交給 app，
    由 app 等 agent 準備好之後再送出。
  - 傳訊：`hc send <terminal>`，以回傳的 `started` 判斷 agent 是否真的開始；agent 回報 `blocked` 時，hc 會拒絕送出，沿用既有的 retry 與 attention 通知。
  - 確認還在：`hc get <terminal>`，`state` 是 `live`，而且 foreground 是該角色的 harness。
  - 關閉：cleanup 用 `herdr-app do space.close`（迴圈開的 space）或 `tab.close`（加在別處的 tab）並帶 `--confirmed true`，再用 `hc rm` 清除已結束的 terminal。
- `loop.yaml` 記錄 `herdr-app` 角色的 terminal 位址（例如 `t1k`）、space ID 與 tab ID。
- Herdr app 沒有開著時，`handoff-doctor`、`handoff-start`、`handoff-role`、`handoff-finish` 直接失敗，並提示先開啟 Herdr app；
  不改用 `hc run` 在畫面外執行，因為那樣 session 看不到，與這個 host 的目的相反（spike A-01）。
- `handoff-doctor` 對 `herdr-app` 檢查：`herdr-app` 與 `hc` 指令存在、herdr-core 在跑（`hc server status`）、app 視窗在跑（`herdr-app status`）。
- `routing.log` 對 `herdr-app` 角色記錄停止端的 terminal 位址（`HC_TERMINAL_ID`）。
- 文件：`scripts/handoff/README.md` 的 Session hosts 段落、`roles.example.yaml`、`docs/skills/agent-handoff.md`。

不在範圍內：寫入 app 內部的排版文件（core 文件 `herdr-app`，格式未公開）；herdr-core 的遠端機器（`--machine`）。

驗收條件：
- `host: herdr-app` 時，`handoff-start` 在 Herdr app 開出名為 change ID 的 space 與實作者 tab，實作者收到 prompt；`loop.yaml` 記錄 terminal、space、tab。
- 實作者交件後，hook 在同一個 space 加開審查者 tab，並送出審查 prompt；之後的往返都用 `hc send` 送到同一個 terminal。
- Herdr app 沒開時，`handoff-doctor` 出現 `fail host`，`handoff-start` 不開任何 session。
- agent 卡在對話框（`blocked`）時，hook 發一次 attention 通知，不替使用者回答，交件單維持未處理。
- cleanup 後，迴圈開的 space 與 terminal 都已關閉並移除，worktree 已移除，分支保留。
- 既有的 `xirp`、`herdr` 迴圈行為不變，既有測試全部通過。

支援的 AI CLI：Claude Code、Codex、Pi（hook 與 Pi 觸發器不變）。

## Capabilities

### New Capabilities

### Modified Capabilities
- `agent-handoff-hosts`: 新增 `herdr-app` host 的設定值、開啟、傳訊、確認、關閉與 app 未開啟時的行為。
- `agent-handoff-doctor`: 新增 herdr-app host 的檢查需求（指令、herdr-core、app 視窗），既有需求不變。

## Impact

- 程式：`scripts/handoff/lib/handoff.sh`（host 分派新增 `herdr-app` 分支與 `ho_happ_*` 函式、doctor 檢查）、`handoff-route`（停止端 terminal 位址）、
  `handoff-cleanup` 預覽（列出要關的 space 與 tab）。
- 測試：`tests/test_agent_handoff.sh` 新增假的 `herdr-app` 與 `hc`，以及 `herdr-app` 區段。
- 文件：`scripts/handoff/README.md`、`docs/skills/agent-handoff.md`、`template/common/skills/agent-handoff/roles.example.yaml`。
- 外部依賴：Herdr 桌面 app 與 herdr-core（選用，只有 `host: herdr-app` 需要）。實測版本為 `hc` 0.1.21。

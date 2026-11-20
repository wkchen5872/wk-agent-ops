# Proposal

## Why

交接迴圈目前只能用 Xirp 開啟和傳訊 session：`handoff-start`、`handoff-finish` 找不到 `xirp` 就停止，`handoff-route`
則什麼都不做。同仁使用原生 AI CLI 搭配 herdr，無法使用這套迴圈。herdr 0.9.5 能在指定的 worktree workspace 開啟
Claude Code、Codex、Pi，回報原生 Session ID，也能把 prompt 送進已開啟的 session，可以作為第二個 session 宿主（host）。
另外，啟動前的環境檢查散落在 `handoff-start`、`handoff-role`、`handoff-finish` 與函式庫各處，多一個 host 之前需要先集中。

## What Changes

- 新增 host 概念：`.agent-handoff/roles.yaml` 頂層可設 `host: xirp|herdr`（沒寫時為 `xirp`，與現狀相同），
  個別角色可用 `host:` 覆寫；`herdr_session:` 指定 herdr session（沒寫時用 default；在 herdr pane 裡執行時沿用目前的 session）。
  `loop.yaml` 逐角色記錄 host 與該 host 的 session 識別。
- host 只負責四個動作：開 session、傳訊、確認 session 存在、刪除 session。現有的 Xirp 行為搬成 `xirp` host，行為不變。
- 新增 `herdr` host：
  - 每個迴圈用一個 linked worktree workspace（`herdr worktree open --path <迴圈 worktree>`），掛在主 repo 的 workspace 之下；
    主 repo 還沒在 herdr 開啟時自動開啟。每個角色一個 tab，tab 名稱用角色範本的 `name`。
  - 以 `herdr agent start` 帶入範本的 harness、model、effort（Pi 另帶 provider），第一則 prompt 另以 `herdr agent prompt` 送出。
  - 記錄 pane ID 與 herdr 回報的原生 Session ID；傳訊前確認 pane 裡仍是同一個 agent。
  - agent 卡在信任對話框或其他互動畫面時，不替使用者操作，沿用既有 retry：發一次 attention 通知，修好後可重試。
  - cleanup 關閉迴圈建立的 workspace 或 tab，再移除 worktree。
- 新增 `handoff-doctor [change-id]`：集中檢查 base（git、jq、main worktree、`roles.yaml`）、host（CLI、Xirp project、
  herdr server）、harness（CLI、版本、觸發器）、role（範本欄位、模型；只有 Pi 能真正驗證模型）、notify（只提醒）。
  每項結果為 `ok`、`warn`、`fail`。`handoff-start`、`handoff-role`、`handoff-finish` 改用同一套檢查，有 `fail` 就拒絕。
- 修正：herdr server 從 Xirp 管理的 shell 啟動時，pane 會帶著啟動者的 `CHIRP_SESSION_ID`。在 herdr pane 裡
  （`HERDR_ENV=1`），`handoff-author` 與 `handoff-route` 不再採用 `CHIRP_SESSION_ID`。
- 不在範圍內：`manual`（純終端機、通知使用者自己貼指令）、`tmux`、背景 headless 執行、agy harness。
  README 註記 `ghostty + tmux` 是之後可能支援的 host。

驗收條件：

- `roles.yaml` 沒寫 `host` 的既有迴圈，行為與現在完全相同，既有測試全部通過。
- `host: herdr` 時，`handoff-start` 在主 repo 的 herdr workspace 之下開出迴圈的 linked workspace 與實作者 tab，
  實作者收到範本的 prompt；`loop.yaml` 記錄 host、pane ID 與原生 Session ID。
- 實作者交件後，hook 在同一個 workspace 開出審查者 tab 並送出審查 prompt；之後的往返都送進同一個 pane。
- herdr server 沒在跑、或角色的 CLI 沒裝時，`handoff-doctor` 與 `handoff-start` 回報 `fail` 並且不開任何 session。
- agent 卡在信任對話框時，hook 發一次 attention 通知，交件單不標為已處理；處理完再跑 hook 即可送出。
- cleanup 後，迴圈的 herdr workspace 與 pane 都已關閉，worktree 已移除，feature 分支保留。
- 在帶有 `CHIRP_SESSION_ID` 的 herdr pane 裡執行 `handoff-author`，印出 `XIRP-SESSION-ID: null`。

支援的 AI CLI：Claude Code、Codex、Pi（hook 與 Pi 觸發器不變）。

## Capabilities

### New Capabilities
- `agent-handoff-hosts`: 交接迴圈的 session 宿主：host 設定與選擇、四個 host 動作，以及 `xirp`、`herdr` 兩個 host 的行為與 herdr workspace 配置。
- `agent-handoff-doctor`: 交接迴圈的環境檢查：`handoff-doctor` 指令、檢查項目與結果等級，以及 start、role、finish 共用同一套檢查。

### Modified Capabilities
- `agent-crew-launcher`: 開 session、記錄實作者、重用審查者與 cleanup 刪除 session，從「透過 Xirp」改為「透過角色的 host」。
- `agent-handoff-routing`: hook 只在迴圈所用 host 的 CLI 不存在時不做事；routing log 的模型在 host 不回報時取自範本。
- `agent-handoff-records`: `loop.yaml` 逐角色記錄 host 與 session 識別；`handoff-author` 在 herdr pane 裡不採用 `CHIRP_SESSION_ID`。
- `agent-handoff-pi`: Pi 角色的 provider、model、effort 傳給角色的 host，而不只傳給 Xirp。

## Impact

- 程式：`scripts/handoff/lib/handoff.sh`（host 分派、herdr host、共用檢查）、`handoff-start`、`handoff-finish`、
  `handoff-role`、`handoff-cleanup`、`handoff-route`、新增 `handoff-doctor`、`install.sh`；
  `template/common/skills/agent-handoff/scripts/handoff-author`、`roles.example.yaml`、`SKILL.md`。
- 測試：`tests/test_agent_handoff.sh` 新增假 `herdr` 與 doctor 的案例；既有 Xirp 案例必須不變地通過。
- 文件：`scripts/handoff/README.md`、`docs/skills/agent-handoff.md`。
- 外部依賴：herdr（選用，僅 `host: herdr` 需要），以及 herdr 對 Claude Code、Codex、Pi 的整合 hook（用來回報原生 Session ID）。

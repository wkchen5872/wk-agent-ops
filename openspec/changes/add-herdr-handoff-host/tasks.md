# Tasks

## 1. Host 介面（只重構，行為不變）

- [x] 1.1 在 `scripts/handoff/lib/handoff.sh` 新增 `ho_host_open`、`ho_host_message`、`ho_host_exists`、`ho_host_close`，依 host `case` 分派，目前只有 `xirp` 分支呼叫既有的 `ho_xirp_*`；把 `ho_open_role`、`ho_finish_open`、`ho_finish_retry`、`handoff-route` 的傳訊、`handoff-cleanup` 的刪除、`handoff-start` 的 reviewer 確認改用這些函式。
  - 測試要求：重構，不新增測試；`bash tests/test_agent_handoff.sh` 全數通過，做為行為不變的證據（design 的 TDD 策略）。

## 2. host 設定與 loop.yaml

- [x] 2.1 `roles.yaml` 讀取頂層 `host`（預設 `xirp`）、`herdr_session` 與角色的 `host`；未知的 host 在開任何 session 前拒絕；`handoff-start` 把每個角色的 host（herdr 另含 herdr session）寫進 `loop.yaml`；沒有 host 欄位的 `loop.yaml` 一律視為 `xirp`。
  - 測試要求：先寫失敗測試再實作，涵蓋：沒寫 host 時記錄 `xirp`；角色覆寫為 `herdr`；`host: tmux` 被拒絕且什麼都沒開；舊格式 `loop.yaml` 照常以 Xirp 派送。
- [x] 2.2 `handoff-author` 與 `handoff-route` 在 `HERDR_ENV=1` 時不採用 `CHIRP_SESSION_ID`。
  - 測試要求：先寫失敗測試：`HERDR_ENV=1` 加上 `CHIRP_SESSION_ID` 時印出 `XIRP-SESSION-ID: null`；routing log 不記那個值；沒有 `HERDR_ENV` 時照舊。

## 3. 環境檢查（handoff-doctor）

- [x] 3.1 在函式庫新增逐項檢查函式（輸出 `<ok|warn|fail> <area> <message>`）與 `ho_preflight`，涵蓋 design D9 表格的 base、host（xirp）、harness、role、notify；Pi 與範本檢查沿用 `ho_pi_ready`、`ho_template_check`。
  - 測試要求：先寫失敗測試：缺 `codex` 時出現 `fail harness` 並以非零結束；Xirp project 未登錄時 `fail host`；Pi 模型不存在時 `fail role`；沒設通知器時只有 `warn notify`、結束狀態為 0；Claude 模型標示未驗證。
- [x] 3.2 新增 `scripts/handoff/handoff-doctor [change-id]`：沒帶 change 時檢查 `roles.yaml`，帶 change 時檢查 `loop.yaml` 的角色；不改任何檔案、不碰任何 session；`install.sh` 安裝到 `~/.local/bin`。
  - 測試要求：先寫失敗測試：對執行中的迴圈跑完，`loop.yaml` 與交件單不變、假 `xirp` 沒有收到任何寫入呼叫；hookinstall 測試確認 `handoff-doctor` 已安裝。
- [x] 3.3 `handoff-start`、`handoff-role`、`handoff-finish` 在開 session 或寫 `loop.yaml` 前跑 `ho_preflight`，有 `fail` 就印出那幾行並拒絕，`warn` 只印出；移除各指令裡被取代的重複檢查。
  - 測試要求：先寫失敗測試：審查者 harness 未安裝時 `handoff-start` 不開 session、不寫 `loop.yaml`；只有 `warn` 時照常開啟；既有的 Pi 檢查測試全數通過。
- [x] 3.4 文件：`scripts/handoff/README.md` 與 `docs/skills/agent-handoff.md` 新增 `handoff-doctor` 段落（用途、各區檢查、等級、何時會被自動執行）。
  - 測試要求：文件類，不需要測試；以 README 中的指令實際執行一次 `handoff-doctor` 核對輸出格式與說明一致。

## 4. herdr host：開啟

- [x] 4.1 新增假的 `herdr` 測試替身（記錄參數；可設定回傳成功、`agent_pane_busy`、`agent_not_ready`、`agent_blocked`、`server_not_running` 的 JSON）。
  - 測試要求：測試基礎設施；由 4.2 起的測試使用，本身不需要另外的測試。
- [x] 4.2 doctor 的 host 檢查加入 herdr：CLI、選定 session 的 server、`herdr status`；herdr 角色的 harness 缺少 herdr 整合時 `warn`；herdr session 依 pane 內 `HERDR_SESSION`、`herdr_session`、default 的順序決定。
  - 測試要求：先寫失敗測試：server 沒在跑時 `fail host` 且 `handoff-start` 什麼都沒開；在 pane 內（設 `HERDR_ENV=1`、`HERDR_SESSION=dev`）時採用 `dev`；在外面時採用 `herdr_session`。
- [x] 4.3 實作 `ho_herdr_open`：找或開主 repo 的 workspace；依 worktree 開 linked workspace 或用主 repo workspace；每個角色一個以範本 `name` 命名的 tab；`agent start` 遇 `agent_pane_busy` 重試；依 harness 帶入模型、effort、profile、provider；第一則 prompt 另外以 `agent prompt` 送出；輪詢取得原生 Session ID；所有建立都帶 `--no-focus`；`loop.yaml` 記錄 pane、herdr session、原生 Session ID 與迴圈建立的 workspace／tab。
  - 測試要求：先寫失敗測試：假 `herdr` 收到的指令序列正確（主 repo workspace 不存在時先建立；Claude 帶 `--model`／`--effort`／`--name`；Codex 帶 `-m`／`-c model_reasoning_effort=`；Pi 帶 `--provider`／`--model`／`--thinking` 且 worktree 有 `.pi/settings.json`）；`agent_pane_busy` 一次後成功；`loop.yaml` 記錄 pane 與原生 Session ID。

## 5. herdr host：傳訊與 retry

- [x] 5.1 實作 `ho_herdr_message` 與 `ho_herdr_exists`：傳訊前確認 pane 的 agent kind 與已知的原生 Session ID；`agent prompt` 不帶 `--wait`（herdr 0.9.5 的 `--timeout` 需要 `--wait`，所以也不帶 `--timeout`）；不符、不存在或 `agent_blocked` 都算傳送失敗；送出結果不明（例如 `timeout`）時不重送，停下通知使用者。
  - 測試要求：先寫失敗測試：pane 已換成 shell 時沒有送出任何文字且交件單維持未處理；`agent_blocked` 時發一次 attention 通知；正常時審查 prompt 送進記錄的 pane。
  - 審查修正（codex-herdr-r01 F-03、codex-herdr-r03）：送出結果不明的 prompt 存成 `<role>-unconfirmed.txt`；檔案存在期間，開啟、傳訊與收尾的「已開啟」判斷都不送出也不視為成功，使用者核對後刪檔才繼續。驗證：`tests/test_agent_handoff.sh herdr` 的自動收尾與 `handoff-finish` 重試兩個情境。
  - 審查修正（codex-herdr-r04，r01/F-03）：收尾重試對每筆 blocked 交件單只送一次（`finish.retried_for`），不論是否確認送達；使用者刪掉待確認檔後再跑 `handoff-finish`，只回報已送過。驗證：`tests/test_agent_handoff.sh herdr` 的「清除待確認後不重送」與「每筆 blocked 交件單只送一次」。
  - 審查修正（codex-herdr-r05，r01/F-03）：送出收尾重試前，先以 `mkdir` 原子地建立該筆交件單的 claim（迴圈資料夾的 `.finish-retry-<交件單>`），重疊的第二次執行拿不到 claim 就只回報、不送出；host 回報沒送出時移除 claim 以便重試。驗證：`tests/test_agent_handoff.sh herdr` 的「兩次重疊執行只送一次」與「被對話框擋住後仍可重試」。
  - 審查修正（codex-herdr-r06/F-01）：只有 claim 目錄已存在才回報「已送出或正在送出」；`mkdir` 因其他原因失敗時印出錯誤、以非零結束、不送出，恢復後可重試。驗證：`tests/test_agent_handoff.sh herdr` 的「claim 無法建立」情境（以只讓該路徑 `mkdir` 失敗的 PATH shim 注入）。
- [x] 5.2 開啟時遇到 `agent_not_ready` 或第一則 prompt 被拒：保留 pane、記 `pending_prompt`，route 走 retry，通知寫出 workspace 與 tab；重試時只補送 prompt，不開新 pane；不送任何回答對話框的按鍵。
  - 測試要求：先寫失敗測試：信任對話框情境只發一次通知、交件單未處理、假 `herdr` 沒收到 `send-keys`；`handoff-route --foreground` 重試時對同一個 pane 補送 prompt，並把交件單標為已處理。
  - 審查修正（codex-herdr-r01 F-05、codex-herdr-r03）：對話框通知改向 herdr 查 pane 實際所在的 workspace 與 tab（含標籤），重用的 reviewer 也適用；cleanup 不關閉重用 reviewer 的 tab。驗證：`tests/test_agent_handoff.sh herdr` 的重用 reviewer 情境。
- [x] 5.3 routing log 對 herdr 角色記 `model=<範本模型>(template)`；混用 host 的迴圈中，hook 依角色的 host 傳訊。
  - 測試要求：先寫失敗測試：herdr 審查者的 log 行帶 `(template)`；實作者在 xirp、審查者在 herdr 時，兩個方向的訊息分別送到對應的假 CLI。
  - 審查修正（codex-herdr-r03/F-01）：在 herdr pane 中，routing log 記 `session=herdr:<HERDR_PANE_ID> native=<hook 輸入的原生 Session ID>`，不採用繼承的 `CHIRP_SESSION_ID`；Xirp 的寫法不變。驗證：`tests/test_agent_handoff.sh herdr` 與 `route`。
  - 審查修正（codex-herdr-r04，r03/F-01）：手動 `--foreground` 或重試時，停止端記 `session=unknown`，執行者另記 `trigger=xirp:<id>`／`trigger=herdr:<pane>`；這類執行也不以觸發者的 Xirp 模型代填。驗證：`tests/test_agent_handoff.sh herdr` 的手動補跑情境。
- [x] 5.4 文件：README 新增「host」段落（`host`、`herdr_session`、角色覆寫、herdr 的 workspace／tab 配置、信任對話框與 retry、`ghostty + tmux` 為之後可能支援的 host）；`roles.example.yaml` 加上 `host`、`herdr_session` 的註解範例；`SKILL.md` 說明 herdr pane 中的 `XIRP-SESSION-ID`。
  - 測試要求：文件類；hookinstall 測試確認 README 提到 `host:` 與 `herdr_session`，`roles.example.yaml` 仍能被範本檢查接受。

## 6. herdr host：cleanup

- [x] 6.1 實作 `ho_herdr_close`：cleanup 在移除 worktree 前，關閉迴圈建立的 workspace，以及迴圈在主 repo workspace 開的 tab；不關閉不是迴圈建立的東西；預覽列出將關閉的 herdr workspace／tab。
  - 測試要求：先寫失敗測試：新 worktree 的迴圈關閉其 workspace 且順序在 `git worktree remove` 之前；`--worktree here` 的迴圈只關 tab；混用 host 時 Xirp session 被刪、herdr workspace 被關；預覽列出 herdr 項目。
- [x] 6.2 文件：README 的 cleanup 段落與 `docs/diagrams/agent-handoff-cleanup.svg` 說明 herdr 的關閉步驟。
  - 測試要求：文件類；確認 SVG 可正常開啟、文字與 README 一致。

## 7. 整合驗收

- [x] 7.1 完整執行 `bash tests/test_agent_handoff.sh` 與專案的 pre-commit 檢查，全部通過。
  - 測試要求：指令輸出全部通過。
- [x] 7.2 用真實 herdr 跑一個小型迴圈（實作、審查各一輪到 pass，再 cleanup），確認 workspace 分組、tab 名稱、原生 Session ID、信任對話框的 retry、cleanup 後沒有殘留的 pane。
  - 測試要求：無法自動化；把重播步驟、預期結果與實際結果記在 Work Item `WI-20261120-handoff-session-hosts`。

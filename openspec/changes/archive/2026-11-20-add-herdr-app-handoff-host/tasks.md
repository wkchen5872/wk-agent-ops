# Tasks

## 1. host 值與環境檢查

- [x] 1.1 `roles.yaml` 接受 `host: herdr-app`（頂層與角色），寫入 `loop.yaml`；未知值的錯誤訊息列出三個 host。
  - 測試要求：先寫失敗測試：`host: herdr-app` 記入 `loop.yaml`；`host: tmux` 的錯誤列出 `xirp, herdr, herdr-app`；既有 `xirp`／`herdr` 測試不變。
- [x] 1.2 新增假的 `herdr-app`（`status`、`do space.new|tab.new|space.close|tab.close`，記錄參數，回傳 `{space, tab, terminal}`；可切換 app 沒開）與假的 `hc`（`server status`、`get`、`send`、`rm`；可切換 core 沒開、`blocked`、`started:false`、`turn` 不變、terminal 結束）。
  - 測試要求：測試基礎設施；由後續任務的測試使用。
- [x] 1.3 `ho_host_check` 的 `herdr-app` 分支（design D7）：指令存在、`hc server status`、`herdr-app status`，各有 `fail host` 訊息與處理方式；成功時印出 herdr-core 版本。
  - 測試要求：先寫失敗測試：app 沒開時 `fail host` 並提示開啟 Herdr app，`handoff-start` 不開任何 session；core 沒開；缺 `herdr-app` 或 `hc`；全部正常時為 `ok`。
- [x] 1.4 實測 app 沒開時 `herdr-app status` 的實際回應（關閉 app 後執行一次，再重開），確認判斷規則；結果記在 Work Item。
  - 測試要求：無法自動化；記錄指令、結束代碼與輸出摘要。

## 2. 開啟

- [x] 2.1 實作 `ho_happ_open`（design D3、D4）：該 worktree 還沒有迴圈開的 space 就 `space.new`，有就 `tab.new --space`；`--argv` 依 harness 組成，Pi 照常寫入 `.pi/settings.json`；`--task` 帶第一則 prompt；`--focus false`；`loop.yaml` 記錄 terminal、`happ_space`、`happ_tab`、`herdr_app.spaces`；接著輪詢 `hc get`：`turn` 增加或 `working` 視為送達，`blocked` 走對話框流程，等不到就存 unconfirmed 檔、通知一次、不重送。
  - 測試要求：先寫失敗測試：假 `herdr-app` 收到的指令與參數正確（Claude、Codex、Pi 的 argv；`--focus false`；space 名稱是 change ID）；共用 worktree 的審查者用 `tab.new --space`；`--worktree new` 的審查者開自己的 space；`turn` 不變時產生 unconfirmed 檔且只通知一次；`blocked` 時通知寫出 space 與 tab。

## 3. 傳訊與確認

- [x] 3.1 實作 `ho_happ_exists` 與 `ho_happ_message`（design D5、D6）：`hc get` 確認 live、harness、idle/done；`hc send` 看 `started`；`blocked` 時不回答、通知、交件單維持未處理；其他結果存 unconfirmed 檔、不重送。
  - 測試要求：先寫失敗測試：idle 時送達並標為已處理；`blocked`（kind permission）時沒有送出任何文字，且只通知一次；terminal 已結束時算傳送失敗；`started:false` 時存 unconfirmed 檔；混用 host（實作者 `xirp`、審查者 `herdr-app`）時，兩個方向分別送到正確的 CLI。
- [x] 3.2 `handoff-route` 在有 `HC_TERMINAL_ID` 時記錄 `session=herdr-app:<id>`（design D9）。
  - 測試要求：先寫失敗測試：設定 `HC_TERMINAL_ID` 時 routing log 含 `herdr-app:<id>`；沒設定時照舊。

## 4. 關閉

- [x] 4.1 實作 `ho_happ_close`（design D8）：迴圈開的 space 用 `space.close --confirmed true`，其他 space 裡的 tab 用 `tab.close --confirmed true`，再對每個角色的 terminal 執行 `hc rm`；關閉失敗時不移除 worktree；cleanup 預覽列出要關的 space 與 tab。
  - 測試要求：先寫失敗測試：關閉順序在 `git worktree remove` 之前；只關閉迴圈開的 space；app 沒開時以非零結束且 worktree 仍在；預覽列出 herdr-app 項目。

## 5. 文件

- [x] 5.1 `scripts/handoff/README.md` 的 Session hosts 段落新增 `herdr-app`（與 `herdr` 的差別、space 與 tab 配置、app 必須開著、對話框處理）；`roles.example.yaml` 註解列出三個 host；`docs/skills/agent-handoff.md` 同步。
  - 測試要求：文件類；hookinstall 測試確認 README 提到 `herdr-app`，`roles.example.yaml` 仍能通過範本檢查。

## 6. 整合驗收

- [x] 6.1 完整執行 `bash tests/test_agent_handoff.sh`，全部通過。
  - 測試要求：指令輸出全部通過。
- [x] 6.2 用真實 Herdr app 跑一次實作、審查、收尾演練（`finish.trigger: auto`），確認 space 與 tab 出現在 app、prompt 都有送出、cleanup 後沒有殘留的 space 或 terminal。
  - 測試要求：無法自動化；把重播步驟、預期結果與實際結果記在 Work Item `WI-20261120-handoff-session-hosts`。

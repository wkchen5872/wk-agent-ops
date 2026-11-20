# Proposal

## Why

handoff 重構分析的第 2 階段。交接迴圈有三個軸：host、harness、model。目前只有 host 有分派層（`ho_host_*`）；
harness 的知識散在 `scripts/handoff/lib/handoff.sh` 與各指令，以後加入新的 harness（例如 agy）或 host（例如 tmux），要改很多地方。
現況（main `89b1af0`）：
- 同一份 harness 參數對應寫了三遍：xirp 的 effort 欄位（`ho_xirp_create`）、herdr 的 bash 陣列（`ho_herdr_open`）、herdr-app 的 JSON 陣列（`ho_happ_argv`）。
  harness 的其他知識也各自散落：合法值清單（`ho_template_check`）、顯示名稱（`ho_author`）、skill 呼叫語法（`ho_retool`）、
  觸發器檢查（`ho_check_*`），以及 override 格式的正規式（`handoff-start`、`handoff-role` 各一份）。
- 「送出結果不明」的共用機制（`ho_herdr_unconfirmed`、`ho_herdr_held`、`ho_herdr_hold_error` 與 `HO_HERDR_CODE`）
  也被 herdr-app 與收尾流程使用，名稱卻掛在 herdr 底下，造成兩個 host 互相依賴。
- 指令裡有 15 處 Pi 專屬判斷（start 5、role 5、route 3、cleanup 2）；「一個 worktree 只能有一個 Pi 角色」的檢查在 start 與 role 各寫一份；
  `ho_pi_role_key` 其實是通用的「section 轉角色鍵」，名稱卻帶 pi。

## What Changes

- 新增 harness 層：集中在 lib 的一組 `ho_harness_*` 函式，作為 harness 知識的唯一來源：
  - 合法值清單與 override 格式檢查；
  - 顯示名稱；
  - skill 呼叫語法；
  - 啟動參數：回傳 JSON 陣列，herdr 與 herdr-app 共用；
  - xirp 的 effort 欄位名稱；
  - 觸發器檢查。
- 「送出結果不明」機制改成與 host 無關的名稱（`ho_unconfirmed_*`、`HO_HOST_CODE`），herdr、herdr-app、收尾流程改呼叫新名稱。
- Pi 專屬判斷收進 harness 掛勾：
  - 指令不再直接判斷 `harness == pi`，改為呼叫 `ho_harness_*` 掛勾（準備 worktree、交件單檢查與標籤、cleanup 時的設定檔）；
  - 「一個 worktree 一個 Pi 角色」的檢查抽成共用函式，start 與 role 一起使用；
  - `ho_pi_role_key` 改名為 `ho_role_key`。
- 不改任何外部行為：錯誤訊息、`loop.yaml` 欄位、指令選項、通知內容一律不變。

驗收條件：
- 完整測試的斷言名稱與結果，和本 change 開始前完全相同；只多出 harness 層直接測試的新斷言。
- 在 `scripts/handoff/` 中，`claude`、`codex`、`pi` 的參數或 skill 語法只出現在 harness 層。
  可以用 `grep` 確認：`case` 分派 harness 名稱的位置只剩 harness 層。
- 指令檔（`handoff-start`、`handoff-role`、`handoff-route`、`handoff-cleanup`）裡沒有 `== pi` 的判斷，也沒有直接呼叫 `ho_pi_*`。
- lib 中不再有 `ho_herdr_unconfirmed`、`ho_herdr_held`、`ho_herdr_hold_error`、`HO_HERDR_CODE`、`ho_pi_role_key`。

## Capabilities

### New Capabilities

### Modified Capabilities

（純重構，不改變任何規格行為；`.openspec.yaml` 設定 `skip_specs: true`。）

## Impact

- 程式：`scripts/handoff/lib/handoff.sh`、`handoff-start`、`handoff-role`、`handoff-route`、`handoff-cleanup`。
- 測試：在第 1 階段（`split-handoff-tests`）的新結構裡進行；新增 harness 層的直接測試區段。
- 相依：必須在 `split-handoff-tests` 合併之後才開始實作，因為兩者都會改測試；規劃文件可以先完成。
- 文件：`scripts/handoff/README.md` 的維護者說明，補上「新增 harness 要改哪裡」。

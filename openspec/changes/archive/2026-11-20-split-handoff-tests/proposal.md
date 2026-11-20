# Proposal

## Why

`tests/test_agent_handoff.sh` 已經長到 2869 行：15 個區段、約 495 個斷言，依序執行一次要 449 秒（2026-11-20 實測）。
這直接拖慢交接迴圈：每輪實作都要等完整測試，Coordinator 的「可能卡住」門檻也被迫從 10 分鐘放寬到 20 分鐘。

另外有兩個問題：
- 5 個假 CLI（xirp、herdr、herdr-app、hc、pi）以 heredoc 寫在測試檔中間，看不出各自模擬的是哪個版本。
  `herdr agent prompt` 的「`--timeout` 必須搭配 `--wait`」限制，就是因為假 herdr 沒有模擬而沒被測出來。
- 斷言寫成 `cond && ok "名稱" || bad "名稱"`，同一個名稱要寫兩次，日後容易改到不一致。

這是 handoff 重構分析的第 1 階段：先整理測試，作為之後重構正式程式時的安全網。

## What Changes

- 拆檔：每個區段一個檔案，放在 `tests/handoff/<section>.sh`；共用的設定與 helper 移到 `tests/handoff/lib.sh`。
- 假 CLI 移出：xirp、gh、notify.sh、claude、codex、herdr、herdr-app、hc、pi 各自成為 `tests/handoff/fakes/` 下的固定檔案。
  每個檔案開頭註明模擬的真實 CLI 與版本，以及可切換的狀態檔。
- `tests/test_agent_handoff.sh` 保留原本的用法 `[section|all]`，改成執行器：
  - `all` 時平行執行全部區段，並發數可用 `HANDOFF_TEST_JOBS` 調整；
  - 輸出依固定的區段順序列印；
  - 最後印出 `test_agent_handoff: ok` 或 `FAILED`，結束代碼和現在相同。
- 斷言 helper：新增 `check "名稱"`，讀取前一個指令的結束狀態，所以名稱只寫一次。
  現有斷言以機械方式改寫，條件與名稱都不變。
- 不改 `scripts/`、`template/` 等正式程式，也不改任何斷言的條件。

驗收條件：
- 改寫前後，完整執行所列出的斷言名稱與數量完全相同（以 `ok`／`FAIL` 行比對，基線 495 項 ok、0 FAIL）。
- 每個區段都能單獨執行（`bash tests/test_agent_handoff.sh <section>`），結果和該區段在基線中的結果相同。
- 在同一環境中先後量測，完整平行執行（預設並發數）的時間 ≤ 依序執行（`HANDOFF_TEST_JOBS=1`）的 50%；兩者在同一段時間內連續量測，tasks 記錄兩個秒數、比例與當時的 1 分鐘負載。（原訂絕對秒數：180 秒，後改 200 秒；量測機器的背景負載使結果落在 183–207 秒而無法穩定通過，使用者決定改為相對指標，不拆 pi 區段。先前的秒數紀錄保留在 tasks 作為參考。）
- `git diff main -- scripts template` 為空。

## Capabilities

### New Capabilities

### Modified Capabilities

（純測試重構，不改變任何規格行為；`.openspec.yaml` 設定 `skip_specs: true`。）

## Impact

- 測試：`tests/test_agent_handoff.sh`（改為執行器）、新增 `tests/handoff/lib.sh`、`tests/handoff/<section>.sh`（15 個）、`tests/handoff/fakes/*`。
- 文件：`scripts/handoff/README.md` 若有提到測試的寫法或位置則同步；`AGENTS.md` 的相關文件清單補上 `tests/handoff/`。
- 正式程式與已安裝的 handoff 腳本不受影響。

# Design

## Context

動機見 proposal.md 的 Why。現況（2026-11-20，main `89b1af0` 之後）：
- `tests/test_agent_handoff.sh` 2869 行，用 `run_section <name>` 分成 15 個區段：
  kv、write、skill、install、route、notify、mixed、start、finish、doctor、herdr、happ、hookinstall、cleanup、pi。
  區段外的共用程式散在第 4–32、249–460、932–970、1307–1308 行，以及各處 helper。
  因為區段外的程式不論選哪個區段都會執行，所以每個區段現在都能單獨跑。
- 假 CLI 只在共用設定時寫入 `$FAKES` 一次；Pi 的假 CLI 在 pi 區段裡寫入一次。執行期間沒有測試會修改假 CLI。
- 每個測試用 `fresh_state` 在 `$tmp` 底下建立自己的狀態目錄；整個測試共用一個 `$tmp`。
- 依序跑完全部要 449 秒，共 495 項 ok、0 FAIL。基線輸出存在 scratchpad 的 `baseline-handoff.log`。

## Goals / Non-Goals

**Goals:**
- 斷言的名稱、數量與條件完全不變，只改組織方式。
- `bash tests/test_agent_handoff.sh [section]` 的用法不變，交接迴圈與既有文件不用改。
- 完整執行在本機 180 秒內完成。

**Non-Goals:**
- 不新增或刪除斷言，也不修正斷言本身的問題（例如同一斷言 ok／bad 名稱不一致，只記錄，不在這裡改）。
- 不改正式程式，不做 host 合約測試（屬於第 3 階段）。
- 不引入新的測試框架（bats 等），維持純 bash。

## Decisions

### D1：目錄結構
```
tests/
  test_agent_handoff.sh      執行器（入口不變）
  handoff/
    lib.sh                   共用設定與 helper（原本區段外的程式，保持原順序）
    fakes/                   xirp gh notify.sh claude codex herdr herdr-app hc pi
    kv.sh write.sh ... pi.sh 每個區段一個檔案，內容就是原本 if run_section 裡的程式
```
- 不採用「15 個 `tests/test_handoff_*.sh` 放在 tests/ 頂層」：會讓 tests/ 頂層變得雜亂，而且入口會有 15 個；放在子目錄、維持單一入口比較清楚。

### D2：`lib.sh` 的內容與隔離
- 原本區段外的程式依原順序搬進 `lib.sh`，包括路徑變數、`new_repo`、`hook_home`、`new_loop`、`fresh_state`、各種 `*_in` 包裝、git／mv shim。
- 每個區段檔開頭 `source lib.sh`，結尾呼叫 `finish_section <name>`，印出該區段的結果並以 0 或 1 結束。
- 每個區段在自己的行程裡建立自己的 `$tmp`（`mktemp -d`），結束時清掉，所以平行執行時不會共用狀態。

### D3：假 CLI 是固定檔案
- `$FAKES` 改為指向 `tests/handoff/fakes/`。heredoc 的內容原樣搬成檔案，保留執行權限。
- 每個檔案開頭註明：模擬哪個 CLI、對照的真實版本（herdr 0.9.5、hc 0.1.21、herdr-app 0.1.16）、狀態目錄，以及可切換的狀態檔（原本寫在 heredoc 上方的說明一併移過去）。
- 假 CLI 本來就從環境變數指定的狀態目錄讀寫，不需要每次重新產生；Pi 的假 CLI 也改為固定檔案。

### D4：執行器
- `section` 是單一區段名稱時，直接執行該區段檔，輸出和現在相同。
- `all`（預設）時用 `xargs -P "$HANDOFF_TEST_JOBS"` 平行執行全部區段檔，各自的輸出寫進暫存 log；全部結束後，依 D1 的固定順序印出各區段的 log。
  任何區段失敗就印出 `test_agent_handoff: FAILED` 並以 1 結束，否則印出 `test_agent_handoff: ok`。
- `HANDOFF_TEST_JOBS` 預設為 CPU 數與 8 取較小值；設為 1 就等於依序執行，方便除錯。
- 未知的區段名稱以非 0 結束，並列出可用的區段。

### D5：`check` helper 與機械改寫
```bash
check() { local rc=$? name="$1"; if (( rc == 0 )); then ok "$name"; else bad "$name"; return 1; fi; }
```
- 函式剛開始時，`$?` 還是呼叫前那個指令的結束狀態，所以條件寫在前面、`check` 接在後面即可。
- 改寫規則：
  - `COND && ok "N" || bad "N"` 改成 `COND; check "N"`；
  - `COND && ok "N" || { bad "N"; DIAG; }` 改成 `COND; check "N" || { DIAG; }`；
  - 跨多行（行尾 `\`）的條件，照樣把 `check` 接在條件最後。
- 這和原本等價：`a && b && ok` 只有在 a、b 都成功時才會 ok，`a && b; check` 取的也是 `a && b` 這整串的結束狀態。
- 用腳本改寫，再以 D6 的方式核對名稱；腳本處理不了的寫法（例如 `if ... then ok ... else bad ... fi`）改用人工轉換。ok 與 bad 名稱原本就不一致的地方，列成清單記在 tasks，保留 ok 的名稱。

### D6：用「斷言名稱一致」證明行為不變
- 基線：main 上依序完整執行的輸出（scratchpad 的 `baseline-handoff.log`）。
- 每完成一步，就把輸出中 `^  (ok|FAIL) ` 的行排序後，和基線比對；兩邊必須完全相同（目前是 495 行 ok、0 行 FAIL）。
- 平行執行會改變區段之間的順序，但每個區段內的順序不變，所以比對排序後的結果。

## Risks / Trade-offs

- [區段之間有隱藏的依賴，例如在中段才定義的變數或 helper] → 共用程式依原順序整段搬進 `lib.sh`；現在每個區段都能單獨跑，代表沒有依賴其他區段的執行結果。每個區段單獨執行並核對名稱一次。
- [平行執行時負載變高，依賴時間的測試可能不穩定（`HANDOFF_CREATE_WAIT`、`prompt-delay` 製造兩個呼叫重疊的測試）] → 完整平行執行連跑 3 次都要一致；若有區段不穩定，在執行器裡把它排到最後單獨執行，並在 tasks 記錄原因。
- [改寫斷言時改錯條件] → D6 的名稱比對加上逐區段比對；改寫腳本只改 `ok`／`bad` 的部分，不碰條件。

## Migration Plan

- 入口與用法不變，交接迴圈、文件與習慣都不用改。
- 回復：退回本 change 的 commit。

## TDD 策略與測試邊界

- 這是不改變行為的重構，不新增需求測試。正確性由 D6 的名稱一致與每個區段單獨執行的結果保證。
- 執行器的失敗傳遞是新的邏輯：暫時讓一個區段失敗（例如改壞某個區段的假 CLI），確認執行器印出 `FAILED` 並以 1 結束，再還原；結果記在 tasks。

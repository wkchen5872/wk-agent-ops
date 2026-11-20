# Tasks

## 1. 基線

- [ ] 1.1 在 main 上依序完整執行一次 `bash tests/test_agent_handoff.sh`，保存輸出與所需時間，並把排序後的 `^  (ok|FAIL) ` 行存成基線清單。
  - 測試要求：記錄指令、結束代碼、秒數與 ok／FAIL 數量（預期 495／0）；之後每一步都和這份清單比對（design D6）。

## 2. 假 CLI 移出

- [ ] 2.1 把 xirp、gh、notify.sh、claude、codex、herdr、herdr-app、hc、pi 的 heredoc 原樣搬到 `tests/handoff/fakes/`，保留執行權限，開頭註明模擬的 CLI、對照版本、狀態目錄與可切換的狀態檔；`$FAKES` 改為指向這個目錄（design D3）。
  - 測試要求：完整執行的斷言名稱清單和基線完全相同；`grep` 確認測試程式中不再有寫入 `$FAKES/` 的程式。

## 3. 斷言 helper

- [ ] 3.1 在共用 helper 加入 `check`，用腳本把 `COND && ok "N" || bad "N"` 與 `|| { bad "N"; DIAG; }` 兩種寫法改成 `COND; check "N"`；腳本處理不了的寫法以人工轉換；列出 ok 與 bad 名稱原本不一致的位置（design D5）。
  - 測試要求：完整執行的斷言名稱清單和基線完全相同；`grep` 確認除了 `check` 本身之外，已沒有成對的 `&& ok`／`|| bad`；不一致名稱清單記在本 task 下方。

## 4. 拆檔與執行器

- [ ] 4.1 把區段外的共用程式依原順序搬到 `tests/handoff/lib.sh`，每個區段搬成 `tests/handoff/<section>.sh`，開頭 `source lib.sh`、結尾 `finish_section`；每個區段建立自己的 `$tmp`（design D1、D2）。
  - 測試要求：15 個區段逐一單獨執行，每個區段的名稱清單和基線中該區段的部分相同。
- [ ] 4.2 `tests/test_agent_handoff.sh` 改成執行器：單一區段直接執行；`all` 用 `xargs -P "$HANDOFF_TEST_JOBS"` 平行執行並依固定順序印出；未知區段以非 0 結束並列出可用區段；失敗時印 `FAILED` 並以 1 結束（design D4）。
  - 測試要求：完整平行執行連跑 3 次，名稱清單都和基線相同；記錄每次秒數，目標 180 秒內；暫時改壞一個區段，確認印出 `FAILED` 且結束代碼為 1，再還原；`HANDOFF_TEST_JOBS=1` 時結果相同。

## 5. 文件與收尾

- [ ] 5.1 檔案開頭的 Usage 說明更新；若 `scripts/handoff/README.md` 或 `AGENTS.md` 的相關文件清單提到 handoff 測試的位置或寫法，一併同步，補上 `tests/handoff/` 的說明。
  - 測試要求：文件類；照文件中的指令執行一次，確認可用。
- [ ] 5.2 確認 `git diff main -- scripts template` 為空，並執行 repo 其他會用到 handoff 的測試檔（`tests/test_workflow.sh` 等），全部通過。
  - 測試要求：指令輸出全部通過、diff 為空。

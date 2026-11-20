# Tasks

## 0. 前置

- [ ] 0.1 確認 `split-handoff-tests` 已封存並合併到 main，把本分支 rebase 到 main；完整執行 `bash tests/test_agent_handoff.sh`，保存排序後的 `^  (ok|FAIL) ` 斷言名稱清單作為基線。
  - 測試要求：記錄 main 的 commit、結束代碼、秒數與 ok／FAIL 數量；之後每一步都和這份清單比對（design D6）。

## 1. 「送出結果不明」改成與 host 無關的名稱

- [ ] 1.1 把 `ho_herdr_unconfirmed`、`ho_herdr_held`、`ho_herdr_hold_error`、`HO_HERDR_CODE` 改名為 `ho_unconfirmed_keep`、`ho_unconfirmed_file`、`ho_unconfirmed_guard`、`HO_HOST_CODE`，更新所有呼叫處與註解，不改邏輯與輸出訊息（design D3）。
  - 測試要求：斷言名稱清單與基線相同；`grep` 確認 `scripts/handoff/` 已沒有舊名稱。

## 2. harness 層

- [ ] 2.1 新增 `harness` 測試區段：以表格檢查 `ho_harness_valid`、`ho_override_valid`、`ho_harness_tool`、`ho_harness_skill`、`ho_harness_argv`、`ho_harness_xirp_effort_key` 對 claude、codex、pi 的輸出（含 codex profile、Pi provider、含空白的 name），並加入執行器的區段清單。
  - 測試要求：先執行，記錄因函式不存在而失敗的 Red 證據（指令、失敗斷言、結束代碼）。
- [ ] 2.2 在 lib 新增 `# --- harness` 區塊與 `HANDOFF_HARNESSES`，實作 design D2 的函式；`ho_template_check`、`ho_author`、`ho_retool`、`ho_xirp_create`、`handoff-start`／`handoff-role` 的 override 檢查改用這些函式。
  - 測試要求：2.1 的區段通過（Green）；斷言名稱清單只比基線多出 `harness` 區段的名稱，其餘相同。
- [ ] 2.3 herdr 與 herdr-app 的啟動參數改用 `ho_harness_argv`（herdr 以 bash 3.2 相容的逐行讀取轉成陣列），移除重複的參數對應；doctor 的觸發器檢查改用 `ho_harness_check_trigger`。
  - 測試要求：斷言名稱清單同上；herdr 與 herdr-app 區段中檢查完整參數的斷言（含 `--name` 的空白）都通過；用 `/bin/bash` 3.2 執行 herdr 區段一次，確認通過。

## 3. Pi 掛勾

- [ ] 3.1 把「一個 worktree 一個 Pi 角色」抽成 `ho_harness_shared_worktree_error`，`handoff-start` 與 `handoff-role` 共用；錯誤訊息不變（design D4）。
  - 測試要求：斷言名稱清單同上；start 與 role 的「second Pi role in one worktree」斷言都通過。
- [ ] 3.2 新增 `ho_harness_prepare_worktree`、`ho_harness_worktree_ready`、`ho_harness_role_change_files`、`ho_harness_record_check`、`ho_harness_record_label`、`ho_harness_owned_files`、`ho_harness_cleanup_files`；`handoff-start`、`handoff-role`、`handoff-route`、`handoff-cleanup` 改呼叫這些掛勾，Pi 的實作仍由既有的 `ho_pi_*` 提供；`handoff-role` 的 Pi 設定檔邏輯原樣搬移。
  - 測試要求：斷言名稱清單同上；`grep` 確認這四個指令沒有 `== pi` 判斷，也沒有 `ho_pi_` 呼叫。
- [ ] 3.3 `ho_pi_role_key` 改名為 `ho_role_key`，更新所有呼叫處（design D5）。
  - 測試要求：斷言名稱清單同上；`grep` 確認舊名稱完全消失。

## 4. 文件與收尾

- [ ] 4.1 `scripts/handoff/README.md` 新增一小段維護者說明：harness 層的位置、加入新 harness 要補哪些函式與測試；並記錄 Non-Goals 中「herdr-app 的送出結果不明訊息仍寫 herdr」的已知問題。
  - 測試要求：文件類；hookinstall 測試照常通過。
- [ ] 4.2 完整執行全部測試並檢查 proposal 的 grep 類驗收條件：harness 名稱的 `case` 分派只剩 harness 層；指令中沒有 Pi 專屬判斷；舊名稱都已移除。
  - 測試要求：完整測試的斷言名稱清單 = 基線 + `harness` 區段；每一項 grep 結果記在本 task 下方。

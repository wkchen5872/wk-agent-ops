# Tasks

> **驗證方式調整（使用者的決定）**：改用 agent-protocol §4 的分層驗證以縮短時間。基線仍完整執行一次並保存斷言名稱清單（0.1）；各 task 的中間步驟只跑受影響的區段，並只和基線中這些區段的斷言比對（區段依序輸出的斷言必須與基線完整日誌中連續的一段相同）：1.x 跑 herdr、happ、finish；2.x 跑 harness、herdr、happ、doctor、start（含 override）與 role；3.x 跑 start、role、route、cleanup、pi；bash 3.2 檢查照舊只跑 herdr；4.2 交件前跑一次完整測試，完整名稱清單須 = 基線 + harness 區段。執行器沒有 `role` 區段，handoff-role 的測試主要在 `finish` 區段（另有少數在 herdr、pi），所以「role」以 `finish` 區段執行。下方各 task 原有的「斷言名稱清單與基線相同」都依此解讀。

## 0. 前置

- [x] 0.1 確認 `split-handoff-tests` 已封存並合併到 main，把本分支 rebase 到 main；完整執行 `bash tests/test_agent_handoff.sh`，保存排序後的 `^  (ok|FAIL) ` 斷言名稱清單作為基線。
  - 測試要求：記錄 main 的 commit、結束代碼、秒數與 ok／FAIL 數量；之後每一步都和這份清單比對（design D6）。
  - 基線：main `da53c17` 已含封存的 `split-handoff-tests`，本分支只多一個規劃 commit，不需 rebase；`bash tests/test_agent_handoff.sh` 結束代碼 0、213 秒、495 ok／0 FAIL。

## 1. 「送出結果不明」改成與 host 無關的名稱

- [x] 1.1 把 `ho_herdr_unconfirmed`、`ho_herdr_held`、`ho_herdr_hold_error`、`HO_HERDR_CODE` 改名為 `ho_unconfirmed_keep`、`ho_unconfirmed_file`、`ho_unconfirmed_guard`、`HO_HOST_CODE`，更新所有呼叫處與註解，不改邏輯與輸出訊息（design D3）。
  - 測試要求：斷言名稱清單與基線相同；`grep` 確認 `scripts/handoff/` 已沒有舊名稱。
  - 結果：herdr 60、happ 42、finish 32 個斷言全部 ok，且與基線的對應段落相同；`grep` 在 `scripts/handoff/` 找不到四個舊名稱。

## 2. harness 層

- [x] 2.1 新增 `harness` 測試區段：以表格檢查 `ho_harness_valid`、`ho_override_valid`、`ho_harness_tool`、`ho_harness_skill`、`ho_harness_argv`、`ho_harness_xirp_effort_key` 對 claude、codex、pi 的輸出（含 codex profile、Pi provider、含空白的 name），並加入執行器的區段清單。
  - 測試要求：先執行，記錄因函式不存在而失敗的 Red 證據（指令、失敗斷言、結束代碼）。
  - Red：`bash tests/test_agent_handoff.sh harness` 結束代碼 1；19 個 FAIL（如 `FAIL claude is a valid harness`），原因是 `ho_harness_valid: command not found` 等函式不存在；11 個「拒絕」案例因 `!` 反轉找不到指令而暫時通過，抽出函式後才有判別力。
- [x] 2.2 在 lib 新增 `# --- harness` 區塊與 `HANDOFF_HARNESSES`，實作 design D2 的函式；`ho_template_check`、`ho_author`、`ho_retool`、`ho_xirp_create`、`handoff-start`／`handoff-role` 的 override 檢查改用這些函式。
  - 測試要求：2.1 的區段通過（Green）；斷言名稱清單只比基線多出 `harness` 區段的名稱，其餘相同。
  - 結果（與 2.3 一起跑）：harness 30 ok（Green）；herdr 60、happ 42、doctor 19、start 28、finish（role）32 全部 ok 且與基線段落相同。`ho_retool` 解析舊 skill 前綴也改由 `ho_harness_skill` 提供（取最長的前綴），讓 skill 語法只留在 harness 層。
  - 修正 codex-extract-handoff-r01/F-01：共用流程仍持有 harness 規則。新增 `ho_harness_fields`、`ho_harness_template_check`（Pi 的 provider／billing／effort／model 規則、只有 Pi 可設 provider／billing、只有 Codex 可設 profile）、`ho_override_fields`（拆 Pi 的 provider/model）、`ho_harness_xirp_label`（Xirp 通知標籤）與 `HANDOFF_HARNESS_KEYS`；`ho_template_check`、`ho_apply_override`、`ho_copy_template`、`ho_agent_label` 改呼叫它們，錯誤訊息與檢查順序不變。Red：新測試套到受審版 `87b5f9d` 時 harness 區段結束代碼 1、9 個 FAIL（函式不存在，結構檢查也命中）。
- [x] 2.3 herdr 與 herdr-app 的啟動參數改用 `ho_harness_argv`（herdr 以 bash 3.2 相容的逐行讀取轉成陣列），移除重複的參數對應；doctor 的觸發器檢查改用 `ho_harness_check_trigger`。
  - 測試要求：斷言名稱清單同上；herdr 與 herdr-app 區段中檢查完整參數的斷言（含 `--name` 的空白）都通過；用 `/bin/bash` 3.2 執行 herdr 區段一次，確認通過。
  - 結果：同上；`ho_happ_argv` 已刪除，herdr 以逐行讀取取 `.[1:]`；`/bin/bash tests/handoff/herdr.sh`（GNU bash 3.2.57）結束代碼 0、60 ok。
  - 修正 codex-extract-handoff-r01/F-02：`ho_herdr_open` 先以命令替換完整解碼 argv，jq 失敗就回報 `cannot read the <role>'s agent arguments; pane <pane> is kept for a retry` 並回傳 1，不呼叫 `agent start`。假 herdr 新增 `argv-<pane>` 紀錄（以 NUL 分隔交給 jq）。Red：只截斷解碼的 jq 替身讓 `handoff-start` 帶 `--model opus` 啟動並送出 prompt（FAIL）；修正後兩個新斷言都通過，含空白的名稱仍是單一參數。
  - 修正 codex-extract-handoff-r02/F-01：`$(...)` 會去掉尾端換行，渲染成空字串的最後一個參數（如 `--name` 的值）因此消失。改為在解碼結果後加哨兵 `.`，去掉哨兵後以 `printf '%s'` 讀入陣列，jq 失敗仍回傳 1。Red：reviewer 名稱為 `{report}` 的首次路由，Herdr 收到 `["--model","opus","--effort","high","--name"]`（FAIL）；修正後收到含空字串的六個參數。另加「解碼失敗後在同一 pane 重試，只啟動與 prompt 各一次、參數完整」的斷言。

## 3. Pi 掛勾

- [x] 3.1 把「一個 worktree 一個 Pi 角色」抽成 `ho_harness_shared_worktree_error`，`handoff-start` 與 `handoff-role` 共用；錯誤訊息不變（design D4）。
  - 測試要求：斷言名稱清單同上；start 與 role 的「second Pi role in one worktree」斷言都通過。
  - 結果（3.1–3.3 一起跑，另加 doctor、herdr，因為 `ho_role_key` 也在它們的路徑上）：start 28、finish（role）32、route 30、cleanup 15、pi 156、doctor 19、herdr 60 全部 ok 且與基線段落相同；`two Pi roles in the implementer worktree are refused, naming both`、`handoff-role refuses a second Pi role in the implementer worktree` 都通過。
- [x] 3.2 新增 `ho_harness_prepare_worktree`、`ho_harness_worktree_ready`、`ho_harness_role_change_files`、`ho_harness_record_check`、`ho_harness_record_label`、`ho_harness_owned_files`、`ho_harness_cleanup_files`；`handoff-start`、`handoff-role`、`handoff-route`、`handoff-cleanup` 改呼叫這些掛勾，Pi 的實作仍由既有的 `ho_pi_*` 提供；`handoff-role` 的 Pi 設定檔邏輯原樣搬移。
  - 測試要求：斷言名稱清單同上；`grep` 確認這四個指令沒有 `== pi` 判斷，也沒有 `ho_pi_` 呼叫。
  - 結果：`grep -nE '== pi|ho_pi_'` 在四個指令沒有結果。設計表沒有列到 `handoff-start` 在建立 worktree 前「分支追蹤 `.pi/settings.json`」的檢查，所以多加一個掛勾 `ho_harness_branch_error`（同樣是印出原有訊息後回傳 1）。`ho_finish_check`／`ho_finish_retry` 也改呼叫 `ho_harness_record_check`。
  - 修正 codex-extract-handoff-r01/F-01：`ho_open_role` 不再自己判斷 Pi，與 `handoff-start` 共用 `ho_harness_ready`、`ho_harness_worktree_error`（取代 `ho_harness_worktree_ready`，Pi 的訊息移到 harness 層，呼叫端各自加上原有的結尾）與 `ho_harness_prepare_worktree`，順序不變；doctor 的角色檢查移為 `ho_harness_check_role`；route 的 Pi 模型改由 `ho_harness_record_model` 提供。
- [x] 3.3 `ho_pi_role_key` 改名為 `ho_role_key`，更新所有呼叫處（design D5）。
  - 測試要求：斷言名稱清單同上；`grep` 確認舊名稱完全消失。
  - 結果：`grep -rn ho_pi_role_key scripts tests` 沒有結果；`ho_role_key` 移到 `ho_role_tsec` 旁邊，並改成通用的註解。

## 4. 文件與收尾

- [x] 4.1 `scripts/handoff/README.md` 新增一小段維護者說明：harness 層的位置、加入新 harness 要補哪些函式與測試；並記錄 Non-Goals 中「herdr-app 的送出結果不明訊息仍寫 herdr」的已知問題。
  - 測試要求：文件類；hookinstall 測試照常通過。
  - 結果：README 新增 `## For maintainers`；`bash tests/test_agent_handoff.sh hookinstall` 通過；`bash tests/test_documentation_authoring.sh` 結束代碼 0。
- [x] 4.2 完整執行全部測試並檢查 proposal 的 grep 類驗收條件：harness 名稱的 `case` 分派只剩 harness 層；指令中沒有 Pi 專屬判斷；舊名稱都已移除。
  - 測試要求：完整測試的斷言名稱清單 = 基線 + `harness` 區段；每一項 grep 結果記在本 task 下方。
  - 完整測試：`bash tests/test_agent_handoff.sh` 結束代碼 0、170 秒、525 ok／0 FAIL；排序後的名稱清單與「基線 495 + harness 30」逐行相同（`cmp`）。
  - `grep -nE '(^|[[:space:](|])(claude|codex|pi)\)' scripts/handoff/handoff-* scripts/handoff/lib/handoff.sh`：只有 lib 第 153–186 行，都在 `# --- harness` 區塊（第 145–281 行）內。
  - `grep -nE '== pi|!= pi|ho_pi_' scripts/handoff/handoff-{start,role,route,cleanup}`：沒有結果。
  - `grep -rnE 'ho_herdr_unconfirmed|ho_herdr_held|ho_herdr_hold_error|HO_HERDR_CODE|ho_pi_role_key|ho_happ_argv' scripts tests`：沒有結果。
  - `/skill:` 在 harness 區塊外只出現在註解。lib 內部仍有 Pi 的 `[[ … == pi ]]` 檢查（`ho_template_check` 的 provider／billing、`ho_open_role`、`ho_check_role`），第 1 輪因為它們不是 `case` 分派、也不在指令內而沒有處理；審查 r01/F-01 要求一併移出，修正輪已移入 harness 層（見下）。
  - 修正輪 r01：`bash tests/test_agent_handoff.sh` 結束代碼 0、178 秒、537 ok／0 FAIL；基線 495 個名稱全部保留，新增 42 個 = harness 區段 40 個 + herdr 的 F-02 2 個。harness 區段新增結構檢查：harness 區塊與 `# --- Pi roles` 區塊以外（排除 Pi 觸發器自己的 `handoff-pi-trust`），沒有與 harness 名稱比較（`==`／`!=`，涵蓋 `if`／`[[ … ]]`／jq）、以它分派 `case` 或呼叫 `ho_pi_*`／`HANDOFF_PI_*` 的程式。
  - 修正輪 r02：完整測試結束代碼 0、196 秒、539 ok／0 FAIL；基線 495 個名稱全部保留，比 r01 多 herdr 的 2 個 r02/F-01 斷言。

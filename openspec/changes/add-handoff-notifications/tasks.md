# Tasks

## 1. 前置

- [ ] 1.1 確認 `refine-notify-core` 已合併並部署（事件對照表、範本與取代函式可用），並以 `xirp session get` 記錄 Claude 與 Codex Session 回報工具、模型與 effort 的實際欄位。測試要求：查證任務；完成條件是 Work Item `WI-20261118-notify-optimization` 有兩種工具的欄位名稱與範例值。

## 2. 交接端送出結構化事件

- [ ] 2.1 `ho_notify_user` 改為以種類與欄位組成 JSON，呼叫通知腳本的 `handoff` 事件，移除 `NOTIFY_ACTION_REQUIRED=true` 覆寫。測試要求：先在 `tests/test_agent_handoff.sh` 寫失敗測試，假通知腳本記錄事件名稱、JSON 與環境變數；斷言事件為 `handoff`、JSON 含種類與 change，且不再帶覆寫。
- [ ] 2.2 `handoff-route` 在路由完成後依交件單送出 `implement`、`review`、`finish` 事件，補上目前沒有通知的實作交件與審查退回；`{next}` 依實際動作產生，commit 縮成 7 碼。測試要求：先寫失敗測試，涵蓋實作交件、退回、通過且 `auto`、收尾完成各一案，檢查種類、輪次、commit 與下一步；既有路由測試維持通過。
- [ ] 2.3 需要使用者處理的情況改送 `attention`：blocked、輪數上限、worktree 不乾淨或版本不符、無法開啟或移動審查 worktree、無法判讀交件單、收尾被拒或停下、通過且 `ask`。測試要求：先寫失敗測試，每個來源各一案；通過且 `ask` 的下一步為 `handoff-finish <change-id>`。
- [ ] 2.4 Agent 資訊：從同一次 Xirp 查詢取得工具、模型、effort（`effort` 或 `reasoning_effort`），組成 `agent` 欄位；讀不到時省略該部分。測試要求：先寫失敗測試，涵蓋三項齊全、缺 effort、Xirp 查詢失敗（仍路由、仍送出不含 Agent 的通知）。
- [ ] 2.5 同一張交件單只通知一次，通知失敗不影響路由與結束狀態。測試要求：先寫失敗測試——Agent 再次停下不重複通知；假通知腳本回傳非零時 hook 仍以成功結束且路由已完成。

## 3. 通知端的事件、開關與範本

- [ ] 3.1 事件對照表新增四個交件單事件，新增內建範本 `handoff-implement`、`handoff-review`、`handoff-finish`、`handoff-attention`，標題帶 Agent 與 Session 標籤。測試要求：先在 `scripts/notify/telegram/test.sh` 寫失敗的 dry-run 測試，驗證四種輸出、Agent 部分缺少時的格式，以及交件單事件不使用等待回應的範本。
- [ ] 3.2 三個開關 `NOTIFY_HANDOFF_IMPLEMENT`、`NOTIFY_HANDOFF_REVIEW`、`NOTIFY_HANDOFF_FINISH`（缺少時為開）；`attention` 在 Telegram 啟用時一律送出。測試要求：先寫失敗測試，涵蓋缺少鍵、各自關閉、其他類不受影響、所有開關與一般分類皆關時 `attention` 仍送出、Telegram 停用時不送。
- [ ] 3.3 設定選單列出三個交件單開關並說明「需要你處理」一律送出；儲存只寫這三個鍵。測試要求：先寫失敗測試，驗證選單文字與儲存後的設定檔，其他鍵與憑證不變。

## 4. 文件與部署

- [ ] 4.1 更新 `scripts/handoff/README.md`（通知種類、開關、不可關閉的項目、Agent 資訊）、`docs/notify/telegram.md`（三個設定鍵與四個範本）、`docs/workflow/local-development.md` 的交接迴圈段落。測試要求：`tests/test_documentation_authoring.sh` 通過；文件列出的設定鍵與範本名稱和程式一致（以 grep 檢查）。
- [ ] 4.2 確認 `scripts/handoff/install.sh` 與 `scripts/notify/telegram/update.sh` 重新部署後新事件可用，登記的 hook 指令不變。測試要求：以暫時 HOME 的測試驗證部署後的檔案與登記內容；兩個設定檔的 hook 指令與變更前相同。

## 5. 整合驗證

- [ ] 5.1 執行完整檢查：`tests/test_*.sh` 與 `scripts/notify/telegram/test.sh` 全部通過、`openspec validate add-handoff-notifications --strict` 通過。
- [ ] 5.2 真實演練（需使用者在場，結果記入 Work Item）：在演練用的 repo 跑一輪含一次退回的迴圈，確認依序收到實作完成、審查退回、實作完成、審查通過（等你執行 `handoff-finish`）、收尾完成，每則有 Agent 資訊與下一步；關閉一個開關後該類不再出現，「需要你處理」仍會送出。

## Workflow follow-up

- 依使用者授權以 `openspec-commit` 封存並提交。
- 觀察一段時間後，再決定是否新增「已送交件單通知時略過 Task Complete」的選項（不在本 change）。

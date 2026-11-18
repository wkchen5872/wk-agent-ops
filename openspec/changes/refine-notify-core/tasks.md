# Tasks

## 1. 前置查證（結果記入 Work Item `WI-20261118-notify-optimization`）

- [x] 1.1 擷取 Claude Code 真實的 `Notification` 輸入：授權詢問與等待輸入各一次，記錄 `notification_type`、`transcript_path`、`message` 是否存在、詢問出現到 hook 觸發的時間，以及能否從紀錄尾端取得該請求的工具呼叫 ID；另外連續觸發兩次授權詢問（第一次回答後立即出現第二次），記錄兩次之間有哪些事件可作為解除證據。測試要求：查證任務，無自動測試；完成條件是 Work Item 有去除敏感內容的輸入欄位清單與時間。
- [x] 1.2 擷取 Codex 真實的 `PermissionRequest` 輸入欄位，並在一次自動審核期間每秒查詢 daemon，記錄 `waitingOnApproval` 是否出現與持續多久，以及輸入或 Session 紀錄中能否取得請求的呼叫 ID；在 daemon 不可連的 Session 重複一次，記錄紀錄檔在核准前後的差異。測試要求：查證任務；完成條件是 Work Item 有欄位清單與旗標時間線。
- [ ] 1.3 擷取 Antigravity 真實的 Stop 輸入（正常完成、使用者取消各一次），並觀察工具確認等待期間與解除時狀態列的回報頻率。測試要求：查證任務；完成條件是 Work Item 有 `terminationReason` 實際值與狀態列回報的時間線。若任一工具拿不到 design 決策 4 表中的等待身分或解除證據，先更新 design 與 spec（該工具改用每個起始訊號一個新身分）再繼續第 4 組。

## 2. 範本與事件對照表（行為不變）

- [x] 2.1 在 `scripts/notify/telegram/test.sh` 把現有每種事件的輸出錄成基準測試（工作結束、Codex 與 Claude 的等待回應、Antigravity 完成與停止、未知事件）。測試要求：先寫測試並確認在現行程式下通過，作為重構的防護；不得修改既有斷言。
- [x] 2.2 新增內建範本 `scripts/notify/telegram/templates/*.md` 與取代函式：`{name}` 取代、值的跳脫、只含參數且為空的行移除、未知參數保留、不執行範本內容。測試要求：先寫失敗測試，涵蓋 spec `notify-message-templates` 的取代、跳脫、空行、未知參數與 shell 語法情境。
- [x] 2.3 新增事件對照表 `scripts/notify/telegram/events.tsv`，`hook.sh` 改為解析後查表取得分類與範本，移除組訊息的 `case`。測試要求：2.1 的基準測試全部維持通過；另先寫失敗測試驗證已知事件經對照表解析、未知事件維持現行行為。
- [x] 2.4 使用者範本覆寫：`~/.config/ai-notify/templates/<name>.md` 優先，空檔或讀不到時用內建；部署內建範本與對照表到 `~/.config/ai-notify/hooks/`，安裝、更新、修復、移除都不碰使用者範本目錄。測試要求：先寫失敗測試，以暫時 HOME 驗證覆寫、退回，以及更新前後使用者範本逐位元相同。

## 3. 四個分類與設定

- [x] 3.1 `config.sh` 改為四個分類鍵與 design 決策 2 的取值順序（環境變數新鍵、環境變數舊鍵、設定檔新鍵、設定檔舊鍵、層級預設）。測試要求：先寫失敗的表格化測試，涵蓋 design 決策 2 表格的每一列、新舊並存、同來源一真一假、環境變數新鍵與舊鍵並存、環境變數舊鍵覆寫，以及空值與 `yes` 這類無效值視為未定義。
- [x] 3.2 設定選單改為工作結束、授權要求、等待回應、異常停止，說明授權要求的延遲；儲存時寫入四個新鍵並移除三個舊鍵。測試要求：先寫失敗測試，驗證選單文字不再出現「既有操作提醒」；以「`NOTIFY_ACTION_REQUIRED=true`、`NOTIFY_CODEX_HUMAN_APPROVAL=false`、`NOTIFY_CODEX_USER_INPUT=true`」的設定檔不切換任何項目直接儲存，斷言得到 `NOTIFY_AUTHORIZATION=true`、`NOTIFY_USER_INPUT=true`、三個舊鍵消失，無關的鍵與憑證不變、權限 600。
- [x] 3.3 改通知層級只寫 `NOTIFY_LEVEL` 與 `NOTIFY_COMPLETION`。測試要求：先寫失敗測試——授權關閉時改層級，改完授權仍為關閉。
- [x] 3.4 Claude Code 的 Notification 依 `notification_type` 分流：`permission_prompt` 為授權；`idle_prompt`、`agent_needs_input`、`elicitation_dialog`、`elicitation_url_dialog` 與沒有類型者為等待回應；其他類型不送。測試要求：先寫失敗測試，各類型各一個案例，含「沒有類型且環境變數 `NOTIFY_ACTION_REQUIRED=true` 仍送出」。

## 4. 授權延遲確認

- [x] 4.1 共同機制：帶等待身分的標記、脫離 hook 的背景檢查（到期時身分不符即結束）、`NOTIFY_AUTHORIZATION_DELAY_SECONDS`（預設 30、0 為立即、無效值用預設）、同一段等待只通知一次、以解除證據與回合結束清除標記、無法確認時送「無法確認」的通知。測試要求：先寫失敗測試，把延遲設為數秒，驗證 hook 立即返回、延遲前無訊息、延遲後恰一則、提前解除則無訊息、同一請求重複訊號不重複；並以兩個可重播案例固定行為——(a) 已通知後解除，同一 Session 再次等待，第二次在自己的延遲後通知；(b) 第一段等待解除後、第一個檢查到期前開始第二段等待，第一個檢查到期時不送也不清除，第二段在自己的延遲後才通知。另外涵蓋沒有請求識別的情境（design 決策 3 的表：重複訊號不延後、持續重複只有一則、已通知後沒有解除證據的訊號不再通知、距通知超過 `NOTIFY_AUTHORIZATION_REARM_SECONDS` 後重新武裝、差一秒未到時仍合併、有解除證據後立即重新武裝），並以邊界測試確認重新武裝只適用已通知的標記——重新武裝時間短於延遲、等於延遲、以及延遲長於預設重新武裝時間三種設定下持續送出訊號，第一則通知都在延遲到期時發出且之前沒有任何通知；非數字與負值使用預設；時間在測試中縮短為數秒；並以先持有 Session 鎖再觸發起始訊號與檢查的方式，驗證比對後標記不會被取代、新的等待不會被舊檢查送出或清除。
- [x] 4.2 Claude Code：`permission_prompt` 啟動延遲確認，以 `transcript_path` 尾端是否有未取得結果的工具呼叫判斷。測試要求：先寫失敗測試，以最小的假紀錄檔涵蓋「仍無結果」「已有結果」「紀錄讀不到（送無法確認）」「已通知後回答、Session 停下後再次詢問可再通知」；訊息不得含指令內容。
- [x] 4.3 Antigravity：狀態列的確認等待改為啟動延遲確認，回報 false 時清除標記；依 1.3 的結果補上其他清除時機。測試要求：先寫失敗測試，涵蓋持續等待、延遲內解除、重複回報 true 不延後通知（第 0、10 秒各一次仍在第 30 秒通知）、回報 false 後再次等待是新的一段、沒有 false 的第二次 true 併入前一段、對話 `Stop` 清除標記、Telegram 停用時仍清除標記、狀態列輸出不變。
- [x] 4.4 Codex：`PermissionRequest` 不再立即送出；`wait.py` 改為旗標持續超過延遲才送確認的通知，旗標消失後再出現視為新的等待；daemon 無法查詢時依 Session 紀錄：延遲內有結果則不通知，否則送「無法確認」的通知；同步問題維持看到旗標即通知。測試要求：先寫失敗測試，以既有的假 daemon 資料涵蓋自動審核在延遲內解除（之後指令再執行多久都不通知）、旗標持續超過延遲、旗標消失後再出現、只有問題等待且 daemon 不可用、沒有請求的安靜回合；daemon 不可用的三個固定案例——真的在等、已核准仍在執行、紀錄讀不到——各得到一則「無法確認」且沒有確認的文字，延遲內紀錄已有結果則無通知。
- [x] 4.5 授權通知的範本與隱私：新增 `authorization` 與 `authorization-unconfirmed` 兩個範本，只含工具、專案、Session 標籤、時間與請求工具的通用標籤；後者明寫「可能在等待授權，無法確認」。測試要求：先寫失敗測試，輸入帶有指令與參數的請求，斷言訊息不含這些內容。

## 5. Antigravity 完成判斷

- [x] 5.1 終止原因不分大小寫比對：`NO_TOOL_CALL` 與 `model_stop` 且 `fullyIdle` 為完成；`USER_CANCELED` 不通知；其餘為停止並顯示固定標籤，未知原因用通用標籤。測試要求：先寫失敗測試，涵蓋 spec 的六個情境，並確認訊息不含原始錯誤文字。

## 6. 狀態檔清理

- [x] 6.1 檢查啟動時清除超過 7 天、鎖未被持有、且符合通知自有命名規則的狀態檔（Codex 的三種檔案成組處理，含延遲確認的標記）。測試要求：先寫失敗測試，在暫時的狀態目錄放入過期、近期、被鎖住與無關的檔案，斷言只有過期且未鎖的自有檔案被刪除。

## 7. 文件與部署

- [x] 7.1 更新 `docs/notify/telegram.md`、`docs/notify/architecture.md`、`scripts/notify/README.md`：四個分類與新舊設定鍵、延遲確認與各工具的判斷依據及限制、範本位置與參數、Antigravity 終止原因對照、狀態檔清理。測試要求：`tests/test_documentation_authoring.sh` 通過；文件列出的設定鍵與參數和程式一致（以 grep 檢查）。
- [x] 7.2 `update.sh` 與 `install.sh` 部署對照表與內建範本，`status` 顯示延遲秒數與正在使用的使用者範本。測試要求：先寫失敗測試，以暫時 HOME 驗證部署後的檔案、重跑不重複、`status` 輸出。

## 8. 整合驗證

- [x] 8.1 執行完整檢查：`scripts/notify/telegram/test.sh` 與 `tests/test_*.sh` 全部通過、`openspec validate refine-notify-core --strict` 通過。
- [ ] 8.2 真實驗收（需使用者在場，結果記入 Work Item）：重新部署後，Codex 一次自動審核放行的請求不產生通知；Codex、Claude Code、Antigravity 各一次停著等超過延遲的授權產生一則通知；Claude 與 Codex 的提問立即通知；Antigravity 正常完成顯示 Task Complete；放入一個使用者範本後通知改用該範本。

## Workflow follow-up

- 依使用者授權以 `openspec-commit` 封存並提交。
- `add-handoff-notifications` 依賴本 change 的範本與事件對照表，本 change 合併回 main 後才開始實作。

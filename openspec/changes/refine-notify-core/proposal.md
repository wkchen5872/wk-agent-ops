# Proposal

## Why

Telegram 通知現在有三個問題，都來自同一個原因：通知發在「事件出現」的那一刻，而不是「真的需要使用者」的那一刻。

- **Codex 授權假警報。** 每個 PermissionRequest hook 都會發「Approval requested」，但本機 Codex 使用自動審核，
  2026-11-16～18 的 156 個 Session、226 次越界請求全部自動放行，沒有一次真的等使用者（中位數 5.9 秒、p90 10.6 秒、最長 31.7 秒）。
- **Antigravity 正常完成被顯示成 Task Stopped。** hook 只認得舊的終止原因 `model_stop`；`agy` 1.5.10 的正常完成是 `NO_TOOL_CALL`。
- **通知內容與分類寫死在 bash 的 `case` 裡。** 改文案、改選單名稱或新增事件都要改程式，維護成本隨功能增加。

使用者已確認（Work Item `WI-20261118-notify-optimization` 的 D-001～D-005）：授權通知可以延遲，預設 30 秒後 Agent 仍在等才通知，
Codex、Claude Code、Antigravity 一致；Agent 提問維持立即通知；交件單通知另開 change `add-handoff-notifications`。

## What Changes

- **授權延遲確認**：收到「可能在等授權」的訊號時不立即通知；N 秒（`NOTIFY_AUTHORIZATION_DELAY_SECONDS`，預設 30）後仍在等才通知，
  同一段等待只通知一次。三個工具各有起始訊號、等待身分與「仍在等」的判斷依據。
  Codex 的執行期狀態查不到時無法確認是否在等，改發一則標明「可能在等待授權，無法確認」的通知（使用者確認的例外，D-004）。
- **通知分類改為四類**：工作結束、授權要求、等待回應、異常停止，各有一個開關。選單的「既有操作提醒」改為「授權要求」；
  Codex 專用的兩個開關併入共用的授權要求與等待回應。舊設定鍵在新鍵不存在時仍被讀取。
  已接受的取捨（D-005）：原本「一般操作提醒開、Codex 等待你授權關」的設定，合併後授權要求為開，Codex 的延遲授權通知隨之開啟。**BREAKING**：每次 PermissionRequest 立即通知的行為移除。
- **Claude Code 的 Notification 依類型分流**：`permission_prompt` 屬授權要求（延遲確認）；提問與等待輸入屬等待回應（立即）；
  登入成功、額度恢復等資訊類型不再當成「Action Required」送出。
- **Antigravity 完成判斷**：`NO_TOOL_CALL`（與舊的 `model_stop`）且背景工作結束才是完成；`USER_CANCELED` 不通知；其餘顯示為停止並附固定的原因標籤。
- **通知內容範本化**：每種通知一個範本檔，以 `{參數}` 取代；使用者可在 `~/.config/ai-notify/templates/` 放同名檔覆寫，安裝與更新不覆寫使用者範本。
  事件對分類、開關、範本的對照改成資料表。預設範本維持現有文字。
- **修正**：在選單改通知層級時，不再把其他類別的開關強制寫回開啟。
- **清理**：Codex 等待檢查器留下的過期狀態檔自動清除（目前 78 個 Session 累積 234 個檔案）。

支援的 AI CLI：Claude Code、Codex、Antigravity CLI；Copilot CLI 的既有對應不變。

驗收條件：

- 自動審核在延遲時間內放行的 Codex 請求不產生通知；停著等使用者超過延遲時間的請求產生一則通知。
  Codex 執行期狀態查不到時，延遲後仍無結果的請求產生一則「無法確認」的通知，文字不宣稱正在等待。
- 連續兩次授權等待各自計時：前一次的計時不會替後一次提早通知，已通知的等待解除後，下一次等待仍會通知。
- 工具不提供請求識別時，重複的等待訊號不會延後通知，也不會重複通知；沒有解除訊號的緊接等待併入前一段，這個限制寫入文件。
- Claude Code 的授權詢問與 Antigravity 的工具確認套用同一個延遲規則；Claude 與 Codex 的提問立即通知。
- Antigravity 以 `NO_TOOL_CALL` 結束且背景工作完成時，通知為 Task Complete。
- 沒有使用者範本時，工作結束、等待回應與異常停止的通知文字與現行相同；放入使用者範本後，通知使用該範本。
- 既有設定檔不需手動修改即可繼續運作；改通知層級不改變其他開關。

## Capabilities

### New Capabilities

- `notify-authorization-wait`: 授權等待的延遲確認——各工具的起始訊號、仍在等待的判斷依據、去重與重新武裝、無法取得依據時的行為。
- `notify-message-templates`: 通知內容範本、參數取代與跳脫規則、使用者覆寫，以及事件對分類、開關、範本的對照表。

### Modified Capabilities

- `telegram-notify-hook`: 分類改為四類與新的設定鍵及舊鍵相容；Claude Notification 依類型分流；Antigravity 完成判斷與確認觀察改用延遲確認；改層級不重設其他開關。
- `codex-human-wait-notifications`: 檢查器的啟動條件改用共用分類；授權等待需持續超過延遲時間；daemon 無法連線時改用 Session 紀錄判斷；過期狀態檔清理。
- `notify-test-harness`: 新增範本、四類開關與舊鍵相容、延遲確認、Antigravity 終止原因與狀態檔清理的回歸測試。

## Impact

- 程式：`scripts/notify/telegram/hook.sh`、`scripts/notify/lib/{config,settings,registry,runtime}.sh`、`scripts/notify/telegram/{install,update}.sh`、
  `scripts/notify/codex/wait.py`、`scripts/notify/telegram/test.sh`；新增預設範本與事件對照表。
- 部署：`~/.config/ai-notify/hooks/` 的腳本、新增內建範本目錄；使用者範本目錄 `~/.config/ai-notify/templates/`（選用）。
  已安裝的環境要執行 `scripts/notify/telegram/update.sh` 重新部署；hook 的登記指令不變，Codex 不需重新信任。
- 設定：`~/.config/ai-notify/config` 新增 `NOTIFY_AUTHORIZATION`、`NOTIFY_USER_INPUT`、`NOTIFY_AUTHORIZATION_DELAY_SECONDS`、`NOTIFY_AUTHORIZATION_REARM_SECONDS`（工具不提供請求識別時，已通知的等待從通知起算多久後可再次通知，預設 600；只適用已通知的等待）；
  `NOTIFY_ACTION_REQUIRED`、`NOTIFY_CODEX_HUMAN_APPROVAL`、`NOTIFY_CODEX_USER_INPUT` 改為相容讀取。
- 交接迴圈：`handoff-route` 目前以環境變數 `NOTIFY_ACTION_REQUIRED=true` 經一般通知送出，本 change 保留這個相容行為；專屬事件在 `add-handoff-notifications` 處理。
- 文件：`docs/notify/telegram.md`、`docs/notify/architecture.md`、`scripts/notify/README.md`。
- 依賴：不新增語言或套件；延遲確認在 Claude Code 與 Antigravity 用 bash 與既有的 `jq`，Codex 沿用既有的 Python 檢查器。

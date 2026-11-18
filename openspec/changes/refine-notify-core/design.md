# Design

## Context

動機與驗收條件見 proposal.md。這裡只列影響做法的現況：

- `scripts/notify/telegram/hook.sh`（351 行）在同一個檔案裡做五件事：讀輸入、判斷事件、套用開關、以 `case` 組訊息字串、送出。
  `codex-permission` 事件同時啟動等待檢查器並立即送「Approval requested」。
- `scripts/notify/codex/wait.py` 已能向 Codex daemon 查 `waitingOnApproval`／`waitingOnUserInput`，每秒輪詢、看到旗標就發。
  實績：78 個 Session 中 30 個連不上 daemon（`daemon-unavailable`）。
- Codex 的 Session 紀錄在「提出請求」與「取得結果」之間沒有「已核准」的標記，所以只看紀錄無法區分「等人核准」與「已核准但指令執行很久」。
- Antigravity 1.5.10 的 hook 只有 `SessionStart`、`PreToolUse`、`PostToolUse`、`PreInvocation`、`PostInvocation`、`Stop`；授權等待只能從狀態列的
  `tool_confirmation_pending` 得知。Stop 的 `terminationReason` 以 `NO_TOOL_CALL` 表示正常完成。
- hook 由各工具以短逾時（5–10 秒）呼叫，必須立刻返回；交接迴圈的 `handoff-route` 已驗證「背景子程序在 hook 結束後繼續執行」可行。
- 訊息以 Telegram 的 `parse_mode=Markdown` 送出，內容沒有跳脫。
- 既有 spec `codex-human-wait-notifications` 寫明「elapsed quiet time MUST NOT produce human-wait messages」與「daemon 不可用時不得發明等待通知」；
  本設計在 daemon 不可用時改用 Session 紀錄判斷，與這兩句衝突，已在 delta spec 明確修改（見決策 4）。

## Goals / Non-Goals

**Goals:**

- 授權通知只在 Agent 仍停著等使用者時發出，三個工具同一套規則。
- 訊息文字與事件分類成為資料，改文案或加事件不必改 hook 邏輯。
- 既有安裝不需手動改設定；預設範本下，非授權類訊息的文字不變。

**Non-Goals:**

- 不改寫安裝與 hook 登記流程（`registry.sh`、`install.sh` 的結構不動），不新增語言或常駐服務。
- 不處理交件單通知的事件、開關與模型資訊（`add-handoff-notifications`）。
- 不嘗試分辨 Codex「已核准但指令執行超過延遲時間」與「等待核准」在 daemon 不可用時的差別（見風險）。
- 不新增 Claude Code 或 Antigravity 的 hook 登記事件；不改 Copilot CLI 的對應。

## Decisions

### 1. hook 拆成「解析 → 查表 → 套範本 → 送出」

```
stdin JSON + 參數
      |
      v
  解析事件（工具、事件名、notification_type、terminationReason…）
      |
      v
  事件對照表  ──>  分類、開關、範本名
      |
      +── authorization ──> 延遲確認（決策 3）──> 仍在等才往下
      |
      v
  套用開關（決策 2）
      |
      v
  讀範本（使用者覆寫 > 內建）→ 取代參數 → 跳脫 → 送出
```

- 事件對照表是一個隨 hook 部署的純文字表（每列：事件鍵、分類、範本名），放在 `scripts/notify/telegram/events.tsv`，部署到 `~/.config/ai-notify/hooks/`。
  開關由分類決定，不在表內重複。
- 需要程式判斷才知道鍵的事件（Claude 的 `notification_type`、Antigravity 的終止原因）先在解析步驟轉成事件鍵
  （例如 `claude-notification:permission_prompt`、`antigravity-stop:complete`），之後一律查表。
- 替代方案：整個 hook 改寫成 Python。不採用——目前的需求用資料表加範本就能把 bash 縮到只剩流程，換語言的收益不足以抵銷重寫與重新驗證五個工具的成本；
  有狀態的 Codex 檢查已經在 Python。

### 2. 四個分類與設定鍵

| 分類 | 選單名稱 | 設定鍵 | 新鍵不存在時 |
| --- | --- | --- | --- |
| completion | 工作結束 | `NOTIFY_COMPLETION` | 依 `NOTIFY_LEVEL` |
| authorization | 授權要求 | `NOTIFY_AUTHORIZATION` | `NOTIFY_ACTION_REQUIRED` 或 `NOTIFY_CODEX_HUMAN_APPROVAL` 任一為 true；都沒有則開 |
| user_input | 等待回應 | `NOTIFY_USER_INPUT` | `NOTIFY_ACTION_REQUIRED` 或 `NOTIFY_CODEX_USER_INPUT` 任一為 true；都沒有則開 |
| failure | 異常停止 | `NOTIFY_FAILURE` | 開 |

- 取值順序：環境變數的新鍵 → 環境變數的舊鍵 → 設定檔的新鍵 → 設定檔的舊鍵 → 層級預設。
  保留「環境變數的舊鍵」是為了讓 `handoff-route` 目前的 `NOTIFY_ACTION_REQUIRED=true` 覆寫在本 change 合併後仍然有效。
- 選單儲存時寫入四個新鍵並移除三個舊鍵；只讀不存時不動設定檔。
- 改層級只寫 `NOTIFY_LEVEL` 與 `NOTIFY_COMPLETION`（層級只定義這一類的差別），不再寫其他開關。
- 替代方案：保留五個鍵，只改選單文字。不採用——授權改成三工具共用的延遲確認後，「Codex 等待你授權」與「授權要求」是同一件事，留兩個開關只會讓使用者再次分不清。

### 3. 延遲確認的共同機制

- 起始訊號到達時：寫入該 Session 的等待標記（工具、Session、時間、請求的工具標籤），啟動一個脫離 hook 的背景檢查後立即返回。
  標記已存在時不重複啟動。
- 背景檢查等待 `NOTIFY_AUTHORIZATION_DELAY_SECONDS` 秒，再看「仍在等」的依據：仍在等就以 `authorization` 事件送一次並把標記記為已通知；
  已解除就刪除標記。標記在等待解除時刪除，所以下一段等待可以再通知。
- 延遲為 0 時不啟動背景檢查，直接送出。
- 讀不到任何依據時送出（寧可偶爾多一則，不漏掉真的等待）。
- 標記放在既有的 `~/.config/ai-notify/state/`，檔名帶工具前綴，與 Codex 檢查器的檔案同受決策 6 的清理規則。

### 4. 各工具的起始訊號與判斷依據

| 工具 | 起始訊號 | 仍在等的依據 | 實作位置 |
| --- | --- | --- | --- |
| Claude Code | `Notification` 且 `notification_type=permission_prompt` | hook 輸入的 `transcript_path`：尾端有工具呼叫沒有對應結果 | bash + `jq`（只讀檔案尾端） |
| Codex | `PermissionRequest` hook | daemon 可連：`waitingOnApproval` 旗標持續到延遲結束；不可連：Session 紀錄尾端的請求沒有結果 | 既有的 `wait.py` |
| Antigravity | 狀態列 `tool_confirmation_pending: true` | 等待標記仍在（狀態列回報 false 時清除） | bash |

- Codex 沿用 `wait.py` 的單一檢查器與鎖：旗標首次出現時記下時間，持續超過延遲才發；旗標消失就重置。daemon 連續失敗時不再直接結束，
  而是在有等待標記的情況下改讀 Session 紀錄（以 Session ID 在 `~/.codex/sessions/` 找到紀錄檔，只讀尾端的中繼資料，不讀指令內容）。
- 這修改了既有 spec 的兩句（見 Context）。理由：38% 的 Session 連不上 daemon，維持原規則等於這些 Session 永遠收不到真正的等待通知；
  「靜默時間」本身仍不會觸發通知，必須有一個未解除的授權請求。
- Claude Code 的 `permission_prompt` 只在真的要詢問使用者時出現（`auto` 模式由分類器決定，不詢問），加上延遲後行為與其他工具一致。
- 替代方案：依 `approvals_reviewer` 設定直接略過 Codex 的通知。不採用——設定可被 profile 或啟動參數覆寫，而且自動審核拒絕後仍可能需要使用者。

### 5. 範本

- 內建範本放 `scripts/notify/telegram/templates/<name>.md`，部署到 `~/.config/ai-notify/hooks/templates/`，每次更新都覆寫。
- 使用者範本放 `~/.config/ai-notify/templates/<name>.md`，同名優先；空檔或讀不到時用內建。安裝、更新、修復、移除都不碰這個目錄。
  分成兩個目錄，就不需要判斷「使用者有沒有改過」。
- 參數以 `{name}` 表示：`{title_suffix}`、`{tool}`、`{project}`、`{time}`、`{tag}`、`{message}`、`{reason}`、`{request_tool}`。
  取代前先跳脫值裡在 Telegram Markdown 有意義的字元；範本本身的標記不跳脫。只含參數且結果為空的行會被移除；未知參數原樣保留，方便發現打錯。
- 取代用字串操作完成，不經 `eval`，範本內容不會被當成指令執行。
- 預設範本逐字對應現有訊息；授權類新增一個範本（標題沿用「Action Required」，內文改為「<工具> 等待你授權超過 N 秒」）。
- 替代方案：把訊息放進設定檔的鍵值。不採用——多行訊息在 `key=value` 檔裡難以編輯。

### 6. 狀態檔清理

- `wait.py` 啟動檢查時順便清理：`state/` 內符合通知自有命名規則、超過 7 天、且鎖沒有被持有的檔案（Codex 的 `.lock`／`.json`／`.request.json` 成組處理，
  以及延遲確認的等待標記）。沿用既有的非阻塞 `flock` 檢查。
- 不在檢查結束時立即刪除，因為 `status` 會讀最近的狀態檔顯示支援情況。
- 替代方案：安裝或更新時才清。不採用——使用者不常跑更新，檔案仍會累積。

### 7. TDD 策略與測試邊界

- 先把現有訊息錄成基準（golden）：對每種事件以 `TELEGRAM_DRY_RUN=true` 取得目前輸出，寫成測試；之後的範本化必須讓這些測試維持通過。
  這一步是行為不變的重構，Red 來自「範本檔不存在時測試失敗」。
- 行為變更各自先寫失敗測試：四類開關與舊鍵相容、Claude 類型分流、Antigravity 終止原因、延遲確認（把延遲設成 1 秒）、狀態檔清理。
- 測試邊界：全部在暫時的 HOME 與假資料下執行，不送真實 Telegram、不連真實 daemon（沿用既有的假 daemon 中繼資料）。
  Claude 與 Codex 的 Session 紀錄以最小的假紀錄檔代表「有結果」與「沒有結果」。
- 無法自動化的部分另列可重播的驗收步驟並記錄實際結果：三個工具各一次真實的授權等待（等超過延遲、在延遲內回應各一次）、
  Antigravity 一次真實的正常完成。

## Risks / Trade-offs

- [Codex daemon 不可連時，已核准但執行超過延遲時間的指令會被當成等待] → 三天資料中 226 次只有 1 次超過 30 秒；延遲可調；文件寫明這個限制。
- [Claude Code 的 `permission_prompt` 實際觸發時機與輸入欄位未以真實資料確認] → tasks 第 1 組先擷取真實輸入；若沒有 `transcript_path` 或類型欄位，改以不延遲送出並回報，不猜測。
- [Antigravity 等待期間狀態列是否持續回報、解除時是否一定回報 false] → 第 1 組先觀察；若解除後不回報，改在 `Stop` 與下一次狀態列呼叫時清除標記。
- [hook 結束後背景檢查被工具終止] → 沿用 `handoff-route` 已驗證的脫離方式；測試以「hook 立即返回而訊息稍後出現」驗證。
- [範本被使用者改壞導致 Telegram 拒收] → 值會跳脫；送出失敗時不重試、不阻擋工具（既有行為）；`status` 顯示正在使用的使用者範本。
- [移除立即通知是行為改變] → 延遲設為 0 可回到立即通知；文件與選單說明寫明。
- [舊鍵相容的取值順序複雜] → 以表格化的測試涵蓋每一種組合。

## Migration Plan

1. 合併後執行 `scripts/notify/telegram/update.sh` 重新部署 hook、對照表與內建範本；hook 的登記指令不變，Codex 不需重新信任。
2. 既有設定檔不需修改：新鍵不存在時讀舊鍵。使用者下次在選單儲存分類時才改寫成新鍵。
3. 回復：重新部署前一版的 hook 即可；新鍵對舊版 hook 無作用，舊鍵若已被選單移除，需在選單重新設定一次。

## Open Questions

- `TERMINAL_STEP_TYPE` 是否也應視為正常完成：先歸為停止並顯示標籤，取得真實資料後再調整對照表（只改資料，不影響做法）。
- auto_review 審核期間 daemon 是否短暫標成 `waitingOnApproval`：不影響設計，延遲確認對兩種情況都成立；第 1 組順便記錄。

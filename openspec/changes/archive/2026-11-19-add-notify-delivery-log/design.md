# Design

## Context

見 proposal.md「Why」。`hook.sh` 的 `deliver()` 以 `printf ... | curl --config - --output /dev/null ... || true` 送出；
`EVENT_KEY` 是查表用的事件鍵（例如 `stop`、`notification:idle_prompt`、`handoff:review`），`deliver` 的參數是範本名稱。
`authorization.sh`（hook 已載入）定義 `NOTIFY_STATE_DIR=~/.config/ai-notify/state`，建立時 `chmod 700`。hook 的 stdout 保留給
各工具的控制回應，不能輸出其他內容。

## Goals / Non-Goals

**Goals:**

- 可選的、可證明「Telegram 已接受」的送達紀錄，供排查與驗收。

**Non-Goals:**

- 不記錄被擋下或 dry-run 的事件（那是設定問題，dry-run 本身已印出訊息）。
- 不在 `update.sh` 選單加開關；直接編輯設定檔（另案再加）。
- 不重送失敗的通知。

## Decisions

### 1. 一律取回 Telegram 回覆，只在開啟時寫紀錄

- curl 改為不加 `--output /dev/null`，以 `$(...)` 取回回覆（不會進入 hook 的 stdout），保留 exit code；開啟紀錄時解析
  `"ok":true|false` 與 `"message_id":<數字>`。curl 失敗或回覆無法辨識時記 `ok=false`、`message_id=-`。
- 單一路徑：不論是否開啟都同樣取回回覆，避免兩套 curl 呼叫。
- 解析用 `grep -o`，不依賴 jq（hook 在沒有 jq 的環境也要能送通知）。
- 替代方案：關閉時維持 `--output /dev/null`。不採用——兩套呼叫容易分歧；回覆很小，取回不影響 4 秒逾時。

### 2. 紀錄格式與大小

- 一行：`<ISO 時間> event=<EVENT_KEY> template=<範本> ok=<true|false> message_id=<數字或->`，格式與 `routing.log` 一致。
- `EVENT_KEY` 只含英數字、`:`、`_`、`-`（各來源已清理）；寫入前再以 `tr -cd` 限制字元。
- 超過 500 行時以 `tail -n 500` 改寫。ponytail：每次寫入都檢查行數（`wc -l`），量小可接受；需要時改成定期輪替。
- 目錄沿用 `NOTIFY_STATE_DIR`（700）；檔案以 `umask 077` 建立。

### 3. TDD 策略與測試邊界

- `scripts/notify/telegram/test.sh` 新增 `DELIVERY-LOG` 區段，以假 curl 回覆 `{"ok":true,"result":{"message_id":42}}`、
  `{"ok":false}` 或以非零結束：
  - 開啟：一行、含事件鍵、範本、`ok=true`、`message_id=42`；不含 token、chat ID、訊息內文（`Task Complete`）。
  - 拒絕與 curl 失敗：`ok=false message_id=-`。
  - 關閉：不建立檔案；dry-run：不建立檔案。
  - 預先放 500 行：送出後仍 500 行，最後一行是新紀錄。
- 既有測試（含 SEC-ARGV 的 argv 檢查與送達測試）維持通過。
- 邊界：不連 Telegram；合併後以一則真實通知確認紀錄出現（Migration Plan）。

## Risks / Trade-offs

- [紀錄檔外洩] → 不含內文與憑證；目錄 700、檔案 600。
- [Telegram 回覆格式改變] → 解析不到即記 `ok=false`，不影響送出。

## Migration Plan

1. 合併後執行 `bash scripts/notify/telegram/update.sh fix-hooks`。
2. 需要時在 `~/.config/ai-notify/config` 加 `NOTIFY_DELIVERY_LOG=true`，完成一輪 AI CLI 後確認 `deliveries.log` 有新行。
3. 回退：移除設定即停止寫入；刪除紀錄檔不影響任何功能。

# Design

## Context

見 proposal.md「Why」。目前的呼叫：

- `hook.sh` `deliver()`：`curl --silent --max-time 4 --output /dev/null -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" -d "chat_id=${CHAT}" -d "parse_mode=Markdown" --data-urlencode "text=..."`。
- `install.sh`：`curl ... "${TELEGRAM_API}${token}/getMe"`、`.../getUpdates`，以及以 `${NEW_TOKEN}` 送出的測試訊息。

hook 由各 AI CLI 以背景程序啟動，`curl` 的 argv 對同機使用者可見（`ps`）。

## Goals / Non-Goals

**Goals:**

- token 與 chat ID 不進入任何程序的 argv。

**Non-Goals:**

- 不隱藏訊息內文（不是憑證；內容已受既有隱私規則限制）。
- 不改設定檔的儲存方式與權限（另案）。
- 不改 Telegram 請求內容、逾時或錯誤處理。

## Decisions

### 1. 以 `curl --config -` 從 stdin 傳 URL 與 chat ID

- 每次呼叫以 `printf` 產生兩行 curl 設定：`url = "https://api.telegram.org/bot<token>/<method>"`，送訊息時再加
  `data = "chat_id=<id>"`，接到 `curl --config -`；其餘參數（`--silent`、`--max-time`、`-X POST`、`parse_mode`、
  `--data-urlencode text=...`）照舊放在指令列。`printf` 是 bash 內建，不會產生帶 token 的子程序。
- 替代方案：環境變數。不採用——curl 不從環境變數讀 URL；且 `/proc/<pid>/environ` 對同使用者可讀。
- 替代方案：寫入暫存設定檔再 `--config <file>`。不採用——要處理檔案權限與清理，stdin 已足夠。
- 替代方案：整段訊息也走 stdin。不採用——設定檔字串需跳脫換行與引號，增加出錯面，而內文不是憑證。

### 2. 先驗證字元再組設定

- token 必須符合 `^[A-Za-z0-9:_-]+$`，chat ID 必須符合 `^[A-Za-z0-9_@-]+$`；不符就不呼叫 curl。這兩組字元都不需要在
  curl 設定字串中跳脫，也排除以引號或換行注入其他 curl 選項。
- hook：不符時視同無法送出，走既有的安靜結束路徑（仍輸出各工具的中性控制回應）。
- 安裝精靈：token 不符時沿用「token 無效」的既有提示，要求重新輸入。

### 3. TDD 策略與測試邊界

- 在 `scripts/notify/telegram/test.sh` 新增一段，以假 curl 記錄 argv 與 stdin（不連網）：
  - hook 送出一則完成通知：argv 不含 token、chat ID；stdin 含 `url = "https://api.telegram.org/bot<token>/sendMessage"` 與
    `data = "chat_id=<id>"`；argv 仍含 `parse_mode=Markdown` 與訊息。
  - 安裝精靈完整跑一次（沿用 LIFE-CONFIG-01 的假 curl 回應形式）：所有 curl 呼叫的 argv 都不含 token。
  - 設定 token 含 `"` 時，curl 未被呼叫且 hook 結束碼為 0。
- 既有 dry-run 與 HO-SW-07 等送達測試維持通過（假 curl 不讀 stdin 也不受影響）。
- 邊界：不呼叫真實 Telegram；真實送達於合併後以一則手動通知確認（Migration Plan）。

## Risks / Trade-offs

- [舊 curl 不支援 `--config -`] → macOS 與主流 Linux 發行版的 curl 皆支援；不支援時 curl 失敗，hook 既有的 `|| true` 讓 CLI 不受影響。
- [合法 token 格式改變] → Telegram token 長期為 `<數字>:<英數字_->`；若日後格式擴充，只需放寬驗證字元。

## Migration Plan

1. 合併後執行 `bash scripts/notify/telegram/update.sh fix-hooks`，部署新的 `telegram-notify.sh`。
2. 在任一 AI CLI 完成一輪，確認仍收到 Telegram 通知。
3. 回退：重新部署前一版；設定檔不變。
4. 既有 token 曾出現在程序列表與工具輸出，由使用者評估是否輪換。

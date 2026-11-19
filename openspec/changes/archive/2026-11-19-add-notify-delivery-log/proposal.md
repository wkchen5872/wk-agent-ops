# Proposal

## Why

通知腳本送出 Telegram 訊息後丟棄回覆，沒有任何送達紀錄。Pi 交接實測的真實驗收需要「收件證據」時，只能另外在 PATH 前置
`curl` 轉接層記錄 Telegram 回覆；平時排查「為什麼沒收到通知」也無從判斷是沒送、送失敗還是 Telegram 拒絕。

## What Changes

- 新增選用設定 `NOTIFY_DELIVERY_LOG`（`~/.config/ai-notify/config`），預設關閉；設為 `true` 時，每次實際呼叫 Telegram 送出
  通知後，在 `~/.config/ai-notify/state/deliveries.log` 追加一行：時間、事件鍵、範本、Telegram 是否接受（`ok`）、`message_id`。
- 紀錄不含訊息內文、token、chat ID、提示或指令內容。
- dry-run、被開關或等級擋下、未送出的事件不寫紀錄；寫紀錄失敗不影響通知與各 AI CLI。
- 紀錄檔保持在最近 500 行以內。
- 支援的 AI CLI：Claude Code、Codex、Antigravity、Copilot CLI、Pi 與交接事件——全部經由同一個 `hook.sh` 送出，行為一致。

驗收條件：

- 開啟後送出一則完成通知，紀錄多一行，含事件鍵、範本、`ok=true` 與 Telegram 回覆的 `message_id`，不含訊息內文與 token。
- Telegram 回 `ok:false` 或 curl 失敗時，紀錄 `ok=false`、`message_id=-`。
- 未開啟時不建立紀錄檔；dry-run 不寫紀錄。
- 紀錄超過 500 行時只保留最近 500 行。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `telegram-notify-hook`: 新增選用的送達紀錄。

## Impact

- 程式：`scripts/notify/telegram/hook.sh`（`deliver()`）。
- 測試：`scripts/notify/telegram/test.sh`。
- 文件：`docs/notify/telegram.md`（設定與排查）。
- 使用者環境：合併後執行 `bash scripts/notify/telegram/update.sh fix-hooks` 部署；需要時在設定檔加入 `NOTIFY_DELIVERY_LOG=true`。

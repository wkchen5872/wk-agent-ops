# Proposal

## Why

通知腳本與安裝精靈呼叫 Telegram Bot API 時，把含 bot token 的 URL 與 chat ID 放在 `curl` 的指令列參數。同一台機器上任何
使用者都能用 `ps` 讀到它們；Pi 交接實測時，觀察程序列表就讓 token 出現在工具輸出中。

## What Changes

- `scripts/notify/telegram/hook.sh` 送出通知時，含 token 的 URL 與 `chat_id` 改由 stdin 以 curl 設定檔格式交給
  `curl --config -`，不出現在任何程序的指令列；訊息內文與其他參數不變。
- `scripts/notify/telegram/install.sh` 的 `getMe`、`getUpdates` 與測試訊息三處呼叫採相同方式。
- token 只接受 Telegram token 的字元（英數字、`:`、`_`、`-`），chat ID 只接受 Telegram chat ID 的字元（英數字、`-`、`_`、`@`）；
  不符時不呼叫 curl（hook 安靜略過，照常回傳各工具的中性回應；安裝精靈回報 token 無效），避免設定值注入 curl 設定。
- 支援的 AI CLI：Claude Code、Codex、Antigravity、Copilot CLI、Pi——全部經由同一個 `hook.sh` 送出，行為不變。

驗收條件：

- 送出通知與安裝精靈的每一次 Telegram 呼叫，`curl` 收到的參數都不含 token 與 chat ID，而 stdin 的設定含正確的 URL 與 chat ID。
- 實際送出的 Telegram 請求（URL、chat ID、訊息、`parse_mode`）與修改前相同。
- 設定檔中的 token 含引號、空白或換行時，不呼叫 curl，hook 仍正常結束。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `telegram-notify-hook`: 新增「Telegram 憑證不出現在程序指令列」的需求，涵蓋通知送出與安裝精靈。

## Impact

- 程式：`scripts/notify/telegram/hook.sh`（`deliver()`）、`scripts/notify/telegram/install.sh`。
- 測試：`scripts/notify/telegram/test.sh`。
- 文件：`docs/notify/telegram.md` 的安全說明。
- 使用者環境：合併後重跑 `bash scripts/notify/telegram/update.sh fix-hooks` 部署新的通知腳本；既有 token 曾出現在程序列表與
  工具輸出時，由使用者評估是否在 BotFather 輪換。
- 依賴：curl 的 `--config -`（自 curl 7.x 起支援；macOS 內建 curl 可用）。

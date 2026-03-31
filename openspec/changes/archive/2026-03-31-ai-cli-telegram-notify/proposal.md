## Why

當 AI CLI 工具（Claude Code、Gemini CLI 等）在背景執行長時間任務時，使用者無法即時得知任務完成或等待授權的狀態，必須持續盯著畫面。透過 Telegram 通知可讓使用者離開螢幕仍能即時回應。

## What Changes

- 新增全域 Telegram 通知腳本 `~/.claude/hooks/telegram-notify.sh`，供所有 AI CLI hook 共用
- 更新 `~/.claude/settings.json` 加入 `Stop` 與 `Notification` 全域 hook，對所有 Claude Code 專案自動生效
- 更新 `~/.gemini/settings.json` 加入 `AfterAgent` 與 `Notification` hook
- 新增 `docs/telegram-notify-hook.md` 說明安裝方式與架構
- 透過 `TELEGRAM_NOTIFY_LEVEL` 環境變數支援通知等級切換（`all` / `notify_only`）

## Capabilities

### New Capabilities

- `telegram-notify-hook`: 全域 AI CLI Telegram 通知腳本與 hook 配置，包含通知腳本、Claude Code hook 設定、Gemini CLI hook 設定、環境變數說明文件

### Modified Capabilities

（無現有 spec 受影響）

## Impact

- **新增檔案**：`~/.claude/hooks/telegram-notify.sh`、`docs/telegram-notify-hook.md`
- **修改設定**：`~/.claude/settings.json`（全域，影響所有專案）、`~/.gemini/settings.json`
- **外部相依**：Telegram Bot API（需 TELEGRAM_BOT_TOKEN、TELEGRAM_CHAT_ID）、`curl`、`jq`
- **不影響**：任何專案程式碼、現有 hook、現有 plugin 配置

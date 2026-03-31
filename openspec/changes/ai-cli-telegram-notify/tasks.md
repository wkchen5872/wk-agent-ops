## 1. Telegram Bot 準備

- [ ] 1.1 透過 @BotFather 建立 Telegram Bot，取得 Bot Token
- [ ] 1.2 向新 Bot 傳送訊息後，透過 getUpdates API 取得 Chat ID
- [ ] 1.3 將 TELEGRAM_BOT_TOKEN、TELEGRAM_CHAT_ID、TELEGRAM_NOTIFY_LEVEL 加入 `~/.zshrc`
- [ ] 1.4 執行 `source ~/.zshrc` 使環境變數生效

## 2. 通知腳本

- [ ] 2.1 建立目錄 `~/.claude/hooks/`
- [ ] 2.2 建立 `~/.claude/hooks/telegram-notify.sh`（支援 Stop/Notification 事件、工具偵測、TELEGRAM_NOTIFY_LEVEL 控制）
- [ ] 2.3 `chmod +x ~/.claude/hooks/telegram-notify.sh`
- [ ] 2.4 手動測試 Stop event：`echo '{"hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.claude/hooks/telegram-notify.sh stop`
- [ ] 2.5 手動測試 Notification event：`echo '{"hook_event_name":"Notification","message":"Permission: run npm install"}' | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.claude/hooks/telegram-notify.sh notification`
- [ ] 2.6 手動測試 notify_only 模式（Stop 應靜默）

## 3. Claude Code 全域 Hook 設定

- [ ] 3.1 編輯 `~/.claude/settings.json`，加入 `hooks` 區塊（Stop + Notification，async: true，timeout: 15）
- [ ] 3.2 在任意專案中傳送簡短 Claude 訊息，確認收到 Telegram 通知

## 4. Gemini CLI 全域 Hook 設定

- [ ] 4.1 編輯 `~/.gemini/settings.json`，加入 `hooks` 區塊（AfterAgent + Notification，timeout: 15）
- [ ] 4.2 在任意專案中傳送簡短 Gemini 訊息，確認收到 Telegram 通知

## 5. 說明文件

- [ ] 5.1 建立 `docs/telegram-notify-hook.md`，包含：Telegram Bot 建立步驟、環境變數設定、腳本安裝、settings.json 修改方式、手動測試指令、TELEGRAM_NOTIFY_LEVEL 切換說明、Rollback 方式

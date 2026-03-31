## 1. 共用基礎庫（scripts/notify/lib/）

- [x] 1.1 建立 `scripts/notify/lib/config.sh`：讀寫 `~/.config/ai-notify/config` 的函式（read_config、write_config、update_config_key）；此庫只定義函式，不執行任何寫入
- [x] 1.2 建立 `scripts/notify/lib/registry.sh`：idempotent 的 `register_hook()` 與 `unregister_hook()`，使用 `jq` 安全操作 `~/.claude/settings.json` / `~/.gemini/settings.json`；此庫只定義函式，不執行任何寫入
- [x] 1.3 建立 `scripts/notify/README.md`：Provider 擴充指南（目錄複製步驟、hook.sh 介面規範、config key 命名規範）

## 2. Telegram Hook 腳本（scripts/telegram-notify/hook.sh）

- [x] 2.1 建立 `scripts/telegram-notify/hook.sh`：source `~/.config/ai-notify/config`，依 TELEGRAM_ENABLED、NOTIFY_LEVEL 判斷是否傳送
- [x] 2.2 支援 Stop / Notification 兩種事件類型（`$1` 參數 + stdin JSON `hook_event_name`）
- [x] 2.3 支援 Claude Code（`CLAUDE_PROJECT_DIR` env）與 Gemini CLI（`GEMINI_PROJECT_DIR` env / stdin `cwd`）工具偵測
- [x] 2.4 jq 不存在時的 fallback 邏輯
- [x] 2.5 curl 靜默失敗（`|| true`，`--max-time 10`）

## 3. 安裝精靈（scripts/telegram-notify/install.sh）

- [x] 3.1 建立 `scripts/telegram-notify/install.sh`，流程如下（全部在此腳本內完成，不在開發期間執行）：
  - Step 1：引導使用者建立 Bot（@BotFather 步驟說明輸出）
  - Step 2：讀取 Bot Token，呼叫 Telegram API 驗證 token 有效
  - Step 3：自動偵測 Chat ID（傳送測試訊息後呼叫 getUpdates）
  - Step 4：讓使用者選擇 NOTIFY_LEVEL（all / notify_only）
  - Step 5：呼叫 `lib/config.sh write_config()` 建立 `~/.config/ai-notify/config`（chmod 600）
  - Step 6：mkdir -p `~/.config/ai-notify/hooks/`，複製 `hook.sh` 到 `~/.config/ai-notify/hooks/telegram-notify.sh`，chmod +x
  - Step 7：呼叫 `lib/registry.sh register_hook()` 更新 `~/.claude/settings.json` 與 `~/.gemini/settings.json`
  - Step 8：傳送測試通知，確認收到後顯示完成訊息
- [x] 3.2 已安裝時跳過已完成的步驟（幂等）

## 4. 輔助腳本

- [x] 4.1 建立 `scripts/telegram-notify/update.sh`：更新單一設定項目（token / chat_id / notify_level），呼叫 `lib/config.sh update_config_key()`，不觸碰 settings.json
- [x] 4.2 建立 `scripts/telegram-notify/uninstall.sh`：呼叫 `lib/registry.sh unregister_hook()`，從 `~/.config/ai-notify/config` 移除 TELEGRAM_* 條目，移除 `~/.config/ai-notify/hooks/telegram-notify.sh`

## 5. Line Notify 佔位結構（scripts/line-notify/）

- [x] 5.1 建立 `scripts/line-notify/.placeholder`（含說明：實作時參考 `scripts/notify/README.md`）

## 6. Claude Code 指令與說明文件

- [x] 6.1 建立 `.claude/commands/notify-setup.md`：定義 `/notify-setup` 指令，支援無參數（互動選單）、setup（呼叫 install.sh）、update（呼叫 update.sh）、test（直接觸發 hook）、status（讀 config，mask token）、uninstall（呼叫 uninstall.sh）
- [x] 6.2 建立 `docs/notify-hooks-architecture.md`：整體架構（目錄結構、安裝流程、config 格式、hook 生命週期、如何擴充新 provider）
- [x] 6.3 建立 `docs/telegram-notify-hook.md`：快速安裝說明（`/notify-setup` 指令 + 手動 `bash install.sh`）、NOTIFY_LEVEL 說明、Rollback 步驟

## 7. 安裝測試（執行 install.sh 後驗收）

- [ ] 7.1 執行 `bash scripts/telegram-notify/install.sh`，按精靈步驟完成設定
- [ ] 7.2 確認 `~/.config/ai-notify/config` 存在且 chmod 600，內容正確
- [ ] 7.3 確認 `~/.config/ai-notify/hooks/telegram-notify.sh` 存在且可執行
- [ ] 7.4 確認 `~/.claude/settings.json` 包含 Stop + Notification hooks，無重複條目
- [ ] 7.5 重複執行 `install.sh`，確認 idempotent（settings.json 無重複，config 不重複寫入）

## 8. 功能驗收

- [ ] 8.1 手動觸發 Stop event：`echo '{"hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.config/ai-notify/hooks/telegram-notify.sh stop` → 收到 Telegram 通知
- [ ] 8.2 手動觸發 Notification event（含 message 欄位）→ 收到含授權訊息的通知
- [ ] 8.3 設定 NOTIFY_LEVEL=notify_only 後觸發 Stop → 靜默不發送
- [ ] 8.4 執行 `uninstall.sh` → settings.json hook 條目移除，config 條目清除
- [ ] 8.5 Live test：在 Claude Code 輸入 `/notify-setup`，確認能完成完整設定流程並收到通知

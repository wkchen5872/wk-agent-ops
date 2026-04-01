## 1. hook.sh — $2 Tool Name 參數 & Session 顯示

- [x] 1.1 讀取 `$2` 作為 TOOL_NAME；若為空則保留現有 env var 偵測邏輯（向後相容）
- [x] 1.2 從 stdin JSON 依序嘗試取 `.session_id`（Claude）、`.sessionId`（Copilot）；fallback 到 `GITHUB_COPILOT_SESSION_ID` 前 8 字元
- [x] 1.3 實作 session 格式化：UUID 格式（含 `-`）取前 8 字元加 `#` 前綴；否則直接使用；無值則空字串
- [x] 1.4 更新 Task Complete 標題：`🟢 **Task Complete** (SESSION)` 或 `🟢 **Task Complete**`（無 session）
- [x] 1.5 更新 Action Required 標題：同上格式
- [x] 1.6 驗證：`bash hook.sh sessionEnd "Copilot CLI"` → 標題含 "Copilot CLI"；不帶 $2 且 `CLAUDE_PROJECT_DIR` 存在 → fallback 到 "Claude Code"

## 2. registry.sh — 指令格式更新

- [x] 2.1 在 `register_hook()` 的 Claude Stop/Notification 指令末加入 `"Claude Code"` 參數
- [x] 2.2 在 `register_hook()` 的 Gemini AfterAgent/Notification 指令末加入 `"Gemini CLI"` 參數
- [x] 2.3 在 `register_hook_copilot()` 的 sessionEnd 指令末加入 `"Copilot CLI"` 參數
- [x] 2.4 更新 `unregister_hook_copilot()` 的比對邏輯，能清除含新 tool name 參數的指令（舊格式也一併清除）
- [x] 2.5 確認 idempotency：連續呼叫 `register_hook_copilot` 兩次，`hooks.json` 只有一條 sessionEnd 指令
- [x] 2.6 驗證：`register_hook` 後檢查 `~/.claude/settings.json`，Stop hook 指令末尾含 `"Claude Code"`

## 3. hook.sh dry-run 模式

- [x] 3.1 在 hook.sh 加入 `TELEGRAM_DRY_RUN` guard：若為 `true`，以 `echo "${MESSAGE}"` 取代 curl，exit 0
- [x] 3.2 確認 dry-run 模式下 NOTIFY_LEVEL gate 仍生效（notify_only + stop → 無輸出）
- [x] 3.3 驗證：`TELEGRAM_DRY_RUN=true bash hook.sh stop "Claude Code"` 輸出含 `Task Complete`

## 4. test.sh — 自動化測試腳本

- [x] 4.1 建立 `scripts/notify/telegram/test.sh`，定義 `run_test <name> <expected_pattern> <command>` 輔助函式
- [x] 4.2 實作 BUG-01：sessionEnd 輸出 Task Complete（非 AI CLI Event）
- [x] 4.3 實作 BUG-02：$2 覆蓋 env var，Copilot 正確識別（CLAUDE_PROJECT_DIR 干擾測試）
- [x] 4.4 實作 BUG-03：無 $2 且 event=sessionend → Copilot fallback
- [x] 4.5 實作 BUG-04：stop + Claude Code → Task Complete
- [x] 4.6 實作 BUG-05：notification + stdin message → Action Required + message
- [x] 4.7 實作 BUG-06：AfterAgent + Gemini CLI → Task Complete
- [x] 4.8 實作 SESSION-01：UUID session_id 截短為前 8 字元
- [x] 4.9 實作 SESSION-02：無 session 資訊，標題無括號
- [x] 4.10 實作 LEVEL-01：notify_only 抑制 stop
- [x] 4.11 實作 LEVEL-02：notify_only 允許 notification
- [x] 4.12 確認 `bash scripts/notify/telegram/test.sh` 全 PASS，exit 0

## 5. 重新部署 & 更新已存在的 hooks

- [x] 5.1 重新部署 `hook.sh` 到 `~/.config/ai-notify/hooks/telegram-notify.sh`
- [x] 5.2 執行 `register_hook_copilot` 更新 `.github/hooks/hooks.json`（帶 "Copilot CLI" 參數）
- [x] 5.3 執行 `fix-hooks`（`update.sh fix-hooks`）更新 `~/.claude/settings.json` 和 `~/.gemini/settings.json`
- [x] 5.4 驗證：用 Copilot CLI 觸發 sessionEnd，Telegram 收到 `🟢 **Task Complete** (#<session>)` 且工具顯示 "Copilot CLI"

## Context

Claude Code 與 Gemini CLI 均提供 hook 系統，允許在特定事件（任務完成、授權等待）時執行外部腳本。目前使用者的全域設定（`~/.claude/settings.json`、`~/.gemini/settings.json`）均無 hook 配置。

需求：一個輕量、無侵入性的通知機制，透過 Telegram Bot API 傳送訊息，並對所有專案自動生效。

## Goals / Non-Goals

**Goals:**
- 單一腳本支援 Claude Code 與 Gemini CLI 兩種工具
- 全域設定生效，不需修改任何專案程式碼
- 透過 `TELEGRAM_NOTIFY_LEVEL` 控制通知頻率（all / notify_only）
- 靜默失敗（無 credentials 或網路問題時不影響 AI CLI 正常運作）
- 提供 `docs/telegram-notify-hook.md` 安裝說明

**Non-Goals:**
- 不支援 GitHub Copilot CLI（無對應 hook 系統）
- 不支援多 Telegram chat / 頻道路由
- 不提供雙向互動（只推送通知，不接受 Telegram 指令）
- 不處理 hook 執行歷史或 retry 邏輯

## Decisions

### D1：共用單一腳本，以 $1 參數區分事件類型

**決定**：Claude Code 與 Gemini CLI 都呼叫同一支 `~/.claude/hooks/telegram-notify.sh`，以 `$1`（`stop` / `notification`）傳入事件類型提示，再從 stdin JSON 的 `hook_event_name` 確認。

**理由**：避免維護兩份腳本；工具差異（環境變數名稱、事件名稱）在腳本內用條件判斷處理，降低日後修改成本。

**替代方案**：分開兩支腳本 → 邏輯重複，捨棄。

---

### D2：使用 `async: true`（Claude Code）避免阻塞

**決定**：Claude Code hook 加上 `"async": true`，讓通知在背景執行，不影響 Claude 回應速度。

**理由**：Telegram 請求有網路延遲（~100-500ms），同步執行會讓每次 Stop 事件都等待網路。`async: true` 讓 Claude Code 在寫完 stdin 後立即繼續，腳本在背景執行。

**Gemini CLI**：不支援 `async` 欄位，但腳本以 `--max-time 10` 限制 curl，且無 credentials 時立即退出，不影響 Gemini 體感速度。

---

### D3：通知等級透過環境變數控制

**決定**：腳本讀取 `TELEGRAM_NOTIFY_LEVEL`（預設 `all`）：
- `all`：Stop 與 Notification 事件均發送
- `notify_only`：只發送 Notification 事件（等待授權），Stop 靜默

**理由**：Stop 事件在長任務中可能連發數十則，使用者明確要求可切換。用環境變數而非 CLI 參數，便於在 `~/.zshrc` 永久設定，也可在特定 shell session 暫時覆蓋（`TELEGRAM_NOTIFY_LEVEL=notify_only claude`）。

---

### D4：腳本放在 `~/.claude/hooks/`

**決定**：腳本路徑 `~/.claude/hooks/telegram-notify.sh`，Gemini CLI 也從此路徑呼叫。

**理由**：`~/.claude/` 是使用者的 Claude Code 全域設定目錄，已有明確語意。統一存放點避免路徑分散。

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Telegram Bot Token 明文存於 `~/.zshrc` | 建議使用 `~/.telegram_secrets` 獨立檔案並加入 `.gitignore`，不強制 |
| `jq` 未安裝時欄位解析失敗 | 使用 `command -v jq` 檢查，fallback 到 `$1` 參數，確保腳本不因 jq 缺失而崩潰 |
| Stop hook 通知過於頻繁 | `TELEGRAM_NOTIFY_LEVEL=notify_only` 切換；文件中明確說明 |
| Gemini CLI hook 事件名稱未來可能變更 | 腳本以 case 匹配 `AfterAgent` 與 `Stop`，其他事件 fallback 到 `$1` 參數 |

## Migration Plan

1. 手動建立 Telegram Bot（@BotFather）
2. 將 credentials 加入 `~/.zshrc`
3. 建立並 chmod 腳本
4. 編輯 `~/.claude/settings.json` 加入 hooks 區塊
5. 編輯 `~/.gemini/settings.json` 加入 hooks 區塊
6. 手動測試腳本（echo JSON | bash script）

**Rollback**：從 `~/.claude/settings.json` 與 `~/.gemini/settings.json` 移除 `hooks` 區塊即可完全還原，腳本可保留不影響任何功能。

## Open Questions

（無）

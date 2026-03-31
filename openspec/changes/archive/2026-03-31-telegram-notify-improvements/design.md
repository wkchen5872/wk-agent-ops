## Context

`scripts/telegram-notify/hook.sh` 的工具偵測目前靠 env var 順序判斷。但根據 Gemini CLI `hookRunner.js` 的原始碼，Gemini 刻意同時注入：

```javascript
GEMINI_PROJECT_DIR: input.cwd,
CLAUDE_PROJECT_DIR: input.cwd,  // For compatibility
```

因此原本「先看 `CLAUDE_PROJECT_DIR`」的邏輯永遠把 Gemini 判定為 Claude Code。正確做法是先看 `GEMINI_PROJECT_DIR`（只有 Gemini 注入），再看 `CLAUDE_PROJECT_DIR`（只有 Claude Code 單獨注入）。

## Goals / Non-Goals

**Goals:**
- 工具偵測邏輯正確：`GEMINI_PROJECT_DIR` 存在 → Gemini CLI；僅 `CLAUDE_PROJECT_DIR` → Claude Code
- `PROJECT_DIR` 優先使用 `GEMINI_PROJECT_DIR`，fallback `CLAUDE_PROJECT_DIR`
- Telegram 訊息加入 `hook_event_name`（方便 debug，兩種事件都顯示）
- 訊息排版優化（更易讀）

**Non-Goals:**
- 不改動 registry.sh、install.sh 等其他腳本
- 不新增新 hook event 類型

## Decisions

### D1：工具偵測順序 — GEMINI_PROJECT_DIR 優先

```bash
if [[ -n "${GEMINI_PROJECT_DIR:-}" ]]; then
  TOOL_NAME="Gemini CLI"
  PROJECT_DIR="${GEMINI_PROJECT_DIR}"
elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  TOOL_NAME="Claude Code"
  PROJECT_DIR="${CLAUDE_PROJECT_DIR}"
else
  TOOL_NAME="AI CLI"   # bug indicator
fi
```

**理由**：`GEMINI_PROJECT_DIR` 只有 Gemini CLI 注入；`CLAUDE_PROJECT_DIR` 兩個都有，所以放後面。

### D2：訊息格式加入 hook event name

在每則通知底部加一行 `🔍 Event: <hook_event_name>`，讓使用者看到實際觸發的 event（`Stop`、`AfterAgent`、`Notification` 等），方便確認 hook 是否正確連接。

### D3：排版優化方向

原格式每行一個 emoji + 資訊，缺乏視覺層次。改為：
- 標題行單獨一行（加粗 + emoji）
- 內容以「分隔線」或「空白行」增加呼吸感
- 關鍵資訊靠前（Tool、Project）
- debug 資訊（Event）置於最後

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Gemini CLI 未來不再注入 `GEMINI_PROJECT_DIR` | `else` fallback 為 `AI CLI`，至少明顯可見而非靜默錯誤 |
| 新排版在不同 Telegram 客戶端渲染差異 | 使用 Markdown（`*bold*`），主流客戶端均支援 |

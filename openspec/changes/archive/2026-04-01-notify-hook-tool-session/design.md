## Context

`hook.sh` 目前依賴 env var（`GEMINI_PROJECT_DIR`、`GITHUB_COPILOT_SESSION_ID`、`CLAUDE_PROJECT_DIR`）判斷 TOOL_NAME。實測發現 Copilot CLI 執行 hook 時這些 env var 不一定存在，導致偵測落回 `CLAUDE_PROJECT_DIR`（若使用者有其他 Claude 工作階段在背景執行）或顯示 "AI CLI"。

此外，通知訊息目前無法識別是哪個 session 觸發，在多 session 並行時難以追蹤。

## Goals / Non-Goals

**Goals:**
- hook.sh 永遠能顯示正確的 TOOL_NAME（不依賴 env var 偵測）
- 通知標題帶入 session 識別，方便追蹤哪個 session 完成

**Non-Goals:**
- 改變 Claude/Gemini 的事件類型或 hook 格式
- 在 hook.sh 中讀取 `~/.claude/projects/` 等目錄結構

## Decisions

### D1: TOOL_NAME 改由呼叫端傳入（$2 參數）

**Decision:** hook.sh 介面從 `hook.sh <event>` 改為 `hook.sh <event> <tool_name>`。registry.sh 在產生 bash 指令時硬寫對應的 tool name：
- Claude: `hook.sh stop "Claude Code"` / `hook.sh notification "Claude Code"`
- Gemini: `hook.sh AfterAgent "Gemini CLI"` / `hook.sh notification "Gemini CLI"`
- Copilot: `hook.sh sessionEnd "Copilot CLI"`

hook.sh 仍保留 env var 偵測作為 fallback（`$2` 為空時），確保向後相容。

**Rationale:** registry.sh 在呼叫端就知道是哪個工具，hardcode 比 env var 偵測更可靠。

**Alternative:** 讓 hook 讀取 stdin JSON 中的工具資訊。不可行 — Copilot/Gemini 的 stdin JSON 結構不同，且 Claude 的 hook 才有完整的 stdin。

---

### D2: Session 識別從 stdin JSON 提取

**Decision:** 依序嘗試以下來源取得 session 識別字串：
1. stdin JSON `.session_id`（Claude Code 有此欄位）
2. stdin JSON `.sessionId`（Copilot CLI 可能的欄位名稱）
3. env var `GITHUB_COPILOT_SESSION_ID`（Copilot，若存在則使用前 8 字元）
4. 若以上皆無 → 不顯示 session 資訊

Session 識別在標題行顯示：若為完整 session name（含英文字元的可讀字串）直接顯示，若為 UUID 格式則只取前 8 字元並加 `#` 前綴。

**Rationale:** 不假設特定 env var，從 stdin 取最完整資訊，降低空值機率。

---

### D3: 向後相容 — $2 為 optional

**Decision:** `$2` 為空時，hook.sh 仍執行原有 env var 偵測邏輯，不 breaking 已部署的舊版指令。

**Rationale:** 舊版 `~/.claude/settings.json` 和 `~/.gemini/settings.json` 可能還是舊格式指令，讓 fix-hooks 更新前仍能正常運作。

## Risks / Trade-offs

- **[Risk] Session 欄位名稱因 CLI 版本而異** → 用多 fallback 降低風險；若所有 fallback 都空，只是不顯示 session，不影響主要通知
- **[Risk] 舊版 hooks.json 使用舊格式指令** → uninstall.sh 的 `unregister_hook_copilot` 需同時能清除舊格式與新格式指令

## Migration Plan

1. 更新 `hook.sh`：增加 `$2` 參數讀取，更新輸出格式
2. 更新 `registry.sh`：`register_hook` 和 `register_hook_copilot` 在指令中加入 tool name
3. 更新 `unregister_hook_copilot`：能清除新格式指令
4. 重新部署：`install.sh` 或 `update.sh fix-hooks` 會更新已部署的 hook 和 settings
5. 使用者需重新執行 fix-hooks 或 install 才能獲得新格式指令；舊版指令仍可運作（D3）

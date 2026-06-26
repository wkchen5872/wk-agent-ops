# 多工具相容性規範 (Multi-Tool Compatibility)

## 核心要求

在進行任何功能規劃（Planning）、規格撰寫（Specs）、設計（Design）或實作（Implementation）時，**必須同時考慮並支援**以下 AI 開發工具：

- **Claude Code**: 主要研發與執行工具。
- **Antigravity**: Google 的 agentic IDE（次要支援目標）。

## 規劃與設計原則

1. **工具感測 (Tool-Awareness)**:
   - 所有的 Hook 腳本必須能偵測當前環境。
   - 識別變數：優先檢查 `CLAUDE_PROJECT_DIR` (Claude Code) -> Fallback `PWD`（Antigravity 於 workspace 內執行，`PWD` 即足夠）。
   - 工具名稱：根據環境變數顯示正確的工具名稱。

2. **跨平台相容性**:
   - 設定檔路徑應避免硬編碼。Claude Code 用 `.claude/` 與 `CLAUDE.md`；Antigravity 用扁平的 `.agent/rules/`、`.agent/workflows/` 與 `GEMINI.md`；跨工具共用 `AGENTS.md`。
   - 若為通用設定，應放置於 `~/.config/` 等中立位置。

3. **介面標準化**:
   - 腳本與工具應優先支援 **Standard Input (stdin)** 接收 JSON 資料，這對 Claude Code 的 Hook 尤為重要。
   - 提供標準的 CLI 參數介面，確保可被各類 AI 工具透過 shell 呼叫。

4. **規則送達兩工具**:
   - Claude Code 讀 `.claude/rules/`；Antigravity 讀**扁平**的 `.agent/rules/*.md`。安裝規則時須同時送達兩者。
   - 跨工具共用規則放 `AGENTS.md`（兩工具共讀）。

## 實作準則

- **Idempotency**: 安裝與更新腳本必須是冪等的（重複執行無害）。
- **Silent Fail**: Hook 腳本在背景執行時，失敗不應阻斷 AI 工具的主要流程。
- **Modern UI**: 通知或輸出訊息應統一格式，支援 Emoji 與清晰的欄位劃分，提供一致的視覺體驗。

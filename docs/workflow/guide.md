# 多 Agent 協作開發工作流 (Master Guide)

本文說明如何結合 **OpenSpec** 與 **Git Worktree**，打造一套支援多個 AI Agent 同步開發的自動化流程。讓多個 Claude 實例可以同時開發不同功能，互不干擾。

---

## 💡 核心概念：兩階段分離 (Two-Phase Separation)

為了極大化並行開發的效率，我們將開發分為兩個性質不同的階段，並指派給不同定位的 Agent：

| 階段 | 負責角色 | 所在環境 | 影響範圍與特性 |
|---|---|---|---|
| **Phase 1: 規劃** | **PM Agent** | 專案根目錄 (`main`) | 只撰寫規格文件 (Markdown)，不改程式碼。 |
| **Phase 2: 實作** | **RD Agent** | 獨立 Worktree (`.worktrees/`) | 修改實際程式碼。為避免互相覆蓋，必須隔離。 |

---

## 🔄 標準協作流程

### 步驟一：需求規劃 (PM Agent)

在專案根目錄執行 `pm-start` 啟動主會話。此時可同時規劃多個功能。

```bash
pm-start    # 啟動 PM Master Session
```

在會話中透過 `/opsx:new` 或 `/opsx:ff` 產出規格文件（`proposal.md`、`design.md`、`tasks.md`）。這些文件會 Commit 至開發主分支。

### 步驟二：獨立開發 (RD Agent)

當任務清單產出後，開啟新的終端機，為該任務建立獨立環境。

```bash
wt-new FEATURE_NAME    # 建立獨立環境並自動啟動 RD Agent
```

**自動偵測模式：**
- **新建**：若是第一次執行，會建立分支與 Worktree 目錄。
- **恢復**：若目錄已存在，會自動進入並恢復上次的 Agent 會話（Resume 模式）。

在 RD Agent 內執行實作與自動收尾：
```bash
/opsx:apply FEATURE_NAME   # 依規格自動實作
/openspec-commit           # 一鍵完成 歸檔 -> 更新文件 -> Git Commit
```

### 步驟三：合併與清理

功能開發完成後，回到主終端機將程式碼合併回主分支。

```bash
wt-done FEATURE_NAME    # 合併分支、刪除 Worktree 並清理環境
```

---

## 📚 延伸閱讀

*   **腳本手冊與安裝**：關於 `wt-new`、`wt-done` 的詳細參數、補全機制與安裝方法，請參閱 [Worktree 腳本參考](../../scripts/workflow/README.md)。
*   **自動化收尾機制**：了解 `/openspec-commit` 如何自動分析變更並更新說明文件，請參閱 [OpenSpec Commit 工作流](commit.md)。
*   **多工具相容性**：本流程同時支援 Claude Code, Github Copilot, Gemini CLI 與 Codex，詳見 [AGENTS.md](../../AGENTS.md)。

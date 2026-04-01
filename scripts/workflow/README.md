# Workflow 自動化腳本手冊
# Worktree 自動化腳本手冊 (Technical Reference)

本目錄包含一組輔助 `git worktree` 開發流程的腳本，旨在簡化多 Agent 的開發環境建立、切換與清理。

---

## 🛠️ 安裝

執行安裝腳本將命令加入您的 Zsh 配置，並啟用 Tab 自動補全：

```bash
bash scripts/workflow/install.sh
source ~/.zshrc
```

**特性：**
* **冪等性**：重複安裝不影響現有設定。
* **補全功能**：支援 `wt-work <TAB>` 列出現有 Feature，`--agent <TAB>` 列出工具選項。
* **自動清理**：若 `wt-new` 舊版本仍存在，安裝時自動移除。

---

## ⌨️ 指令手冊 (Command Reference)

### 1. `wt-work <feature-name>`
**用途**：建立或恢復一個 coding 工作環境，並自動帶入 `/opsx:apply` 初始 prompt。
*   **參數**：
    *   `--base <branch>`：指定基礎分支（預設 `main`）。
    *   `--agent <name>`：指定啟動的工具（`claude`|`copilot`|`gemini`|`codex`）。
    *   `--session <id|name>`：指定要恢復的 AI CLI session ID 或名稱（選填）。
*   **模式**：
    *   **New**：建立 feature 分支與 `.worktrees/` 目錄，並複製 `.env` 與 `settings.local.json`，然後啟動 agent。
    *   **Resume**：偵測到目錄已存在時，自動 `cd` 並以 `"RD: FEATURE"` 恢復 Claude session（或顯示選單）。
*   **注意**：無論新建或恢復，均自動傳入 `/opsx:apply FEATURE` 作為初始 prompt。

### 2. `wt-done <feature-name>`
**用途**：合併開發內容並清理 Worktree。
*   **參數**：
    *   `--base <branch>`：合併回的目標分支（預設 `main`）。
*   **動作**：切換至 base branch -> 合併 feature -> 移除 Worktree 目錄 -> `git worktree prune` -> 刪除分支 -> 重置 iTerm2 徽章。

### 3. `wt-resume <feature-name>`
**用途**：恢復 Agent 對話 session（不自動帶入 opsx:apply）。
*   **參數**：
    *   `--agent <name>`：指定工具（`claude`|`copilot`|`gemini`|`codex`）。
    *   `--session <id|name>`：指定要恢復的 session ID 或名稱（選填）。
*   **特性**：
    *   無 `--session` 時：Claude/Copilot 顯示互動選單，Gemini 自動恢復最新 session。
    *   有 `--session` 時：直接傳給工具的 `--resume` 參數。
    *   即使目錄已被 `wt-done` 刪除，仍可透過此命令恢復 session。

### 4. `pm-start`
**用途**：在專案根目錄啟動「規劃大腦」PM Master Session。
*   **特性**：會話名稱固定為 `PM: <repo-name>`。

---

## ⚙️ 進階配置

*   **Zsh Completion**：安裝後自動載入 `_wt` 補全函式，支援 feature name、`--agent`（含 `gemini`）、`--session` 補全。
*   **iTerm2 整合**：腳本執行期間會動態更新 iTerm2 的 Badge（徽章），方便識別目前的 feature 環境。
*   **環境要求**：
    *   `git` 2.5+ (必須支援 worktree)
    *   `bash` 4+

---

## 🔗 相關說明

*   **協作流程概覽**：了解如何配合 OpenSpec 進行多 Agent 開發，請看 [多 Agent 協作工作流](../../docs/workflow/guide.md)。
*   **自動化 Commit**：了解 `/openspec-commit` 的運作原理，請看 [OpenSpec Commit 工作流](../../docs/workflow/commit.md)。

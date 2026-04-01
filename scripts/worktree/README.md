### 基於 OpenSpec 與 Git Worktree 的多 Agent 協作開發工作流

五個腳本（`install.sh`, `wt-new.sh`, `wt-done.sh`, `wt-resume.sh`, `pm-start.sh`）旨在結合 [OpenSpec](https://github.com/Fission-AI/OpenSpec) 與 `git worktree`，打造一套支援多個 AI Agent 同步開發的自動化流程。

透過 `git worktree` 的特性，我們可以為每個功能任務建立獨立的工作目錄，有效避免多個 Agent 在實作時互相覆蓋或改動到相同的檔案。

**🔄 核心工作流程 (Workflow)**

1. **需求規劃 (PM Agent)：**
   使用 `pm-start` 啟動 PM Master Session，由 PM Agent 透過 OpenSpec 產生各項規格與變更清單（如：`proposal.md`、`design.md`、`tasks.md`）。
2. **獨立開發 (RD Agent)：**
   使用 `wt-new <name>` 自動建立專屬的 feature 分支與 worktree 目錄，並開啟新的對話作為 RD Agent 進行實作。若 worktree 已存在，`wt-new <name>` 會自動切換至 **resume 模式**——中途外出後只需再執行一次 `wt-new <name>` 即可繼續。Agent 在獨立環境下開發，互不干擾。
3. **合併與清理 (Merge & Clean)：**
   開發完成後，使用 `wt-done <name>` 將 feature 分支合併回 `main` 分支，並自動刪除對應的 worktree 與暫存環境。
4. **事後回顧 (Post-done Resume)：**
   若需要在 `wt-done` 刪除 worktree 後重新進入 session（例如：code review），使用 `wt-resume <name>` 以 session 名稱恢復，無需 worktree 目錄存在。

**🛠️ 腳本功能說明 (Scripts)**

* **`install.sh`**
  * 安裝初始化環境，將所有腳本配置到系統中，並安裝 zsh tab 補全。
* **`wt-new.sh`**
  * **Usage:** `wt-new <feature-name> [--base <branch>] [--agent claude|copilot|codex]`
  * **自動偵測模式：** 若 worktree 已存在 → RESUME 模式（顯示 `Mode: resume` banner）；否則 → NEW SESSION 模式（顯示 `Mode: new` banner）。
  * **建立環境（new）：** 從 `BASE_BRANCH`（預設 `main`，可用 `--base develop` 覆寫）建立 feature branch 與 worktree 目錄，複製 `settings.local.json` 與 `.env`。
  * **恢復環境（resume）：** 進入已有的 worktree，以 `--resume "RD: <name>"` 恢復 Claude session。
* **`wt-done.sh`**
  * **Usage:** `wt-done <feature-name> [--base <branch>]`
  * **合併分支：** 將 feature branch 合併回 `BASE_BRANCH`（預設 `main`，可用 `--base develop` 覆寫）。
  * **清理環境：** 移除 worktree 目錄、執行 `git worktree prune`、刪除 feature branch、重置 iTerm2 badge。
  * **衝突處理：** merge 失敗時提示執行 `wt-resume <name>` 以 agent 協助解衝突。
* **`wt-resume.sh`**
  * **Usage:** `wt-resume <feature-name>`
  * 以 session 名稱恢復 Claude agent session。若 worktree 目錄存在則 `cd` 進入後再恢復；若已被 `wt-done` 刪除，則從當前目錄以 `--resume` 恢復。
* **`pm-start.sh`**
  * **Usage:** `pm-start`
  * 從 repo 根目錄啟動（或恢復）名為 `PM: <repo-name>` 的 PM Master Claude session，以 `--permission-mode plan` 開啟（Plan Mode，不自動執行指令）。

**⌨️ Zsh Tab 補全**

安裝後，`wt-new`、`wt-done`、`wt-resume` 支援按 `<TAB>` 自動補全 `.worktrees/` 目錄下的 feature 名稱：

```zsh
wt-new <TAB>      # 列出現有 worktree 名稱
wt-done <TAB>     # 列出現有 worktree 名稱
wt-resume <TAB>   # 列出現有 worktree 名稱
```
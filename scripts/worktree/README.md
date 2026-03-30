### 基於 OpenSpec 與 Git Worktree 的多 Agent 協作開發工作流

三個腳本（`install.sh`, `wt-new.sh`, `wt-done.sh`）旨在結合 [OpenSpec](https://github.com/Fission-AI/OpenSpec) 與 `git worktree`，打造一套支援多個 AI Agent 同步開發的自動化流程。

透過 `git worktree` 的特性，我們可以為每個功能任務建立獨立的工作目錄，有效避免多個 Agent 在實作時互相覆蓋或改動到相同的檔案。

**🔄 核心工作流程 (Workflow)**

1. **需求規劃 (PM Agent)：** 
   在主對話（Master Session）中由 PM Agent 主導，透過 OpenSpec 產生各項規格與變更清單（如：`proposal.md`、`design.md`、`tasks.md`）。
2. **獨立開發 (RD Agent)：** 
   使用 `wt-new.sh` 自動建立專屬的 feature 分支與 worktree 目錄，並開啟新的對話作為 RD Agent 進行實作。Agent 在獨立環境下開發，互不干擾。
3. **合併與清理 (Merge & Clean)：** 
   開發完成後，使用 `wt-done.sh` 將 feature 分支合併回 `main` 分支，並自動刪除對應的 worktree 與暫存環境。

**🛠️ 腳本功能說明 (Scripts)**

* **`install.sh`**
  * 安裝初始化環境，將 `wt-new.sh` 與 `wt-done.sh` 配置到系統中。
* **`wt-new.sh`**
  1. **建立環境：** 建立專屬的 feature branch 與對應的 `git worktree` 目錄。
  2. **環境配置：** 將主環境的相關設定檔複製到新建的 worktree 中。
  3. **啟動任務：** 自動進入 worktree 目錄並執行 `claude` 指令，同時透過 `opsx:apply` 指令讓 RD Agent 自動開始執行實作任務。
* **`wt-done.sh`**
  * **合併分支：** 將實作完成的 feature branch 合併回 `main` 分支。
  * **清理環境：** 刪除該 feature branch 以及對應的 worktree 目錄，釋放空間。
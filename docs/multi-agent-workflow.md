# 基於 OpenSpec 與 Git Worktree 的多 Agent 協作開發工作流

本文說明如何結合 **OpenSpec** 與 **Git Worktree**，打造一套支援多個 AI Agent 同步開發的自動化流程。讓多個 Claude 實例可以同時開發不同功能，互不干擾。

## 💡 核心概念：兩階段分離

為了極大化並行開發的效率，我們將開發分為兩個性質不同的階段，並指派給不同定位的 Agent：

| 階段 | 負責角色 | 所在環境 | 執行指令 | 影響範圍與特性 |
|---|---|---|---|---|
| **規劃** | **PM Agent** | `develop` 主分支 | `/opsx:new` 等 | 只撰寫規格文件（Markdown），不改程式碼，**不需隔離**。 |
| **實作** | **RD Agent** | 獨立 Worktree | `/opsx:apply` 等 | 修改實際程式碼，為避免互相覆蓋，**必須隔離**。 |

---

## 🔄 並行開發標準流程

### 步驟一：需求規劃 (PM Agent 在主環境)

在主 Claude 視窗（工作目錄為專案根目錄，位於 `develop` 分支）進行需求拆解與規格撰寫。此時可**同時規劃多個功能**，產出的 Markdown 文件會直接 Commit 至 `develop` 分支。

**執行指令：**

```text
/opsx:new           ← 描述需求，OpenSpec 將產出 feature 名稱（如 etf-nav-fetcher）
/opsx:continue ×4   ← 依序產出 proposal → specs → design → tasks
```

> **💡 進階技巧：一鍵完成全套規劃 (Auto-Planning)**
> 為了避免手動輸入 4 次 `/opsx:continue`，你可以在啟動 PM Agent 時（或下達需求前），先給予以下 System Prompt，讓 Agent 一口氣把所有文件寫完再來找你 Review：
> 
> ```text
> 你現在扮演 SA (System Analyst) 與 PO (Product Owner) 的角色。
> 接下來我會透過 `/opsx:ff` 或 `/opsx:new` 指令提供開發需求給你。
> 
> 為了加速開發節奏，當我給予需求後，請你「自動且連續地」完成以下四個階段的規劃與檔案產出：
> 1. Proposal (提案：proposal.md)
> 2. Specs (規格：specs/...)
> 3. Design (設計：design.md)
> 4. Tasks (任務：tasks.md)
> 
> 請依序直接產出所有內容並寫入對應的檔案中。在全部 4 個階段都完成之前，請「不要中斷」詢問我是否繼續。等所有檔案（proposal、specs、design、tasks）都建立完畢後，再通知我進行一次性的整體 Review。
> ```

### 步驟二：獨立開發 (RD Agent 在 Worktree)

當 `tasks.md` 產出（或 Review 確認無誤）後，即可開啟新的終端機，啟動 RD Agent 進行實作。
每個功能都會在獨立的 Worktree 中進行，完全不會影響到 `develop` 或其他正在開發的功能。

**執行指令：**

```bash
# 在終端機執行：建立獨立環境並自動啟動 Claude
wt-new FEATURE_NAME
```

feature 名稱建議與 openspec change 的名稱同名，會便於管理


```bash
# 在自動啟動的 Claude 中執行：
/opsx:apply etf-nav-fetcher   ← RD Agent 依照規格自動開始撰寫程式碼
/opsx:commit                  ← 實作完成後，一鍵完成 archive、更新文件與 Git Commit
```
> *註：若 `wt-new` 發現 Worktree 已存在，會直接啟動 Claude 並進入該目錄，適合關閉視窗後重新進入。*

### 步驟三：合併與清理 (Merge & Clean)
功能開發並 Commit 完成後，回到主終端機將程式碼合併回主分支，並釋放環境。

**執行指令：**

```bash
wt-done FEATURE_NAME
```

* **合併成功：** 自動切回 `develop`、合併分支、移除 Worktree 目錄並刪除 feature branch。
* **發生衝突：** 腳本會安全停下並印出提示，請依提示手動解決衝突（Resolve Conflicts）後再完成清理。

---

## 🛠️ 環境配置與工具說明

### 1. Worktree 自動化腳本

為簡化 Git 操作，我們提供了 `wt-new` 與 `wt-done` 腳本。

* **安裝方式：** 執行 `bash scripts/worktree/install.sh` 並 `source ~/.zshrc`。
* **特性：** 安裝腳本具備冪等性（重複執行無害），且後續更新 `.sh` 檔即可自動生效。

### 2. `/commit-feature` 專屬 Skill

這是一個 Claude Code skill，用於在 RD Agent 實作完成（`opsx:apply`）後的一鍵收尾。

* **功能：** 自動執行 `opsx:archive`（封存規格） → 更新 `docs/` 相關文件 → 依據 Conventional Commits 規範執行 `git commit`。
* *(詳細安裝與運作原理請參閱[docs/commit-feature-workflow.md](commit-feature-workflow.md))*
* *Skill 定義：`skills/openspec-commit/SKILL.md`*

---

## ❓ 常見問題 (FAQ)

**Q: 兩個功能同時開發，改到同一個程式碼檔案怎麼辦？**
RD Agent 會在各自的 Worktree 修改。合併時（執行 `wt-done`），Git 會正常報出 Conflict，此時腳本會暫停，開發者只需依照一般 Git 流程手動解決衝突並 Commit 即可。

**Q: `openspec/specs/` 裡面的規格檔會不會衝突？**
執行 `/commit-feature` (內含 `/opsx:archive`) 時，會將規格同步到 `openspec/specs/`。若兩個功能新增不同的 spec 檔案不會有問題；若剛好改到同一個 spec 檔案，同樣在 `wt-done` 時手動解決合併衝突即可。

**Q: 規劃階段（Phase 1）可以在 Worktree 裡面做嗎？**
技術上可以，但沒有必要。規劃階段只會產出 Markdown 文件，不會動到系統程式碼，直接在 `develop` 集中規劃能讓流程更單純。

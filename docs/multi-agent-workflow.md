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

**啟動 PM Agent：**

```bash
pm-start    ← 以 Plan Mode 啟動（或恢復）PM Master Session，session 名稱為 "PM: <repo-name>"
```

**在 PM Agent 內執行：**

```text
/opsx:new           ← 描述需求，OpenSpec 將產出 feature 名稱（如 feature123）
/opsx:continue ×4   ← 依序產出 proposal → specs → design → tasks
or 
/opsx:ff            ← 描述需求，OpenSpec 將自動產出所有文件
```

### 步驟二：獨立開發 (RD Agent 在 Worktree)

當 `tasks.md` 產出（或 Review 確認無誤）後，即可開啟新的終端機，啟動 RD Agent 進行實作。
每個功能都會在獨立的 Worktree 中進行，完全不會影響到 `develop` 或其他正在開發的功能。

**執行指令：**

```bash
# 在終端機執行：建立獨立環境並自動啟動 Agent
wt-new FEATURE_NAME

# 指定不同 Agent（預設 claude）
wt-new FEATURE_NAME --agent copilot

# 指定不同 base branch（預設 main）
wt-new FEATURE_NAME --base develop
```

feature 名稱建議與 openspec change 的名稱同名，會便於管理。

**`wt-new` 自動偵測模式：**
- Worktree **不存在** → 🚀 NEW SESSION：建立 branch + worktree，複製 `.env` 與 `settings.local.json`
- Worktree **已存在** → 🔄 RESUMING：直接進入並恢復 Agent session（中途外出後只需再執行一次 `wt-new <name>` 即可繼續）


```bash
# 在自動啟動的 Claude 中執行：
/opsx:apply feature123   ← RD Agent 依照規格自動開始撰寫程式碼
/opsx:commit                  ← 實作完成後，一鍵完成 archive、更新文件與 Git Commit
```

### 步驟三：合併與清理 (Merge & Clean)
功能開發並 Commit 完成後，回到主終端機將程式碼合併回主分支，並釋放環境。

**執行指令：**

```bash
wt-done FEATURE_NAME

# 指定不同 base branch（預設 main）
wt-done FEATURE_NAME --base develop
```

* **合併成功：** 自動切回 base branch、合併分支、移除 Worktree 目錄、執行 `git worktree prune`、刪除 feature branch，並重置 iTerm2 badge。
* **發生衝突：** 腳本安全停下並提示使用 `wt-resume FEATURE_NAME` 以 Agent 協助解衝突，或手動解決後清理。

### 步驟四：事後回顧 (Post-done Resume)
若在 `wt-done` 刪除 worktree 後需要重新進入 session（例如：code review），使用 `wt-resume`。

```bash
wt-resume FEATURE_NAME

# 指定不同 Agent
wt-resume FEATURE_NAME --agent copilot
```

* Worktree 目錄**存在**：`cd` 進入後以 `--resume` 恢復（僅 claude）。
* Worktree 目錄**已刪除**：從當前目錄以 session 名稱恢復（claude），或直接啟動（copilot/codex）。

---

## 🛠️ 環境配置與工具說明

### 1. Worktree 自動化腳本

為簡化 Git 操作，我們提供了 `wt-new`、`wt-done`、`wt-resume`、`pm-start` 腳本與 zsh tab 補全。

* **安裝方式：** 執行 `bash scripts/worktree/install.sh` 並 `source ~/.zshrc`。
* **特性：** 安裝腳本具備冪等性（重複執行無害），且後續更新 `.sh` 檔即可自動生效。
* **Tab 補全：** 安裝後 `wt-new <TAB>`、`wt-done <TAB>`、`wt-resume <TAB>` 可自動列出現有 feature 名稱（zsh）。

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

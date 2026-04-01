# OpenSpec + Git Worktree 並行開發模式

本文件說明如何利用 Git Worktree 的特性，達成多個 AI Agent 同時並行開發不同功能的底層運作原理與工程實務。

---

## 為什麼需要 Worktree 並行模式？

在傳統的 Git 分支開發中，切換功能（Context Switching）通常需要 `git checkout`，這會導致：
1. **中斷開發**：必須先 `git commit` 或 `git stash` 才能切換，否則未完成的變更會跟著跑。
2. **環境衝突**：無法同時在本地運行兩個不同分支的服務（例如：同時跑開發版與測試版）。
3. **編譯等待**：切換分支後，往往需要重新編譯或重新安裝依賴。

**Worktree 解決了這些問題**，它讓每個功能擁有「獨立的實體目錄」，讓你只需切換終端機視窗就能瞬間切換開發上下文。

---

## 核心概念
每個功能由一個 **Worktree（獨立目錄/Branch）** 與一個 **AI Agent 視窗** 組成，確保開發過程互不干擾。

```text
my-project/                   ← 主倉庫 (main branch)
├── .env                      ← 環境變數 (Source)
└── .worktrees/               ← 存放所有開發中的功能實體
    ├── user-login/           ← Agent A 的獨立實體空間
    └── data-export/          ← Agent B 的獨立實體空間
```

---

## 標準流程 (Under the Hood)

### Step 1 — 建立隔離環境
在專案根目錄執行，建立 feature 分支並對應到 `.worktrees/` 目錄：
```bash
git worktree add .worktrees/user-login -b feature/user-login
```

### Step 2 — 複製環境配置
由於 `.env` 等敏感檔案通常不在 Git 中，建立 Worktree 後需手動同步：
```bash
cp .env .worktrees/user-login/
```

### Step 3 — 啟動 Agent
開啟新的終端機視窗，進入該目錄啟動 Agent：
```bash
cd .worktrees/user-login && claude 
```

### Step 4 — OpenSpec 流程
在各自視窗執行 `/opsx:new` → ... → `/opsx:archive`。

### Step 5 — 合併與清理
功能開發完成並 Commit 後，回到主目錄進行合併：
```bash
git checkout main
git merge feature/user-login

# 移除 worktree 目錄並清理 git 狀態
git worktree remove .worktrees/user-login
git branch -d feature/user-login
```

---

## 避坑指南 (Precautions)

| 挑戰 | 說明與對策 |
| :--- | :--- |
| **依賴更新** | 若 A 功能新增了 library，B 功能的本地執行可能會壞掉。對策：兩邊都需執行 `npm install`。 |
| **環境變數** | 修改了主目錄的 `.env` 後，記得同步到各個 `.worktrees/` 下。 |
| **資料庫衝突** | 若兩個功能共用同一個本地資料庫（如 SQLite），寫入時可能產生競爭。 |
| **命名一致性** | Branch 名、Worktree 目錄名、OpenSpec Change 名三者保持一致，維護最輕鬆。 |
| **OpenSpec/Specs/ 衝突** | Archive 時會同步 Spec 到 `openspec/specs/`，若兩個功能修改同一個 Spec 才會衝突。 |

---

## 🚀 更好的做法：使用自動化腳本

為了減少重複的手動操作，本專案提供了 `wt-work` 與 `wt-done` 腳本。這些腳本已將上述步驟（包含自動建立目錄、複製環境變數、iTerm2 標籤設定、OpenSpec 自動對齊）封裝完畢：

- **啟動/繼續工作**：`wt-work user-login`
- **完成合併收尾**：`wt-done user-login`

詳細用法請參考：[Worktree 腳本手冊](../../scripts/workflow/README.md)

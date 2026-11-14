---
type: Playbook
title: Git Commit Writer
description: Stage a completed worktree and create one Conventional Commits commit.
tags: [skills, git, commits]
timestamp: 2026-08-01T00:00:00+08:00
---

# Git Commit Writer

`git-commit-writer` 是一個專門用來生成符合 [Conventional Commits](https://www.conventionalcommits.org/) 規範之 Git commit 的自動化工具。它可以作為 `openspec-commit` 流程的一部分自動被呼叫，也可以由開發者獨立手動觸發。

---

## 核心功能

1. **精確 Context 優先**：若由 `openspec-commit` 呼叫，會直接接收並使用 `archive_path` 與 `change_id`；若為獨立呼叫，則依當前分支與 staged 變更自動關聯。
2. **自動推斷 Commit Type**：根據 `git diff` 內容自動判斷變更性質（`feat`, `fix`, `docs`, `refactor`, `chore`, `test`）。
3. **高品質 Subject 與 Body**：從 proposal 或實際變更內容推導「為什麼改 (Why)」與「改了什麼 (What)」。
4. **透明的協作標註**：
   - `Co-Authored-By`: 自動標註執行的 AI 工具與對應 email（如 Claude Code 或 Codex）。
   - `AI-Assisted-By`: 記錄協作的 AI 模型名稱。
   - `Refs`: 自動帶入本次工作直接處理且已確認的 GitHub Issue 或 PR 編號（如 `Refs: #19`）。
5. **完整 Staging 防護**：自動執行 `git add -A`，若無任何變更則安全停止；若觸發 pre-commit hook 格式化檔案，會重新 staging 後再完成提交。
6. **即刻執行**：生成符合規範的訊息後直接執行 `git commit`，不需開發者反覆手動確認。

---

## 運作流程

```text
               ┌────────────────────────┐
               │ 呼叫 git-commit-writer │
               └───────────┬────────────┘
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
    [由 openspec-commit 呼叫]        [手動獨立呼叫]
    接收精確 archive_path         自動偵測當前分支與變更
             │                           │
             └─────────────┬─────────────┘
                           ▼
                  執行 git add -A
                           │
                           ▼
                 Staged diff 是否為空？
                 ├─ 是 ──► 停止（Nothing to commit）
                 └─ 否
                           │
                           ▼
             推斷 commit type, subject, body
             並附加 Refs 與 AI 協作標籤
                           │
                           ▼
                    執行 git commit
                           │
                           ▼
                  Pre-commit hook 檢查
                 ├─ 失敗 ──► 修正後重新 git add -A 並重試
                 └─ 通過
                           │
                           ▼
             完成提交，回傳 commit hash 與主旨
```

---

## Commit 格式規範

### 1. 帶有 OpenSpec Context（標準開發流程）
```text
<type>(<change-id>): <subject>

<body>

Refs: #19
Co-Authored-By: Claude Code <noreply@anthropic.com>
AI-Assisted-By: Claude 3.7 Sonnet
```

### 2. 無 OpenSpec Context（一般獨立提交）
```text
<type>: <subject>

<body>

Co-Authored-By: Codex <noreply@openai.com>
AI-Assisted-By: GPT-6
```

### Trailer 標籤說明
- **Refs**：直接處理的 Issue 或 PR 編號（同 repo 寫 `#N`，跨 repo 寫完整網址）。
- **Co-Authored-By**：目前已驗證支援 `Claude Code <noreply@anthropic.com>` 與 `Codex <noreply@openai.com>`。
- **AI-Assisted-By**：記錄本次協作的核心模型名稱（如 `GPT-6` 或 `Claude 3.7 Sonnet`）。

---

## Type 推斷原則

| 變更性質 | Type | 適用情境範例 |
| :--- | :--- | :--- |
| **新功能 / 新能力** | `feat` | 新增資料來源、新工具、新 Skill、新功能 |
| **修復錯誤** | `fix` | 修正解析邏輯、修復 Bug、修正型別錯誤 |
| **重構** | `refactor` | 結構調整、不改變對外行為的程式碼優化 |
| **文件** | `docs` | 僅修改 `docs/`、`README.md` 或註解 |
| **維護 / 設定** | `chore` | 修改 `.gitignore`、更新 dependencies、調整安裝腳本 |
| **測試** | `test` | 新增或更新測試案例、測試腳本 |

---

## 獨立使用方式（新人 Step-by-Step）

當你已經手動完成開發，想要快速產生標準 commit 時：

### 步驟 1：確認工作區狀態
先透過 `git status` 確認你的程式碼已完成且工作區處於欲提交狀態。

### 步驟 2：呼叫 Agent 或 Skill
- **在 Claude Code 中**：
  ```text
  @"git-commit-writer-agent"
  ```
- **在 Codex 中**：
  直接輸入指令呼叫 `git-commit-writer`。
- **在其他支援 Project Skill 的環境中**：
  呼叫 `/git-commit-writer`。

### 步驟 3：檢視提交結果
工具會自動暫存變更、分析變更內容、產生合規的 Conventional Commit 訊息並完成提交。最後會輸出產生的 commit hash 與主旨供你核對。

> [!TIP]
> 如果你的變更屬於完整的 OpenSpec 規格流程，建議使用 [`openspec-commit`](/docs/skills/openspec-commit.md)，它會自動串聯 Change 封存、文件更新與此提交工具。

---

## 相關組件與原始碼

- **Skill 定義**：`template/common/skills/git-commit-writer/SKILL.md`
- **Claude Agent**：`template/common/.claude/agents/git-commit-writer-agent.md`
- **Codex Agent**：`template/common/.codex/agents/git-commit-writer-agent.toml`
- **安裝目標**：`.claude/skills/git-commit-writer/` 與 `.agents/skills/git-commit-writer/`
- **上層工作流**：[OpenSpec Commit 工作流程](/docs/workflow/commit.md)

---
type: Playbook
title: Git Commit Writer
description: Stage a completed worktree and create one Conventional Commits commit.
tags: [skills, git, commits]
timestamp: 2026-07-30T00:00:00+08:00
---

# Git Commit Writer

`git-commit-writer` 是一個專門用來生成符合 [Conventional Commits](https://www.conventionalcommits.org/) 規範之 git commit 的工具。它可以作為 `openspec-commit` 流程的一部分，也可以獨立呼叫。

---

## 核心功能

1. **精確 context 優先**：caller 提供 `archive_path` 與 `change_id` 時直接驗證並使用；只有獨立呼叫才自動偵測。
2. **語意化 Commit Type**：根據 `git diff` 內容自動推斷 type (feat, fix, docs, refactor, chore, test)。
3. **高品質 Subject/Body**：從 `proposal.md` 或 diff 內容推斷變更的原因 (Why) 與細節 (What)。
4. **Co-Authored-By 注入**：自動在 commit footer 加入執行該操作的 AI 模型名稱。
5. **完整 staging guard**：先 `git add -A`，空 staged diff 不 commit；hook 修正後重新 staging。
6. **即刻執行**：生成後不需額外確認，直接執行 `git commit`。

---

## 運作流程

```mermaid
graph TD
    Start[呼叫 git-commit-writer] --> Context{caller 有完整 archive context?}
    Context -- Yes --> Validate[驗證精確 archive_path]
    Context -- No --> Detect[從 Git status / openspec list<br/>找唯一候選]
    Validate --> Stage[git add -A]
    Detect --> Stage
    Stage --> Empty{cached diff 為空?}
    Empty -- Yes --> Stop[停止：Nothing to commit]
    Empty -- No --> Infer[依 staged diff + proposal<br/>推斷訊息]
    Infer --> Commit[執行 git commit]
    Commit --> Hook{hook 通過?}
    Hook -- No --> Restage[修正後重新 git add -A]
    Restage --> Commit
    Hook -- Yes --> Done[回傳 commit hash / subject]
```

---

## OpenSpec context

`openspec-commit` 會傳入一組不可拆分的值：

```text
archive_path=<exact archived change directory>
change_id=<OpenSpec change id without date prefix>
```

少一個值或路徑不存在就停止，不可改抓「最新」archive。獨立呼叫且沒有
context 時，才依序尋找唯一的未 commit archive、唯一的 active change，最後
退回無 scope 的 Git diff。任何層級有多個候選都不得選第一筆。

---

## Commit 格式規範

### 帶有 OpenSpec Context
```
<type>(<change-id>): <subject>

<body>

Co-Authored-By: <Model Name> <noreply@anthropic.com>
```

### 無 OpenSpec Context
```
<type>: <subject>

<body>

Co-Authored-By: <Model Name> <noreply@anthropic.com>
```

---

## Type 推斷原則

| 變更性質 | Type | 範例 |
| :--- | :--- | :--- |
| **新功能 / 新能力** | `feat` | 新增資料來源、新工具、新 Skill |
| **修復錯誤** | `fix` | 修正爬蟲解析邏輯、修正邏輯錯誤 |
| **重構** | `refactor` | 結構調整、不改變外部行為的程式優化 |
| **文件** | `docs` | 僅修改 `docs/` 或 `README.md` |
| **腳本、設定、維護** | `chore` | 修改 `.gitignore`、更新 dependencies、調整 CI |
| **測試** | `test` | 新增或修正測試案例 |

---

## 獨立使用方式

如果你已經手動實作完畢，想直接提交：

1. **Claude Code**：輸入 `@"git-commit-writer (agent)"`
2. **支援 project skill 的 host**：呼叫 `git-commit-writer`
3. **完整 OpenSpec 收尾**：改呼叫 `openspec-commit`，由協調層傳入精確
   archive context

> [!TIP]
> 自動偵測只供獨立呼叫。`openspec-commit` 一律傳入精確的
> `archive_path` 與 `change_id`。

---

## 相關組件

- **Skill**: `template/common/skills/git-commit-writer/SKILL.md`
- **Agent**: `template/common/.claude/agents/git-commit-writer.md`
- **Installed portable skill**: `.claude/skills/git-commit-writer/SKILL.md`、
  `.agents/skills/git-commit-writer/SKILL.md`
- **Workflow**: [OpenSpec Commit Workflow](/docs/workflow/commit.md)

# Citations

[1] [Conventional Commits](https://www.conventionalcommits.org/)

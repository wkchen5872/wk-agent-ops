---
type: Playbook
title: OpenSpec Commit 操作指南
description: 使用 openspec-commit 技能一次完成 Change 封存、文件同步、Git 提交與遠端交付。
tags: [skills, openspec, git, commit, handoff]
timestamp: 2026-11-14T00:00:00+08:00
---

# OpenSpec Commit 操作指南

`openspec-commit` 是一個高效率的收尾協調工具。當功能實作完成且驗收通過後，它負責自動串接**封存規格**、**更新說明文件**與**建立標準 Git Commit**；若已取得授權，還能一併將成果交付至遠端 PR。

詳細設計架構可參考工作流文件：[OpenSpec Commit 工作流程](/docs/workflow/commit.md)。

---

## 協調運作流程

```text
               ┌────────────────────────┐
               │  呼叫 openspec-commit  │
               └───────────┬────────────┘
                           │
                           ▼
           【步驟 1：openspec-archive-change】
           封存 change 目錄至 archive/
           同步更新主要 specs
                           │
                           ▼
                【步驟 2：doc-updater】
           自動分析變更並更新 docs/ 與 README
           文件改動留在工作區與變更一同提交
                           │
                           ▼
             【步驟 3：git-commit-writer】
           自動暫存變更、分析 diff
           產生 Conventional Commit 並完成提交
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
       [本地完成 (預設)]             [授權遠端交付]
       完成 commit 即停止           1. 正常 push 到遠端
       不推送 remote、不改動 PR     2. 以 github-pr update 更新說明
                                    3. 發布最終 Closure 留言
```

---

## 新人 Step-by-Step 使用教學

### 步驟 1：確認功能已實作並驗證

在執行 commit 之前，請確認：
- 規格的所有任務已透過 `openspec-apply-change` 完成。
- 專案測試與 `openspec-verify-change` 通過（或已完成 `change-review` 取得 pass）。

### 步驟 2：呼叫指令進行提交

依據你使用的 AI 工具，輸入對應指令：

- **在 Claude Code 中**：
  ```text
  /opsx:commit
  ```
  （若有多個 change 可加上名稱：`/opsx:commit <change-id>`）
- **在 Antigravity 中**：
  ```text
  /opsx-commit
  ```
- **在 Codex 中**：
  直接輸入指令：
  ```text
  執行 openspec-commit
  ```

### 步驟 3：檢視自動化執行過程

工具會自動依序完成：
1. **Archive**：將 `openspec/changes/<change-id>/` 搬移到 `openspec/changes/archive/`，並確認規格同步狀態。
2. **Docs Update**：比對實際完成的程式碼差異，就地更新相關說明文件（例如 `docs/`、`README.md`、`AGENTS.md`）。
3. **Commit**：將所有變更（含程式碼、文件、封存規格）打包成一個符合規範的 Conventional Commit，並附帶相關 Issue 引用與 AI 協作標籤。

### 步驟 4：選用的遠端交付（需授權）

若此 Change 在遠端已有對應的 PR，且你希望一鍵交付到 PR：

```text
/opsx:commit 並交付到 PR
```

此時工具會在本地 commit 完成後：
1. 正常推送到遠端分支。
2. 呼叫 `github-pr update` 說明最新交付內容。
3. 確認最終 HEAD 的審查狀態，並發表 Closure 結案留言。

---

## 異常與中斷復原

若流程在半途（例如 pre-commit hook 失敗或網路斷線）中斷：
- **不必重新來過**：再次執行 `/opsx:commit`，工具會自動從工作區殘留的 `archive/` 目錄作為起點 resume，繼續完成尚未完成的文件更新或 commit。
- **不會產生重複 commit**：若 commit 已建立但遠端推送失敗，工具會自動以既有 commit hash 補做 push，絕不重複建立多餘的 commit。

---

## 相關文件

- [Git Commit Writer 使用手冊](/docs/skills/git-commit-writer.md)
- [Doc Updater 使用手冊](/docs/skills/doc-updater.md)
- [OpenSpec Commit 工作流程架構](/docs/workflow/commit.md)
- [本機開發四階段流程 — 04 封存與交付](/docs/workflow/local-development.md#04-封存與交付)

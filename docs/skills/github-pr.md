---
type: Playbook
title: GitHub PR 操作指南
description: 使用 github-pr 技能建立 Draft PR、更新說明、回覆審查留言或關閉 PR。
tags: [skills, github, pr, handoff]
timestamp: 2026-11-14T00:00:00+08:00
---

# GitHub PR 操作指南

`github-pr` 是管理 GitHub Pull Request 生命週期的薄封裝工具。它負責建立 Draft PR、更新 PR 說明內容、發布 Review 審查與修復回覆，以及在不 merge 的情況下正常關閉 PR。

所有 PR 格式、欄位與標籤嚴格遵循 [GitHub 交接契約](/docs/github-handoff.md)。

---

## 支援的操作

```text
               ┌────────────────────────┐
               │       github-pr        │
               └───┬───┬────────┬───┬───┘
                   │   │        │   │
        ┌──────────┘   │        │   └──────────┐
        ▼              ▼        ▼              ▼
    [create]       [update]  [reply]        [close]
  檢查/commit/push  更新 PR   回覆審查/修正   發布結案留言
  建立 Draft PR     本文說明  發表 Checkpoint  關閉 PR (不 merge)
  (唯一會寫 Git)
```

| 操作 | 觸發需求 | 授權後的行為 |
|---|---|---|
| **create** | 欲開立的分支變更與相關素材 | 執行必要檢查 → 建立限定範圍的 commit → 正常 push → **開立 Draft PR**（或沿用已存在的 PR） |
| **update** | PR 網址或編號、欲更新內容 | 重新編修並更新 PR 正文的說明區塊 |
| **reply** | PR 網址或編號、留言內容 | 在 PR 發表頂層留言（如：Review 結論、修正回報、Checkpoint、設計批准） |
| **close** | PR 網址或編號、關閉原因 | 先發布 Closure 結案摘要留言並回讀確認，再將 PR 關閉（**不進行 merge**） |

> [!IMPORTANT]
> **只有 `create` 會執行 Git 操作**（commit 與 push）。其餘的 `update`、`reply` 與 `close` 均只操作 GitHub PR 留言與狀態，絕不會擅自變更 Git 分支或推送程式碼。

---

## 新人 Step-by-Step 使用教學

### 步驟 1：實作完成後發布 Draft PR (`create`)

當你在本機分支實作完畢並通過測試，決定發布到遠端讓團隊或 Agent 審查時：

1. **直接對 Agent 說**：
   ```text
   幫我開一個 Draft PR
   ```
   或指定 Change：
   ```text
   將這個 change 發布為 Draft PR
   ```
2. **工具執行動作**：
   - 檢查目前分支與變更。
   - 產生只涵蓋本次工作的 Git commit 並正常 push 至遠端分支。
   - 開立 **Draft PR**（預設為草稿狀態，避免誤觸 CI 自動部署或提早合併）。
   - 回讀並提供 PR 連結（例如 `#21`）。

### 步驟 2：更新 PR 描述內容 (`update`)

當規格有重大調整，需要同步更新 PR 正文的背景、目標或驗收項目時：

1. **直接對 Agent 說**：
   ```text
   更新 PR #21 的說明，補充第三點驗收條件
   ```
2. **工具執行動作**：
   - 更新 PR 正文（Description），保持格式符合交接契約。

### 步驟 3：回覆 Review 審查或回報修正 (`reply`)

當收到審查意見並完成修正，或需要記錄進度 Checkpoint 時：

1. **直接對 Agent 說**：
   ```text
   回覆 PR #21：已修正審查提出的型別錯誤，測試全數通過
   ```
2. **工具執行動作**：
   - 格式化回覆內容（包含修改項目、測試依據與最新 commit SHA）。
   - 以頂層留言（top-level comment）發布至 PR，方便審查者複查。

### 步驟 4：工作被取代或取消時關閉 PR (`close`)

如果某項工作決定放棄、改用其他架構，或分支已不再需要時：

1. **直接對 Agent 說**：
   ```text
   關閉 PR #21，原因：改用新版架構，此實作作廢
   ```
2. **工具執行動作**：
   - 發表 Closure 摘要留言，詳細記錄關閉原因。
   - 關閉 PR（**絕不執行 merge**）。
   - 關聯的 Issue 保持原狀，由開發者或專門流程獨立決定是否結案。

---

## 核心設計原則

1. **Draft PR 優先**：建立時一律為 Draft PR，確保所有人在正式審查通過前都不會誤 merge。
2. **審查與修正回讀**：每一次 review 與 repair 均透過 `reply` 留下結構化紀錄，讓接手者能跨 Session 銜接。
3. **權限嚴格控管**：絕不自動 merge、絕不 force push。

---

## 相關文件

- [GitHub Issue 操作指南](/docs/skills/github-issue.md)
- [Change Review 審查指南](/docs/skills/change-review.md)
- [GitHub 交接契約](/docs/github-handoff.md)
- [本機開發四階段流程](/docs/workflow/local-development.md)

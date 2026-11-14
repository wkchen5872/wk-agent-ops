---
type: Playbook
title: GitHub Issue 操作指南
description: 使用 github-issue 技能建立、更新或關閉 GitHub Issue 來追蹤工作。
tags: [skills, github, issue, handoff]
timestamp: 2026-11-14T00:00:00+08:00
---

# GitHub Issue 操作指南

`github-issue` 是將本機工作（Work Item、OpenSpec Change、分支或當前對話）登錄至 GitHub 的薄封裝工具。它的目的是讓只看 GitHub 的其他協作者或 Agent 能一眼看懂問題背景、驗收標準與下一步進度。

格式與欄位規則嚴格遵循 [GitHub 交接契約](/docs/github-handoff.md)。

---

## 支援的操作

```text
       ┌───────────────┐
       │ github-issue  │
       └───┬───┬───┬───┘
           │   │   │
  ┌────────┘   │   └────────┐
  ▼            ▼            ▼
[create]    [update]     [close]
建立 Issue   發表進度留言  結案並關閉 Issue
```

| 操作 | 觸發需求 | 授權後的行為 |
|---|---|---|
| **create** | 來源（Work Item、Change、分支或 Session 討論）、指定儲存庫 | 建立一筆結構化 Issue（若已有對應 Issue 則直接沿用回報） |
| **update** | 目標 Issue（編號或網址）、進度說明 | 在該 Issue 新增一則進度或 Checkpoint 留言（**絕不改寫主文**） |
| **close** | 目標 Issue、結案原因（已完成或取消） | 先發表 Closure 結案摘要留言並回讀確認，再將 Issue 標記為 completed 或 not planned 關閉 |

> [!NOTE]
> `github-issue` 永遠不會修改 Git 分支、不產生 commit、不推送 remote，也不會修改既有的 PR。

---

## 新人 Step-by-Step 使用教學

### 情境 1：將目前的工作建立為 GitHub Issue (`create`)

當你在本機討論完需求或完成規格開立，希望在 GitHub 開立 Issue 追蹤時：

1. **直接對 Agent 說**：
   ```text
   幫我建立 issue
   ```
   或指定關聯的 Change：
   ```text
   用 change <change-id> 建立 GitHub issue
   ```
2. **工具執行動作**：
   - 確認 GitHub 連線與目標 repository（如 `owner/repo`）。
   - 檢查是否已經存在同一筆工作的 Issue。
   - 產出包含：`## Handoff`（問題背景）、`## Goal`（目標）、`## Acceptance criteria`（驗收標準）、`## Next actions`（下一步）與 `## Author` 的標準主文。
   - 建立完成後回讀並回報 Issue 網址（例如 `#15`）。

### 情境 2：回報工作進度或回覆 Issue (`update`)

當你完成了一個階段，想在 Issue 留下進度記錄時：

1. **直接對 Agent 說**：
   ```text
   更新 issue #15 的進度：已完成單元測試，準備進入 review
   ```
2. **工具執行動作**：
   - 找到 `#15` Issue。
   - 以留言形式新增進度或 Checkpoint 摘要。
   - 保持 Issue 原本文本不動，歷史歷程完全可追溯。

### 情境 3：完成驗收，關閉 Issue (`close`)

當工作全部完成且通過驗收，或是該工作決定取消時：

1. **直接對 Agent 說**：
   ```text
   驗收完成，幫我關閉 issue #15
   ```
   或如果是放棄該需求：
   ```text
   關閉 issue #15，原因：此需求已被其他架構取代 (not planned)
   ```
2. **工具執行動作**：
   - 整理 Closure 結案摘要（包含完成項目、成果鏈結或取消原因）。
   - 發布結案留言並回讀確認無誤。
   - 執行關閉該 Issue。

---

## 核心設計原則

1. **不覆寫主文**：Issue 建立後的任何進展或討論，一律以留言（comment）追蹤，保留完整時間軸。
2. **獨立結案**：關閉 Issue 只處理該 Issue 本身，不會擅自關閉或合併關聯的 PR。
3. **無本機依賴**：GitHub 是對外公開的單一事實來源，協作者不需要取得你的本機臨時對話或 Work Item 也能看懂。

---

## 相關文件

- [GitHub PR 操作指南](/docs/skills/github-pr.md)
- [GitHub 交接契約](/docs/github-handoff.md)
- [本機開發四階段流程](/docs/workflow/local-development.md)

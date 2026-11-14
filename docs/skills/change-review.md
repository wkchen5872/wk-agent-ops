---
type: Playbook
title: Change Review 審查指南
description: 使用 change-review 技能對 Change、Issue 或 PR 執行一輪代碼審查與驗收。
tags: [skills, review, openspec, quality]
timestamp: 2026-11-14T00:00:00+08:00
---

# Change Review 審查指南

`change-review` 是一個標準化的代碼審查與驗收工具。它可以針對一個 OpenSpec Change 名稱、GitHub Issue 或 PR，執行單一輪次的完整檢核（包含規格驗證、代碼品質審查與專案測試），並給出結構化的審查結論。

詳細流程可參考架構圖：[SVG 原稿](/docs/diagrams/change-review-workflow.svg)。

---

## 審查流程圖

```text
               ┌────────────────────────┐
               │   呼叫 change-review   │
               └───────────┬────────────┘
                           │
                           ▼
                  鎖定受審版本 (Commit SHA)
                           │
                           ▼
                  執行自動化驗證與檢查
                  ├─ openspec-verify-change
                  ├─ 專案測試 (test suites)
                  └─ 代碼品質與規範檢查
                           │
                           ▼
                      做出審查結論
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
          [pass]   [changes-required] [blocked]
         通過驗收       需要修正      證據不足/受阻
             │             │             │
             └─────────────┬─────────────┘
                           ▼
                      回報審查結果
             ┌─────────────┴─────────────┐
             ▼                           ▼
       [已確認有 PR]                [無 PR / 本地模式]
   透過 github-pr reply         產出本機審查報告
   發布留言並回讀確認           保存指紋紀錄並交接
```

---

## 審查結論與後續動作

| 審查結論 | 意義 | 後續動作 |
|---|---|---|
| **`pass`** | 規格驗收全數符合，測試 100% 通過，無重大缺陷 | 進入封存與交付階段（可呼叫 [`openspec-commit`](/docs/skills/openspec-commit.md)） |
| **`changes-required`** | 發現功能 Bug、測試失敗或代碼不符規範 | 列出明確修正項目，交回實作者修正；修正完成後啟動新一輪複審 |
| **`blocked`** | 缺少必要前置條件、環境不全或無法執行測試 | 暫停審查，待補齊前置環境或資訊後再重試 |

---

## 新人 Step-by-Step 使用教學

### 步驟 1：發起審查

你可以透過 Change 名稱、PR 或 Issue 發起審查：

- **以 PR 為目標審查**：
  ```text
  review PR #21
  ```
- **以 OpenSpec Change 為目標審查**：
  ```text
  幫我驗收 add-user-auth
  ```
- **單純在本地審查（不發布至 GitHub）**：
  ```text
  本地審查當前的變更，不要發布到 PR
  ```

### 步驟 2：檢視審查過程與產出

工具會自動依序執行：
1. **鎖定 Commit**：固定受審的精確 HEAD commit SHA，避免審查期間代碼被變更干擾。
2. **驗證規格**：呼叫 `openspec-verify-change` 比對實作是否完全滿足 `specs/` 宣告。
3. **執行測試**：執行專案所屬的單元測試與整合測試。
4. **格式化輸出**：整理出包含「範圍」、「發現事項（Findings）」與「總結與限制」的報告。

### 步驟 3：後續處置

- **若為 `pass`**：你可以直接進入下一階段，執行封存與交付。
- **若為 `changes-required`**：
  - 根據報告中的清單進行代碼修正。
  - 修正並 commit 後，再次呼叫 `review PR #21` 進行複審。
  - 審查者會自動比對新舊版本差異，確認修正項目已解決。

---

## 核心設計原則

1. **版本精確綁定**：舊版本的 pass 不會自動套用到新 commit；代碼一有更動就必須重新核驗新 HEAD。
2. **審查不改代碼**：`change-review` 只負責審查與回報結論，絕不直接動手修改產品代碼或執行 merge。
3. **本地與遠端雙軌支援**：即使專案尚未建立 PR 或是在離線環境，也能產出完整的本地驗收報告。

---

## 相關文件

- [GitHub PR 操作指南](/docs/skills/github-pr.md)
- [OpenSpec Commit 操作指南](/docs/skills/openspec-commit.md)
- [本機開發四階段流程 — 03 Review 與修正交接](/docs/workflow/local-development.md#03-review-與修正交接)

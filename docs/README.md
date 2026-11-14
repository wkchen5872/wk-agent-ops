---
type: Reference
title: wk-agent-ops 文件導覽首頁
description: wk-agent-ops 專案文件導航、功能目錄索引與新人起步手冊。
tags: [docs, index, navigation, getting-started]
timestamp: 2026-11-14T00:00:00+08:00
---

# 📚 wk-agent-ops 文件中心

> **專案核心使命**：`wk-agent-ops` 是一個集中開發、管理與維護 AI Agent 擴充套件（Skills, Rules, Workflows, Git Hooks）的中央倉儲。透過安裝腳本，將標準化的 Agent 配置無縫部署到團隊的其他開發專案中，確保跨專案的 Agent 行為具備高度一致性與自動化能力。

本目錄（`docs/`）是提供給人類工程師與協作者閱讀的文件庫。所有指南均以**新人能 Step by Step 照著做**為原則撰寫。

---

## 🗺️ 功能目錄全景圖

```text
docs/
├── README.md               ← [你目前的位置] 新人導覽與全局索引
│
├── 📂 workflow/            ← 開發與協作工作流程
│   ├── local-development.md← 本機開發四階段流程（開立規格 → 實作 → 審查 → 交付）
│   ├── commit.md           ← OpenSpec Commit 協調流程與遠端交付
│   ├── concepts.md         ← OpenSpec、Git 與 Session 責任邊界
│   ├── guide.md            ← PM/RD 多 Agent 協作全貌指南
│   ├── wt-work-flow.md     ← Worktree 與分支解析流程
│   └── provider-worktrees.md← 各 AI 工具原生 Worktree 行為比較
│
├── 📂 skills/              ← 擴充工具與自動化技能手冊
│   ├── github-issue.md     ← 建立、更新與關閉 GitHub Issue
│   ├── github-pr.md        ← 開立 Draft PR、更新說明、回覆審查與結案
│   ├── change-review.md    ← 發起代碼審查、三種結論判定與報告產出
│   ├── openspec-commit.md  ← 一鍵串接封存、文件更新、commit 與遠端交付
│   ├── git-commit-writer.md← 依 diff 自動產生 Conventional Commit
│   ├── doc-updater.md      ← 自動同步更新 docs/、README 與 AGENTS 文件
│   ├── bulk-read-routing.md← 廣泛未知檔案搜尋評估
│   └── template-profiles.md← 範本 Profile 分類與 install.sh 用法
│
├── 📂 hooks/               ← Provider 生命週期整合與鉤子設定
│   ├── index.md            ← 支援矩陣與鉤子總覽
│   ├── claude-hooks.md     ← Claude Code Hook 整合
│   ├── codex-hooks.md      ← Codex Hook 信任與雙階段啟用
│   ├── antigravity-hooks.md← Antigravity Hook 與狀態列整合
│   └── copilot-hooks.md    ← GitHub Copilot CLI 專案級 Hook
│
├── 📂 notify/              ← 自動化通知系統
│   ├── architecture.md     ← 通知系統架構與 Hook 資料流
│   └── telegram.md         ← Telegram Bot 通知精靈快速設定
│
├── 📂 diagrams/            ← 高解析度流程圖與 SVG 原稿
│   └── README.md           ← 圖稿清單、閱讀順序與維護原則
│
└── 📋 專案核心契約與規範
    ├── agent-protocol.md   ← 跨工具 Agent 操作契約（Managed）
    ├── architecture.md     ← 專案模組架構與 Template 分發原則（Seed）
    ├── conventions.md      ← Bash 與腳本編寫慣例（Seed）
    ├── github-handoff.md   ← GitHub Issue/PR 交接契約（Managed）
    ├── okf-conventions.md  ← OKF v0.2 文件與圖稿撰寫規範（Managed）
    ├── openspec-workflow.md← OpenSpec 規格驅動開發流程（Managed）
    └── mutation-testing.md ← 變異測試（Mutation Testing）操作指引（Managed）
```

---

## 🚀 新人第一天起步指南（Getting Started）

如果你是剛加入此專案的新人，建議依序閱讀以下關鍵章節：

### 第一步：理解專案如何分發（3 分鐘）
閱讀 [專案架構指南](architecture.md)，了解 `template/` 是唯一的原始碼真理，透過 `scripts/skills/install.sh` 分發至 `.claude/`、`.agents/` 以及其他專案。**切勿直接手動編輯安裝目錄下的檔案**。

### 第二步：熟悉日常開發的四個階段（5 分鐘）
閱讀 [本機開發四階段流程](workflow/local-development.md)：
1. **01 開立規格**：使用 `openspec-ff-change` 快速產出規格與任務。
2. **02 實作與驗證**：使用 `openspec-apply-change` 循序實作並執行 TDD 測試。
3. **03 審查與驗收**：使用 `change-review` 執行嚴格檢驗，取得 `pass` 結論。
4. **04 封存與交付**：使用 `openspec-commit` 一鍵完成封存、文件同步並產生 commit。

### 第三步：查閱常用 Skills 工具箱（按需查閱）
- 想手動提交代碼？閱讀 [Git Commit Writer](skills/git-commit-writer.md)。
- 代碼改動需要更新文件？閱讀 [Doc Updater](skills/doc-updater.md)。
- 需要在 GitHub 開立或回覆 Issue？閱讀 [GitHub Issue 操作指南](skills/github-issue.md)。
- 需要發布 Draft PR 或回覆 Review？閱讀 [GitHub PR 操作指南](skills/github-pr.md)。
- 準備收尾並交付？閱讀 [OpenSpec Commit 操作指南](skills/openspec-commit.md)。

---

## 🎨 圖表與視覺表達規範

為確保所有人在終端機、瀏覽器與手機端都能輕鬆理解架構，本專案嚴格遵循以下規範：
- **簡易流程與狀態分支**：直接在 Markdown 中以清晰的 **ASCII 方塊圖** 呈現。
- **全局架構與跨模組流程**：繪製為標準 **SVG 向量圖** 存放於 `docs/diagrams/`，並附帶 PNG 預覽供快速開啟。
- **嚴禁 Mermaid**：不使用語法脆弱且在不同 Markdown 渲染器易破版的 Mermaid 語法。

---

## 🤝 尋求協助與維護原則

- 當新增或修改工具技能時，請同步在 `docs/skills/` 撰寫繁體中文手冊。
- 文件應面向人類工程師，避免堆砌 AI 專用的詠唱邊界與內部提示詞。

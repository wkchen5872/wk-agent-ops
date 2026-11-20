---
type: Reference
title: 架構與流程圖索引
description: 現行開發、Review 與 GitHub 協作圖稿的閱讀順序、來源與維護位置；圖稿只保留 SVG。
tags: [architecture, workflow, diagrams]
generated: { by: codex/GPT-5, at: 2026-11-19T19:49:03+08:00 }
sources:
  - id: review-source
    resource: /template/common/skills/change-review/SKILL.md
    title: Change Review
  - id: commit-source
    resource: /template/common/skills/openspec-commit/SKILL.md
    title: OpenSpec Commit
  - id: delivery-design
    resource: /openspec/changes/archive/2026-11-14-extend-openspec-commit-delivery/design.md
    title: Commit 交付擴充設計
---

# 架構與流程圖索引

先讀 [專案架構](../architecture.md) 了解 template 分發與責任邊界，再看開發全貌。
需要操作某個階段時，沿下表進入該文件。Issue、PR 與 Review 的發布格式由 `github-issue`、
`github-pr` 與 `change-review` Skill 持有；各階段在哪些時點接上 GitHub 見
[GitHub 協作整合](../github-handoff.md)。圖稿只保留 SVG，不另存 PNG。

## 現行圖稿

| 圖稿 | 說明與用途 | 來源與維護位置 |
| --- | --- | --- |
| Skills 與 GitHub 協作架構：[SVG](skill-workflow-architecture.svg) | 個人流程按需呼叫自足 Skills；區分 Git 版本、GitHub 協作紀錄、Session 通知及測試題庫 | 本 repo 的 `docs/`；依 `separate-github-contract-from-workflow` 已核定設計完成實作並封存 |
| 開發與交付全貌：[SVG](development-lifecycle.svg) | [多 Agent 工作流](../workflow/guide.md)；探索、規劃、checkout、實作、人工發布檢核、Review、交付與獨立 Git 整合 | 本 repo 的 `docs/`；各階段細節由下列文件管理 |
| 01 開立規格：[SVG](local-development-define.svg) | [本機四階段](../workflow/local-development.md#01-開立規格)；Issue-first（接手既有 Issue）與 Change-first 兩個入口，先分支再建立或沿用 Change，人工確認；既有 Issue 不重開，設計 PR 選用 | 本 repo 的 `docs/`；不新增前兩階段整合 Skill |
| 02 實作與發布：[SVG](local-development-implement.svg) | [本機四階段](../workflow/local-development.md#02-實作與發布)；發布前人工檢核，可留在本地 Review | 本 repo 的 `docs/` |
| 03 Review：[SVG](local-development-review.svg) | [本機四階段](../workflow/local-development.md#03-review-與修正交接)；三種結論與修正重入 | 依現行 `change-review`；本地報告、明確交接與後補 PR 的版本核對以該 Skill 為準[^review-source] |
| 04 封存與交付：[SVG](local-development-finish.svg) | [Commit 工作流](../workflow/commit.md)；本地完成、成功交付、取消／被取代三分支 | 本版本 Skill 已實作並完成本地驗證；真實遠端發布仍待端到端驗收，新 head 要有相符 pass[^delivery-design] |
| 一輪 Review 詳細流程：[SVG](change-review-workflow.svg) | 已確認 PR 的三種結論都 reply 並回讀；無 PR、PR 不明或 local-only 只在本地回報；符合資格才核對原實作者並通知 | 原稿為 [review-loop.svg](../../template/common/skills/change-review/references/review-loop.svg)；更新來源後同步本圖，再由 installer 更新 Skill 副本[^review-source] |
| 交接迴圈：[SVG](agent-handoff-loop.svg) | [交接迴圈手冊](../skills/agent-handoff.md)；實作者、Stop hook、審查者三欄與收尾；支援 Xirp 與 Herdr 雙 host 訊息派送；審查 worktree shared／new、pass 後 ask／auto；具備進度通知與不可關閉停點保護 | 本 repo 的 `docs/`；依 `add-agent-handoff-loop`、`add-handoff-notifications` 與 `add-herdr-handoff-host` 實作 |
| 啟動交接迴圈：[SVG](agent-handoff-start.svg) | [啟動交接](../skills/agent-handoff.md#1-handoff-start-change-id-選項)；三份角色範本、`handoff-doctor` 預檢、`handoff-start` 選項、`handoff-role` 角色動態置換與舊角色退出，以及誰在何時開哪個 worktree 與 Session | 本 repo 的 `docs/`；依 `add-agent-handoff-loop`、`add-herdr-handoff-host` 與 `replace-open-handoff-roles` 實作 |
| 收尾與清理：[SVG](agent-handoff-cleanup.svg) | [交接迴圈收尾](../skills/agent-handoff.md#4-handoff-cleanup-change-id---abandon---yes)；三道安全防護、歷史證據歸檔（含 Work Items 與主 worktree 的 Pi 設定）、刪除 Xirp sessions、關閉 Herdr workspace/tab 再移除臨時 worktree、保留 feature 分支 | 本 repo 的 `docs/`；依 `scripts/handoff/handoff-cleanup` 實作 |
| 通知架構與延遲授權：[SVG](notify-architecture.svg) | [通知架構手冊](../notify/architecture.md)；Claude、Codex、Antigravity、Pi、Copilot 與交接事件接入、30 秒授權防誤報狀態機、範本替換引擎與 Telegram 派送 | 本 repo 的 `docs/`；依 `refine-notify-core`、`add-handoff-notifications` 與 `add-pi-notify-hook` 實作 |
| GitHub 協作整合（組合示例）：[SVG](github-handoff.svg) | [GitHub 協作整合](../github-handoff.md)；Issue-first／Change-first 兩個入口、版本審查、Closure 回讀及 Issue 獨立結案 | managed；修改 `template/common/docs/diagrams/github-handoff.svg`，再跑 installer |

本機四階段及開發全貌是本 repo 的操作文件，不隨 common installer 散布。
圖稿描述規範與目前檔案；能力的實作、驗收與發布狀態見各文件及對應 Change，不由圖稿存在推定。
本地 archive → docs → commit 的基線由 `openspec-commit` 管理。[^commit-source]

## Work Item 圖稿的正式落點

| 探索圖稿 | 正式承接方式 |
| --- | --- |
| `local-workflows/01-define`、`02-implement`、`03-review`、`04-finish` | 由上表四張 `local-development-*` SVG 與 `local-development.md` 承接；正式文件直接引用這些版本 |
| `team-collaboration` | 已確認的責任由專案架構、各 GitHub Skill 與 GitHub 協作整合圖承接；舊圖的「格式待收斂」不帶入現況 |
| `personal-workflow-proposal` | 候選順序已由四階段文件取代；保留探索用途，不另建第二套正式流程 |
| `team-personal-overview` | 共用契約與個人操作的分工由本索引連結的架構、團隊主圖及開發全貌共同說明；不沿用「候選四個封裝」的舊狀態 |

正式閱讀與操作不需要 Work Item；討論原圖可保留在本地，未搬移的草案不表示已批准或已實作。

## 歷史與其他模組

- 舊探索架構圖已由上表的 Skills 與 GitHub 協作架構圖取代；開發順序與審查分支以上表現行流程圖為準。
- [通知架構](../notify/architecture.md)、[Provider hooks](../hooks/index.md) 與 [Session／Git 概念](../workflow/concepts.md) 管理各自的圖文；本輪開發流程調整不改變其模組責任。
- 文字目錄樹及簡單狀態示意保留在所屬文件；複雜操作流程提供可直接開啟的 SVG。

[^review-source]: [Change Review 來源](../../template/common/skills/change-review/SKILL.md)，§5–7。
[^commit-source]: [OpenSpec Commit 來源](../../template/common/skills/openspec-commit/SKILL.md)，本地 archive → docs → commit。
[^delivery-design]: [Commit 交付擴充設計](../../openspec/changes/archive/2026-11-14-extend-openspec-commit-delivery/design.md)，Decisions 1–6。當時的本地驗證紀錄已不在 repo 中；Review 與驗證紀錄只保存在 Work Item 或 GitHub PR。

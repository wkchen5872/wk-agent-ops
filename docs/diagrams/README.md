---
type: Reference
title: 架構與流程圖索引
description: 現行開發、Review、GitHub 交接及 Worktree 圖稿的閱讀順序、來源與維護位置。
tags: [architecture, workflow, diagrams]
generated: { by: codex/GPT-6, at: 2026-11-14T12:41:58+08:00 }
sources:
  - id: review-source
    resource: /template/common/skills/change-review/SKILL.md
    title: Change Review
  - id: commit-source
    resource: /template/common/skills/openspec-commit/SKILL.md
    title: OpenSpec Commit
  - id: runtime-source
    resource: /scripts/workflow/runtime.sh
    title: Worktree runtime
  - id: delivery-design
    resource: /openspec/changes/extend-openspec-commit-delivery/design.md
    title: Commit 交付擴充設計
---

# 架構與流程圖索引

先讀 [專案架構](../architecture.md) 了解 template 分發與責任邊界，再看開發全貌。
需要操作某個階段時，沿下表進入該文件；Issue、PR 與 Review 發布格式的唯一契約是
[GitHub 交接契約](../github-handoff.md)。

## 現行圖稿

| 圖稿 | 說明與用途 | 來源與維護位置 |
| --- | --- | --- |
| 開發與交付全貌：[SVG](development-lifecycle.svg)／[PNG](development-lifecycle.png) | [多 Agent 工作流](../workflow/guide.md)；探索、規劃、checkout、實作、人工發布檢核、Review、交付與獨立 Git 整合 | 本 repo 的 `docs/`；各階段細節由下列文件管理 |
| 01 開立規格：[SVG](local-development-define.svg)／[PNG](local-development-define.png) | [本機四階段](../workflow/local-development.md#01-開立規格)；先分支再 Change，人工確認，Issue／設計 PR 選用 | 本 repo 的 `docs/`；不新增前兩階段整合 Skill |
| 02 實作與發布：[SVG](local-development-implement.svg)／[PNG](local-development-implement.png) | [本機四階段](../workflow/local-development.md#02-實作與發布)；發布前人工檢核，可留在本地 Review | 本 repo 的 `docs/` |
| 03 Review：[SVG](local-development-review.svg)／[PNG](local-development-review.png) | [本機四階段](../workflow/local-development.md#03-review-與修正交接)；三種結論與修正重入 | 依現行 `change-review`，不包含尚在規劃的本地通知優化[^review-source] |
| 04 封存與交付：[SVG](local-development-finish.svg)／[PNG](local-development-finish.png) | [Commit 工作流](../workflow/commit.md)；本地完成、成功交付、取消／被取代三分支 | 已確認的交付擴充設計；遠端能力須搭配對應 Skill 實作，新 head 要有相符 pass[^delivery-design] |
| 一輪 Review 詳細流程：[SVG](change-review-workflow.svg) | 已確認 PR 的三種結論都 reply 並回讀；無 PR、PR 不明或 local-only 只在本地回報；符合資格才核對原實作者並通知 | 原稿為 [review-loop.svg](../../template/common/skills/change-review/references/review-loop.svg)；更新來源後同步本圖，再由 installer 更新 Skill 副本[^review-source] |
| 團隊 GitHub 交接：[SVG](github-handoff.svg) | [交接契約](../github-handoff.md)；設計批准、版本審查、Closure 回讀、結案再核對及 Issue 獨立結案 | managed；修改 `template/common/docs/diagrams/github-handoff.svg`，再跑 installer |
| Worktree 解析：[SVG](wt-work-resolution.svg)／[PNG](wt-work-resolution.png) | [wt-work 解析](../workflow/wt-work-flow.md)；明確 path → project path → named → detached，無候選才建立 | 以 runtime／launcher 為準；固定 planning SHA 的人工核對與當前 branch tip 的腳本檢查分開[^runtime-source] |

本機四階段及開發全貌是本 repo 的操作文件，不隨 common installer 散布。
圖稿描述規範與目前檔案；能力的實作、驗收與發布狀態見各文件及對應 Change，不由圖稿存在推定。
本地 archive → docs → commit 的基線由 `openspec-commit` 管理。[^commit-source]

## Work Item 圖稿的正式落點

| 探索圖稿 | 正式承接方式 |
| --- | --- |
| `local-workflows/01-define`、`02-implement`、`03-review`、`04-finish` | 由上表四張 `local-development-*` SVG／PNG 與 `local-development.md` 承接；正式文件直接引用這些版本 |
| `team-collaboration` | 已確認的責任由專案架構與 GitHub 交接契約／主圖承接；舊圖的「格式待收斂」不帶入現況 |
| `personal-workflow-proposal` | 候選順序已由四階段文件取代；保留探索用途，不另建第二套正式流程 |
| `team-personal-overview` | 共用契約與個人操作的分工由本索引連結的架構、團隊主圖及開發全貌共同說明；不沿用「候選四個封裝」的舊狀態 |

正式閱讀與操作不需要 Work Item；討論原圖可保留在本地，未搬移的草案不表示已批准或已實作。

## 歷史與其他模組

- [GitHub 交接歷史圖稿](github-change-handoff/README.md) 保留三張探索圖；其中的舊 `publish`、Ready 與待制定規範屬當時設計，不作為現行入口。
- [通知架構](../notify/architecture.md)、[Provider hooks](../hooks/index.md) 與 [Session／Git 概念](../workflow/concepts.md) 管理各自的圖文；本輪開發流程調整不改變其模組責任。
- 文字目錄樹及簡單狀態示意保留在所屬文件；複雜操作流程提供可直接開啟的 SVG。

[^review-source]: [Change Review 來源](../../template/common/skills/change-review/SKILL.md)，§5–7。
[^commit-source]: [OpenSpec Commit 來源](../../template/common/skills/openspec-commit/SKILL.md)，本地 archive → docs → commit。
[^runtime-source]: [runtime.sh](../../scripts/workflow/runtime.sh)，`workflow_check_candidate`、`workflow_resolve_worktree`；[wt-work.sh](../../scripts/workflow/wt-work.sh) 管理建立流程。
[^delivery-design]: [Commit 交付擴充設計](../../openspec/changes/extend-openspec-commit-delivery/design.md)，Decisions 1–6；實作另行交付。

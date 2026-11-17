---
type: Reference
title: GitHub 協作整合
description: 個人開發流程的四個階段在哪些時點接上 GitHub Issue／PR、呼叫哪個 Skill 的哪個操作、交接什麼資訊；貼文格式與寫入規則由各 Skill 持有。
tags: [agents, github, workflow, openspec]
generated: { by: claude-code/Claude Opus 5.5, at: 2026-11-14T23:51:02+08:00 }
---

<!-- Managed by wk-agent-ops · do not edit here — re-running install.sh overwrites this file. -->

# GitHub 協作整合

本文件說明個人開發流程如何接上 GitHub 協作：每個階段在什麼時點用到 Issue 或 PR、呼叫哪個
Skill 的哪個操作、交出與取回什麼資訊。

它不是貼文格式的規範。Issue／PR 的格式、Author、寫入前核對與回讀都在各 Skill 內，執行
Skill 時不需要先讀本文件。是否可以進到下一階段（例如開始實作），由
[OpenSpec Workflow](openspec-workflow.md) 決定。

GitHub 協作是選用的：沒有 Issue 或 PR，四個階段一樣能在本機完成。

## 入口對照

| Skill | 負責 | 操作 | 安裝位置 |
| --- | --- | --- | --- |
| `github-issue` | Issue 的建立、進度留言、Checkpoint 與結案 | create、update、close | `.claude/skills/github-issue/SKILL.md`、`.agents/skills/github-issue/SKILL.md` |
| `github-pr` | PR 的建立（含必要的檢查、commit 與 push）、說明更新、審查／修正／交接／結案回覆、不合併的關閉、批准紀錄 | create、update、reply、close | `.claude/skills/github-pr/SKILL.md`、`.agents/skills/github-pr/SKILL.md` |
| `change-review` | 一輪審查與驗收；有 PR 時經 `github-pr reply` 發布，沒有時保存本地報告 | 依目標與目的 | `.claude/skills/change-review/SKILL.md`、`.agents/skills/change-review/SKILL.md` |
| `openspec-commit` | 封存、文件更新與 commit；獲授權時經 `github-pr` 交付或關閉 | 依交付意圖 | `.claude/skills/openspec-commit/SKILL.md`、`.agents/skills/openspec-commit/SKILL.md` |

不會自動載入 Skill 的工具，直接開啟上表的 `SKILL.md`。既有專案的 `AGENTS.md` 若仍寫著
「操作 Issue／PR 前先讀本文件」，讀完本節後依對應 Skill 執行即可。

## 各階段的觸點

[流程圖](diagrams/github-handoff.svg) 是搭配 OpenSpec 流程時的一種組合示例，不是必要流程。

### 01 開立規格

有兩個入口，規劃確認後都交給實作，產出相同：Change、branch、已確認的範圍與實作授權；有
Issue 時再加上 Issue URL。

| | Issue-first | Change-first |
| --- | --- | --- |
| 起點 | 同仁或自己已開了 Issue | 需求已能在本機描述 |
| GitHub 觸點 | 讀取既有 Issue；使用者要求時以 `github-issue update` 新增留言，記下 Change 與 branch | 需要追蹤時以 `github-issue create` 建立；已有同一件工作的 Issue 就沿用 |
| 帶入 | Issue URL、問題與影響、驗收資訊、未決事項 | 已確認的範圍與決策 |
| 產出 | Change 與 branch；proposal 引用該 Issue | Change 與 branch；有 Issue 時加上 Issue URL |
| 不做 | 不另開新 Issue，不改寫他人的 Issue 正文；Issue 缺少驗收資訊時列為規劃中的未決事項，不自行補上 | 不為了補欄位而建立 Issue |

團隊要求遠端設計審查時，可以先以 `github-pr create` 發布只有設計的 Draft PR，實作時沿用同一
張 PR。

### 02 實作與發布

| 時點 | 操作 | 帶入 | 取回 |
| --- | --- | --- | --- |
| 使用者決定發布實作 | `github-pr create`（含必要的檢查、commit、push 與 Draft PR）；同一件工作已有 PR 時，另行 push 後以 `github-pr update` 說明新版本 | Change、branch、Issue、驗證結果 | PR URL、已發布的 head |
| 暫停、換人或換機器 | `github-issue update` 或 `github-pr reply` 發布 Checkpoint | 目前狀態與已發布版本 | 留言 URL |

不發布時，直接以本機版本進入 Review。

### 03 Review 與修正交接

| 情況 | 操作 | 帶入 | 取回 |
| --- | --- | --- | --- |
| 已確認 PR | `change-review` 以 `github-pr reply` 發布任何結論（含 pass）並回讀；需要修正時通知可核對的實作者 | Change、Issue 或 PR | 審查回覆 URL、Finding ID |
| 沒有 PR、查找不明或 local-only | `change-review` 回傳並保存本地報告，不寫 GitHub | Change 或本機版本 | 本地報告與內容指紋 |
| 修正之後 | 實作者 push 後以 `github-pr reply` 逐項回覆，再由 Reviewer 對新 head 複審 | 修正 commit 與驗證結果 | 修正回覆 URL |

交接迴圈（`agent-handoff` Skill 的交件單）只在單一機器上的個人流程中運作；跨人的實作與審核以 PR 為交接媒介，
不延伸交件單。迴圈預設不 push、不開 PR，交給團隊時才以 `github-pr create` 開 PR。

使用交接迴圈時，Review 結束改寫 review 交件單，由 Stop hook 交接；
發布未確認時交件單為 blocked，不轉為本地交接。PR 回覆可委派 `github-pr-agent`，Author 仍是審查者。

### 04 封存與交付

| 交付意圖 | 操作 |
| --- | --- |
| 本地完成 | `openspec-commit`：archive、文件更新、commit；不寫 GitHub |
| 成功交付（獲授權） | push → `github-pr update` → 對最終 head 審查（`change-review`）→ `github-pr reply` 發布準備合併的 Closure；merge 另依授權 |
| 取消或被取代（獲授權） | `github-pr close`：先發布並回讀 Closure，再只關閉該 PR，不合併 |
| Issue 結案 | `github-issue close`：依原範圍驗收後另行處理，不跟著 PR 一起關閉 |

使用交接迴圈時，`openspec-commit` 依 `finish.delivery` 決定是否走成功交付；最終版 Review 審交付後的 head，
迴圈中較早的 pass 不能代替。`github-pr update` 與 Closure 可委派 `github-pr-agent`，Author 仍是收尾 Session。

## 不在本文件

| 內容 | 位置 |
| --- | --- |
| Issue／PR 的格式、Author、寫入前核對與回讀 | `github-issue`、`github-pr` 的 `SKILL.md` 與 `references/` |
| 審查識別、Finding 與報告範例 | `change-review` 的 `SKILL.md` 與 `references/` |
| 批准紀錄的格式、查找與版本核對 | `github-pr` 的 `references/approval-records.md` |
| 是否可以開始實作、各階段的授權與證據 | [OpenSpec Workflow](openspec-workflow.md) |
| 驗收案例與重播方法 | wk-agent-ops 來源 repo 的 `tests/acceptance/`，不隨安裝散布 |

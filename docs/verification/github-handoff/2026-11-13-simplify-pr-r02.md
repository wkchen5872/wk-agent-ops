---
type: Reference
title: simplify-github-pr 獨立 review 與遠端驗收 r02
description: 工作區實作審查、11 組測試、安裝同步、圖稿渲染，以及獨立 PR 的 create／update／reply／close 實測；發現取消 Issue 被標記 completed。
tags: [verification, github-handoff]
generated: { by: codex/GPT-6, at: 2026-11-13T21:40:03+08:00 }
sources:
  - id: change
    resource: /openspec/changes/simplify-github-pr/
    title: simplify-github-pr 工作區規劃
  - id: skill
    resource: /template/common/skills/github-pr/SKILL.md
    title: github-pr 工作區實作
  - id: live
    resource: https://github.com/wkchen5872/wk-agent-ops/pull/7
    title: 本輪獨立測試 PR
---

# simplify-github-pr review r02

## 範圍與版本

審查 `feature/simplify-github-pr` 尚未提交的工作區內容，涵蓋 github-pr、共用契約、change-review、Work Item 解耦、相關文件、案例、測試與安裝副本。假設使用情境是個人／小團隊的 Agent 協作；檢查了已知並行正文 writer 的處理規則，沒有做負載測試。

本輪只審查與測試，沒有修正實作、勾改 tasks、archive、commit 或 push 工作區。Review-ID：`codex-simplify-pr-r02`。發文工具 Codex，已知模型 GPT-6；未確認可公開的本輪 native Session ID，因此測試貼文使用 `SESSION-ID: null`。

來源指紋（SHA-256）：

| 來源 | SHA-256 |
| --- | --- |
| `template/common/skills/github-pr/SKILL.md` | `c0f204ca754cdb41e55f26d0f289e219e92563f0147f823d93ce6b37a8d6e1d2` |
| `template/common/docs/github-handoff.md` | `3c0da3a3df1c1cfcfc772b5884414beec05b4b8afec8a61f8efc33bce541bf51` |
| `template/common/skills/change-review/SKILL.md` | `4e090293e04575e5069084366c811fd836ef53e2acade4fad6075197bedb4904` |

## Verification scorecard

| 面向 | 結果 |
| --- | --- |
| Completeness | apply tracking 為 11/11 tasks 勾選；11 個 ADDED requirements 均找到實作指令與案例。沒有 REMOVED／RENAMED requirement。勾選不視為所有行為驗收通過。 |
| Correctness | 28 個 scenarios 均有指令／案例對應；close 實測發現 F-01。完整 scenarios 本輪未逐一重新生成／重播，不計為 28/28 行為通過。 |
| Coherence | 四操作、獨立 Git 發布、精簡正文、追加回覆、批准證據、Work Item 解耦與既有目錄模式一致；取消與完成原因的實際狀態有 F-01 落差。 |

需求對應：來源整合在 github-pr Shared Step 1；已發布版本在 Step 4 與 create Step 5；框架與 Author 在共用契約 §6.2／§7；create 防重與遠端差異在 Step 4／create；禁止 Git 發布在操作表與 Shared Step 2；正文保留在 update／契約 §11；審查及修正回覆在 reply；關閉範圍在 close；結果核對在 Shared Step 3／Reporting；審查與批准整合在 change-review Step 7、Approval events 與契約 §8–9。Work Item source 與 GitHub schema 的依賴已解除，測試亦有對應。

## Finding

### F-01 — P2 / Must fix：取消 Issue 卻存成 completed

狀態：Open。OpenSpec 分類：WARNING（close 語意與實際儲存結果不一致）。

- **位置**：`template/common/skills/github-pr/SKILL.md:315–319`，以及 `references/acceptance-cases.md` GP-50 等 close 案例。
- **問題**：close 明確支援 cancelled／superseded，且不應把關閉表示為工作完成，但範例命令只有 `gh issue close ... --comment`，沒有選擇關閉原因；回讀也只看 state。依此命令取消 Issue #8，REST 回讀得到 `state: closed, state_reason: completed`。
- **證據**：[Issue #8](https://github.com/wkchen5872/wk-agent-ops/issues/8) 的取消留言，以及本輪 `gh api --hostname github.com repos/wkchen5872/wk-agent-ops/issues/8` 回讀。對照獨立清理 Issue #9 時使用 `--reason 'not planned'`，回讀為 `not_planned`。
- **最小修正**：依有證據的原因選擇 Issue close reason：取消／被取代使用 `not planned`；確實已完成才使用 `completed`。MCP 路徑也需設定等價欄位；回讀核對 reason，補一個取消案例及相應測試，再由 installer 同步。
- **不修影響**：GitHub 將取消工作顯示為 completed，讓接手者及依關閉原因統計的報表誤判。留言說明無法改變平台儲存的原因。
- **完成條件**：取消情境實際讀回 `closed / not_planned`，直接 Issue 正確處理且依賴仍開啟；完成情境保留正確的 completed 原因。

## 本輪本機驗證

全部 11 組 `tests/test_*.sh` exit 0：`test_agents_dir`、`test_bulk_read_routing`、`test_change_review`、`test_documentation_authoring`、`test_github_handoff`、`test_mutation_skills`、`test_openspec_commit`、`test_portable_agents_md`、`test_tdd_enforcement`、`test_work_items`、`test_workflow`。

`openspec validate simplify-github-pr --strict` 與 `git diff --check` 通過。github-pr／change-review 的 template 全部檔案與 `.claude/skills`、`.agents/skills` 副本逐位元一致；managed github-handoff 文件、SVG 與 Work Item AGENTS 也一致。沒有直接編輯安裝副本。

兩張目前版本 SVG 經 `rsvg-convert` 渲染並實際查看 PNG：GitHub handoff 與 change-review review-loop，文字可讀，未見裁切或流程連線錯誤。搜尋現行 callers，剩餘 `github-pr publish` 都是移除說明或舊呼叫的拒絕案例。

測試腳本主要驗證契約文字、安裝與檔案結構；通過不代表自然語言 Agent 的全部決策或遠端行為已證實。r01 的生成與重播結果是既有實作證據，本輪沒有把它們當成重新執行。

## 本輪真實 GitHub 驗收

使用者授權對本 repo PR 測試；另建獨立 fixture，沒有操作原有 PR #6／Issue #5。

先以 GitHub API 建立遠端測試 branch `test/simplify-github-pr-20261113`，指向已發布的 `ee09415386d3790f000e503aa73818b46bab9790`。這是測試前置資料準備，不是 skill 自動發布，也沒有包含目前未提交的 PR skill 重構。Base 為 `feature/add-change-review-skill`（`6941aa2cb811902574c2dc8a481d1cf7301dd447`）；compare 回覆 ahead 1、29 files。

| 操作 | 真實結果 |
| --- | --- |
| create | 建立 [Draft PR #7](https://github.com/wkchen5872/wk-agent-ops/pull/7)，起初只有 branch，沒有空 Change／WI／Issue 欄位；回讀 base、head、SHA、Draft 與正文。 |
| 再次查找 | 該測試 head 只有唯一 PR #7；採用既有 PR，不再 create。這是候選查找驗證，沒有刻意呼叫 create 製造重複。 |
| update | 後補直接 Issue [#8](https://github.com/wkchen5872/wk-agent-ops/issues/8) 與 depends-on [#9](https://github.com/wkchen5872/wk-agent-ops/issues/9)。完整正文等於預期檔，Handoff 之外逐字保留。 |
| reply Review | [留言 6854555870](https://github.com/wkchen5872/wk-agent-ops/pull/7#issuecomment-6854555870)；限定回報已完成的操作，未宣稱尚未發布的重構已部署。 |
| reply Changes | [留言 6854558194](https://github.com/wkchen5872/wk-agent-ops/pull/7#issuecomment-6854558194)；如實說明後補關聯，沒有偽造 fix commit 或宣稱 finding resolved。兩則皆按實際 comment ID 回讀、核對 parent PR #7、repo、作者與完整內容；PR 正文未變。 |
| close | 先關閉 PR #7，再確認 `CLOSED / mergedAt: null`，然後關直接 Issue #8。依賴 #9 仍 OPEN；branch 保留且仍指向 ee09415。Issue #8 reason 錯誤，見 F-01。 |
| rerun | 再讀 PR #7 與 Issue #8 都已 closed，依規則不再寫入；前後留言 ID／數量相同。不是另一次 close 呼叫。 |
| fixture 清理 | 證明 #9 未被連動關閉後，以獨立清理操作 `gh issue close 9 --reason 'not planned' --comment ...` 關閉；讀回 `closed / not_planned`。 |

最終 #7 CLOSED 且未 merge、#8 CLOSED/completed（保留缺陷證據）、#9 CLOSED/not_planned（獨立清理）；測試 branch 保留，沒有刪分支。Author 為 Codex / GPT-6 / SESSION-ID null；GitHub 實際留言帳號為 wkchen5872。

## 結論與限制

Verdict：changes-required，先修 F-01 再驗收 close。其餘本輪實測的基本流程符合預期。

未實際製造 fork、GitHub Enterprise、多 writer 競寫、403、timeout／readback failure 或多 Issue 部分失敗；這些只有指令、靜態測試與既有 replay 證據。沒有重新執行完整 change-review 各情境，也沒有對真實程式 defect 進行 fix commit／複審閉環。封存時仍需依 tasks 的既有 follow-up，檢查上游尚未封存規格的整合；本輪不執行 archive。

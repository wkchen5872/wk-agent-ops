---
type: Reference
title: simplify-change-review 獨立驗證 r02
description: Codex 驗證發現 template 主入口、checklist 與測試仍是舊版，安裝副本卻為新版，核心套件 exit 1；另有封存前主規格調和警告。
tags: [verification, change-review]
generated: { by: codex/GPT-6, at: 2026-11-13T23:09:39+08:00 }
sources:
  - id: change
    resource: /openspec/changes/simplify-change-review/
    title: 本次需求、設計與任務
  - id: source
    resource: /template/common/skills/change-review/SKILL.md
    title: 受檢查的 template 主入口
  - id: test
    resource: /tests/test_change_review.sh
    title: 本輪實際執行的套件
  - id: prior
    resource: /docs/verification/change-review/2026-11-13-simplify-cr-r01.md
    title: 實作驗收紀錄 r01
---

# simplify-change-review verification r02

**結論：未通過，changes-required。** 一項根本交付問題 C-01（影響六項 requirement），另有一項 WARNING W-01。本輪只驗證、新增報告；不還原、不修改實作、不執行 repo 根目錄的 installer，不 commit、push、archive、發 PR 留言或通知。

Review-ID：`codex-simplify-cr-r02`。Checkout HEAD：`70383c176a086fa8db95319b1cd4d7fdb6de6bb1`，分支 `feature/streamline-github-pr-publication`。受測內容是當前未提交的 simplify-change-review 工作區，不能當成 PR #12 的遠端 head 結果。原有未追蹤 `test_sand.tmp` 與其他人的紀錄保持原樣。

## Summary scorecard

| 面向 | 結果 |
| --- | --- |
| Completeness | apply tracking 10/10 tasks 勾選，無 unavailableTrackingFiles；但 C-01 證明核心來源與新測試未留在目前交付狀態，不能以勾選宣稱完成。 |
| Correctness | 10 個 ADDED requirements；template 對版本、結果／finding、Author namespace、單輪界線的 4 項有既有處理，另外 6 項新行為未完整交付。24 scenarios 有案例文本，但不足以證明來源行為。完整 Agent／遠端行為 Not verified。 |
| Coherence | template 與安裝副本不一致；新版 SVG／案例、README 與舊入口／checklist 相矛盾。W-01：主規格已存在，delta 尚未調和。 |

## CRITICAL

### C-01 — 新版只有安裝副本，template 入口與測試仍是舊版

狀態：Open。目前 `template/common/skills/change-review/SKILL.md`、`references/checklists.md`、`tests/test_change_review.sh` 都逐位元等於受測 HEAD 的舊版本；`.claude`／`.agents` 入口卻是 v2.0 新版。核對開始與三套測試結束後的五個指紋沒有變化，不能把結果解釋為測試期間檔案移動。本輪無法確定變回舊版的原因，不歸責任何 session。

具體落差與影響：

- 主入口 `:36–37` 仍將 PR reference 與 phase 設為必填，因此無 PR 的 Change／Issue 不能按新流程進入。
- 主入口 `:128` 與 checklist `:48–49` 仍允許沒有 openspec-verify-change 時改用基線，違反 verify 必用。
- 主入口 `:170` 仍要額外發布請求，`:201` 仍要求 caller 指定 session 工具，不是新規劃的未通過預設回覆及可定位時通知。
- 測試 `:97` 仍只驗證 verify「when available」，新的入口與必用調度檢查未保留；這不能守住新行為。
- `bash tests/test_change_review.sh` 實際 exit 1，輸出 `FAIL repository change-review synchronized`。

受影響的 ADDED requirements：[^change]

| Requirement | 缺口 |
| --- | --- |
| Review resolves a Change from the selected target | 舊入口要求 PR，沒有新的 Change／Issue 解析分流。 |
| Review works with or without a PR | PR 必填，沒有 no-PR／unknown 的本機版本流程。 |
| OpenSpec verification is mandatory and quality extensions are optional | verify 在 template 仍是有安裝才用，可用舊基線代替。 |
| Review purpose controls the interpretation of evidence | phase 仍必填，checklist 仍是舊有調度。 |
| Failed PR reviews are appended through github-pr reply | 有 reply 舊路徑，但缺乏新規定的預設失敗發布、pass 直接回報與 local-only 分流。 |
| Confirmed PR feedback precedes local implementer notification | 舊流程需 caller 另指工具；沒有完整交付新預設本機定位與通知步驟。 |

已安裝 v2.0 的文字包含上述新行為，證明有新版產物，但不能替代 template 的唯一來源。重跑 installer 會以目前舊來源覆蓋安裝的新版；往其他 repo 安裝也會送出舊入口。[^source]

最小修正：恢復正確的新版 template 主入口、checklist 與相應新版測試，再經 installer 同步；不要只手改安裝副本。重跑相關套件及必要回歸，保存來源／副本比對與實際結果。若此狀態是另一次暫時的回退測試，須先還原正確來源並重新驗證，不能沿用先前 pass。

## WARNING

### W-01 — 封存前需將舊主規格的被取代要求改為完整 deltas

`openspec/specs/change-review/spec.md` 現已存在，仍有「Review resolves an explicit phase and version」與「Implementation review uses a self-contained verification baseline」等舊條款；本 change 仍宣告主規格不存在，且 spec 只有 ADDED。直接追加新要求會留下 PR／phase 必填、verify 是補充、通知另需 caller 指定等相反規則。

這已在 design／tasks 的 migration follow-up 記錄。封存前更新 proposal，依 canonical 完整 requirement block 建立適當 MODIFIED／必要 REMOVED deltas，保留版本、finding、批准與單輪範圍等未變要求，再 strict validate。本輪不代改規劃或封存。

## 本輪實際檢查

| 檢查 | 結果 |
| --- | --- |
| tests/test_change_review.sh | exit 1：repository change-review synchronized 失敗。 |
| tests/test_github_handoff.sh | exit 0。 |
| tests/test_work_items.sh | exit 0。 |
| openspec validate simplify-change-review --strict | exit 0；規劃格式有效不等於實作交付完整。 |
| git diff --check | exit 0。 |
| Source／installed 比對 | 兩個安裝目標皆有 SKILL.md、references/checklists.md 不一致。 |
| 圖稿 | template review-loop.svg 經 rsvg-convert 渲染並實際檢視，未見裁切；圖是新流程，主入口卻仍舊版。 |

因核心套件已失敗且交付內容不一致，本輪沒有繼續重跑其餘九組 tests，也不沿用其他 change 的全套通過結果來覆蓋本次失敗。[^test]

測試前後的 SHA-256：

| 檔案 | 指紋 |
| --- | --- |
| template/common/skills/change-review/SKILL.md | 84cd86fd2ba95d5a98d88aa94cc4e48f47fe26da4f07544e9fba50cbde9ad7e8 |
| template/common/skills/change-review/references/checklists.md | 3dc5a3c85d06a8533d86a51ef4f602e096cfcd8e095624ce07a6d9bd307c50e4 |
| tests/test_change_review.sh | c0e258f385a3553951b02ceea7bc90f160d4e7ef571ef183d12fb0d9782e7556 |
| .claude/skills/change-review/SKILL.md | 42c245cd5eb2cd9a25f7f8b7d87ac588575cb9e435a8ab17e2087f81b620dfc0 |
| .agents/skills/change-review/SKILL.md | 42c245cd5eb2cd9a25f7f8b7d87ac588575cb9e435a8ab17e2087f81b620dfc0 |

## 未驗證與評估界線

本輪已讀 proposal、design、spec、tasks、template／安裝版主入口、checklist、案例、相關文件與 r01。r01 的生成／replay 是既有模擬證據，本輪未重做；它宣稱的同步／全套通過不能代表目前來源狀態。[^prior]

沒有真實 GitHub 發文、MCP、session 核對／通知，也沒有在最終一致的來源上重跑完整技能決策與真實下游 verify 調度。這些為適用但未驗證的檢查，不計 pass。受測內容有 C-01，不能宣稱 ready for archive；先修來源交付與新測試，再複驗。

[^change]: [需求規格](../../../openspec/changes/simplify-change-review/specs/change-review/spec.md) 與 [tasks](../../../openspec/changes/simplify-change-review/tasks.md)。
[^source]: [template 入口](../../../template/common/skills/change-review/SKILL.md) 與 [checklist](../../../template/common/skills/change-review/references/checklists.md)。
[^test]: [change-review suite](../../../tests/test_change_review.sh)。
[^prior]: [r01 實作驗收紀錄](2026-11-13-simplify-cr-r01.md)。

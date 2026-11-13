---
type: Reference
title: streamline-github-pr-publication 獨立驗證 r02
description: Codex 核對 8 項需求與 21 個情境、重跑 12 組測試及 strict validation；一項主規格調和警告，遠端行為未驗證。
tags: [verification, github-handoff]
generated: { by: codex/GPT-6, at: 2026-11-13T22:51:59+08:00 }
sources:
  - id: change
    resource: /openspec/changes/streamline-github-pr-publication/
    title: 本輪完整規劃 artifacts
  - id: implementation
    resource: /template/common/skills/github-pr/SKILL.md
    title: github-pr 實作
  - id: prior
    resource: /docs/verification/github-handoff/2026-11-13-streamline-pr-r01.md
    title: Claude 實作與離線重播紀錄
  - id: canonical
    resource: /openspec/specs/github-pr/spec.md
    title: 上游封存後的 github-pr 主規格
---

# streamline-github-pr-publication verification r02

審查分支 `feature/streamline-github-pr-publication`，受測 HEAD `983c1d16c597f0caeb6b493dbf412c3510943c2e`，開始時工作區乾淨。本輪只驗證與新增本報告，沒有實作、勾改 tasks、archive、commit、push、GitHub 寫入或通知。Review-ID：`codex-streamline-pr-r02`。

## Summary scorecard

| 面向 | 結果 |
| --- | --- |
| Completeness | apply tracking 8/8 tasks complete，沒有 unavailableTrackingFiles；8 個 ADDED requirements 均找到指令與案例；沒有 REMOVED／RENAMED。勾選本身不視為全行為驗收通過。 |
| Correctness | 8/8 requirements 有實作對應，21 個 scenarios 有處理與案例；本機測試通過。Scenario Coverage 部分 Not verified：本輪沒有逐例重新執行自然語言 Agent 決策，也沒有真實 GitHub／MCP／通知整合。 |
| Coherence | create 發布、scoped Git、雙欄 Author、消費端 namespace 與 metadata 操作界線符合 design；沿用 template／installer 模式。W-01：主規格與新 delta 的發布規則尚未調和。 |

## Requirement implementation mapping

| Requirement | 實作／案例與證據 |
| --- | --- |
| Creating a PR includes necessary Git publication without repeated approval | github-pr 操作表、§create Step 5；GP-70、72、74；本機 publication suite。 |
| Necessary publication preserves unrelated work and existing Git controls | Step 5 的 pathspec commit、目的地與正常 push；GP-71、76、77、GP-25；真實臨時 repo 驗證。 |
| Publication and PR results are verified before completion claims | Step 5 remote SHA／compare、Step 6 設計與實作界線、Step 7 回讀；GP-31、70、74；遠端 API 本輪未測。 |
| Existing targets and partial results are reconciled without duplicate publication | §create 前置查找及 Partial results and reruns；GP-21、73、75、78、79；實際 PR retry 本輪未測。 |
| PR Author includes native and Xirp session identifiers independently | Step 6、shared contract §6.2 的 PR／Review／Changes；GP-38、81–84。 |
| Session discovery actively checks the current runtime before falling back | Step 6 的限定 key lookup、個別 null 與來源核對；GP-81、85；不同 runtime 的整合本輪未測。 |
| Consumers preserve session namespaces and legacy Author compatibility | change-review §Write findings／§Hand off、contract §6.2；CR-45–47。 |
| Metadata operations do not inherit create publication side effects | 操作表與 update／reply／close；GP-86、既有正文保留與 close reason 案例；相關 regression suites。 |

各 requirement 的 21 個 scenario 均有指令／fixture 對應；這是覆蓋映射，不是 21/21 真實行為重播通過。完整規劃與 scenario 文本已實際讀取。[^change][^implementation]

## Issues by priority

### CRITICAL

無未完成 task 或已確認缺失的 requirement 實作。

### WARNING

**W-01 — 封存前需要調和已存在的 canonical github-pr。**

`openspec/specs/github-pr/spec.md:79–89` 仍規定 create／update／reply／close 全部不得 stage、commit、push；`:58–61` 仍允許以單一 SESSION-ID 放管理 ID。可是本 change 的 `specs/github-pr/spec.md:7` 只有 ADDED Requirements，沒有改寫原有條款。Proposal 也仍以「主規格尚不存在」描述目前狀態。[^canonical][^change]

上游在規劃後已封存，所以這是已知 migration follow-up 的現況變化，不是 create 實作缺少。若直接合併新增條款，舊的禁止 create 發布與新版允許規則會同時存在。

建議：封存前更新 proposal 的 modified capability 宣告，針對原有「PR operations do not publish Git changes」「Create verifies a real published branch and avoids duplicate PRs」「Author identifies the current posting session truthfully」與必要的 Purpose／scenario 做完整 MODIFIED deltas，保留未改動的 update／reply／close、fork、空差異與歷史相容條件；與新增條款一起核對，再 validate。此輪依 verify 的唯讀界線沒有代改規格。

### SUGGESTION

無。

## 本輪實際執行

- 以 Python subprocess 的 returncode 執行全部 12 組 `tests/test_*.sh`，每組 exit 0：agents_dir、bulk_read_routing、change_review、documentation_authoring、github_handoff、github_pr_publication、mutation_skills、openspec_commit、portable_agents_md、tdd_enforcement、work_items、workflow。
- `test_github_pr_publication.sh` 使用真實臨時 Git repo 與本機 bare remote：pathspec commit 只含本次檔案、無關 staged／unstaged／untracked 狀態保留、正常 push／SHA 回讀、重跑 commit 數不變、失敗 hook 不改 HEAD、既有 commit 發布、non-fast-forward 不覆寫遠端、既有前置 base 原樣發布。它測的是 skill 記載的原生 Git 命令，不是完整 Agent＋GitHub pipeline。
- `openspec validate streamline-github-pr-publication --strict` exit 0；`git diff --check` exit 0。
- github-pr／change-review 的 template 所有檔案與 `.claude/skills`、`.agents/skills` 副本逐位元一致；managed contract、handoff SVG、Work Item AGENTS 也一致。
- 當前 handoff SVG 經 rsvg-convert 渲染並實際檢視，文字及流程可讀，未見裁切；create 與 update 的 Git 邊界與文字契約一致。

來源指紋 SHA-256：

| 檔案 | 指紋 |
| --- | --- |
| template/common/skills/github-pr/SKILL.md | 93d7a3b6d18cf77ecca3689ce755bc622a8b772236ba5b452ca8ca9073a67d3c |
| template/common/docs/github-handoff.md | f0b37ceaa74ed7c4269f5a4955ab7ecf668ada20609a5f392d118df8cbb5aed7 |
| tests/test_github_pr_publication.sh | b6d5305c0ab21b9a357c479423be48fc33de4d493f6f886e8d5ad100fcfdac94 |

## Limits and final assessment

r01 的 23 例 Agent replay 是既有證據，本輪只審閱，沒有重新執行；它也明列看過預期答案、最後修正後未重播等限制，不能當成盲測。[^prior]

本輪未建立或改動真實 GitHub PR，未測 MCP、真實 session 通知、權限拒絕／timeout 整合，以及所有 provider 的 Session ID lookup。這些屬適用但尚未驗證的完整端到端行為，不是自動通過，也不是新增一個必須寫遠端才能封存的門檻。

結論：已執行檢查沒有 CRITICAL；1 個 WARNING、0 個 SUGGESTION。實作與本機 regression 未發現已確認缺陷；完整 scenario 執行與遠端整合 Not verified，不能宣稱全數驗收通過或 ready for archive。W-01 應在封存前按既有 migration follow-up 調和。

[^change]: [本輪 proposal](../../../openspec/changes/streamline-github-pr-publication/proposal.md)、[spec](../../../openspec/changes/streamline-github-pr-publication/specs/github-pr/spec.md)、[design](../../../openspec/changes/streamline-github-pr-publication/design.md)、[tasks](../../../openspec/changes/streamline-github-pr-publication/tasks.md)。
[^implementation]: [github-pr](../../../template/common/skills/github-pr/SKILL.md)、[change-review](../../../template/common/skills/change-review/SKILL.md)。
[^canonical]: [github-pr 主規格](../../../openspec/specs/github-pr/spec.md)。
[^prior]: [r01 實作驗證紀錄](2026-11-13-streamline-pr-r01.md)。

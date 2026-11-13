---
type: Reference
title: GitHub Issue 精簡化的獨立驗收與遠端實測 r07
description: Codex 重跑本機測試、核對來源到任務內容，並實測 github-issue 建立、查重及留言更新；Draft PR 發布另以遠端結果為準。
tags: [verification, github-handoff, github-issue]
generated: { by: codex/GPT-6, at: "2026-11-13T20:36:10+08:00" }
sources:
  - id: issue
    resource: https://github.com/wkchen5872/wk-agent-ops/issues/5
    title: 本次工作的正式追蹤 Issue
  - id: comment
    resource: https://github.com/wkchen5872/wk-agent-ops/issues/5#issuecomment-6853077083
    title: 只新增留言的更新實測
  - id: r06
    resource: /docs/verification/github-handoff/2026-11-13-simplify-issue-r06.md
    title: Claude 的來源到內容生成與離線重播證據
  - id: cases
    resource: /template/common/skills/github-issue/references/acceptance-cases.md
    title: GitHub Issue 可重播案例
---

# GitHub Issue 精簡化的獨立驗收與遠端實測 r07

## 範圍與交接

使用者要求等待 Claude Session `eb4f5f48-3592-47fd-90e9-21249f334648` 完成修正，之後由 Codex 驗收，並允許用 skill 開 PR 測試。Claude 已回報實作完成並停止寫入，未 commit、push 或 archive。驗收基線是 `feature/simplify-github-issue` 的 `6941aa2` 加上此次未提交變更。

本輪使用 `openspec-verify-change`、`github-issue` 與 `github-pr` 的既有流程。API 實測使用本機已配置的 gh，留言的實際 API 作者由回讀確認為 `wkchen5872`；工具／root-session 模型為 Codex／GPT-6。不把 Agent 的離線推導當作真實 API 成功。

## 內容驗收

前輪的三項 finding 已有對應修正：

| Finding | 本輪檢查 | 結果 |
| --- | --- | --- |
| 沒有可檢驗的來源到任務整理 | GI-35、GI-36、GI-37 現在提供來源實文、完整參考產出與內容判定；核對 r06 的獨立生成結果及最終 skill 指令 | 已修正 |
| 指定來源會排除本輪對話 | skill 將 Records 與 Conversation 分開，一律整合相關對話；GI-35 的舊值 5 次由使用者新決策 3 次取代，冪等問題仍列未決 | 已修正 |
| Issue 連結被當作合併條件 | examples 改為 PR #12，明列 merge 即解除、無須等部署 | 已修正 |

內容標準是讀者能理解問題、影響、範圍、工作結果與未決事項，不增加每篇必填的中間章節。GI-36 的任務以使用者可見結果重寫；GI-37 的單筆索引做法仍是待確認。r06 只有 A 保存完整獨立生成正文，B、C 保存節錄與審閱摘要；本輪沒有聲稱重新啟動 Agent 跑完全部 25 個情境。[^r06][^cases]

本輪依同一 skill，實際將此 change 與對話整理成 Issue #5：正文交代內部紀錄過多造成的閱讀問題、可交辦任務的目標與可檢查結果，沒有搬運 tasks 群組或 Work Item 格式。[^issue]

## 實際執行的本機檢查

以下 11 套測試由 Codex 在本輪重新執行，各 exit code 都為 0：

- `tests/test_agents_dir.sh`
- `tests/test_bulk_read_routing.sh`
- `tests/test_change_review.sh`
- `tests/test_documentation_authoring.sh`
- `tests/test_github_handoff.sh`
- `tests/test_mutation_skills.sh`
- `tests/test_openspec_commit.sh`
- `tests/test_portable_agents_md.sh`
- `tests/test_tdd_enforcement.sh`
- `tests/test_work_items.sh`
- `tests/test_workflow.sh`

`openspec validate simplify-github-issue --strict` 與 `git diff --check` 均通過。另讀取並核對 10 個 requirements、25 個 scenarios 與 11/11 task 勾選；勾選不是執行證據，行為證據依本文件與 r06 分開判讀。受影響 skills、managed contract、SVG 與 Work Item 規範的來源／安裝副本已核對。以 `rsvg-convert` 渲染 handoff SVG 並實際開啟，未發現文字重疊或溢出。

## 真實 GitHub 操作

完整目標為 `github.com/wkchen5872/wk-agent-ops`。寫入前以 gh repo view 核對目標；Issue 查重使用 `--state all --search '"simplify-github-issue" in:body,comments'`，起初回傳空陣列。

1. 以 `gh issue create --body-file` 建立 #5；回讀 number、URL、正文與 metadata，正文與預備內容相符。未發布的 References 明列 local-only。
2. 以 `gh issue comment 5 --body-file` 新增留言 `6853077083`，不呼叫 body-edit 或 comment-edit。依留言 ID 回讀，核對 `issue_url`、正文與實際作者，均相符。[^comment]
3. 比較更新前後的結構化快照：Issue 的正文、title、state、labels、assignees 全部相同；留言數從 0 增加為 1。正文 SHA-256 前後均為 `15d3bc9783d9faee37b6f436e45d5120de5a48d20c3d43d5e491db3c01e7f9da`。
4. 重跑 create 的查重步驟，回傳唯一 #5，再核對 Handoff 的精確 Change ID；依 skill 沿用該 Issue，沒有建立第二筆。

這是本次 repository 的實測結果，不代表每個 gh／MCP 通道與所有失敗情境都已遠端驗收。

## 發布與限制

- 本紀錄寫成時尚未 commit／push／建立 Draft PR；後續發布依實際回傳 URL 與 remote SHA 回讀確認，不把預定動作寫成成功。
- PR 預定 base 為 `feature/add-change-review-skill`，因其遠端 head 與此工作起點均為 `6941aa2`；這樣只呈現此次 Issue 修改，避免把尚未合併的上游功能混入 diff。
- 本輪沒有在遠端注入 403、逾時或回讀失敗，也沒有真實操作另一個 MCP 寫入通道；相關情境只有既有離線證據。
- C-21 的既有禁止項措辭仍有歧義，實際 skill 與契約第 3 節要求明確拒絕即停止；此項為非阻擋的既有措辭限制。
- 上游 handoff 主規格尚未封存；archive 仍須依 design 的規格調和流程處理。本輪驗收與 PR 發布不代表 merge、archive 或所有遠端情境通過。

[^issue]: [正式追蹤 Issue #5](https://github.com/wkchen5872/wk-agent-ops/issues/5)。
[^comment]: [更新留言與本輪驗收結果](https://github.com/wkchen5872/wk-agent-ops/issues/5#issuecomment-6853077083)。
[^r06]: [Claude 的獨立生成與離線重播紀錄](2026-11-13-simplify-issue-r06.md)。
[^cases]: [來源到內容案例與判定](../../../template/common/skills/github-issue/references/acceptance-cases.md)。

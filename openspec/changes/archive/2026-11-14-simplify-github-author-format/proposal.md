# Proposal

## Why

Issue [#18](https://github.com/wkchen5872/wk-agent-ops/issues/18) 指出 Author 的「方式: Agent 協助」與「人類: @帳號」增加重複資訊：Agent 工具／模型已說明協助來源，GitHub 也顯示實際發布帳號。應精簡新內容的共用格式，同時保留原報告作者、發布 Agent 與雙 Session 的追查能力。

## What Changes

- **BREAKING**：新的 Issue／PR 正文與留言不再輸出 Author 的「方式」與「人類」兩行，也不換成同義欄位重複標示。
- Agent 貼文保留 `Co-Authored-By`、已知的 `AI-Assisted-By`、`SESSION-ID` 與 `XIRP-SESSION-ID`；沿用各欄位的未知值、隱私與命名空間規則。
- 純人類直接發文不為湊格式而建立空 Author 或 Agent metadata；Handoff、工作內容與 Next actions 繼續保留。
- 代發他人的 Review／實作報告仍保留有意義的原作者與來源。新格式不依賴「方式」辨識代發，舊紀錄與舊代發標記仍可讀。
- 同步共用契約、GitHub 入口、Review 的原實作者定位、所有相關範例與驗收案例。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `github-change-handoff`: 簡化 Author 與共用外框，明定純人類例外、代發來源與歷史相容。
- `github-issue`: Issue 建立、更新與結案沿用精簡後的 Author 規則。
- `github-pr`: PR 建立、更新、Review／修正回覆及結案內容沿用相同格式與來源辨識。

## Impact

- 修改 `template/common/docs/github-handoff.md` 的共用 Author、各用途範本、欄位說明及案例，再經 installer 更新 managed 文件。
- 同步 `template/common/skills/github-issue/`、`github-pr/`、`change-review/` 的相關入口與 references。既有 Review Step 6 使用「方式: Agent 協助代發」或「原報告作者」辨識來源，需保留舊標記讀取並明確支援新格式。
- 驗證 `tests/test_github_handoff.sh`、`tests/test_github_pr_publication.sh`、`tests/test_change_review.sh` 及 installer 的適用檢查，支援 Claude Code、Codex、Antigravity。
- 不調整批准／帳號授權政策、Git／GitHub operation 權限、Session mapping 或 Issue／PR 關閉流程；不處理 Issue #19 的 commit 引用自動化，不改寫歷史貼文與其他 Change。

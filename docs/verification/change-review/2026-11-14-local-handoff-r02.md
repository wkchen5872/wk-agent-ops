---
type: Reference
title: change-review 本地交接驗證紀錄 2026-11-14-local-handoff-r02
description: 回應 codex-local-handoff-r01/F-01（無 PR 時的實作者來源）的修正驗證：Red／Green、installer、12 套檢查與 5 案盲測重播；沒有 GitHub 寫入或 Session 通知。
tags: [verification, change-review]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T17:06:00+08:00" }
sources:
  - id: review
    resource: https://github.com/wkchen5872/wk-agent-ops/pull/15#issuecomment-6874906177
    title: codex-local-handoff-r01
---

# change-review 本地交接驗證紀錄 2026-11-14-local-handoff-r02

## 範圍

- Review：[codex-local-handoff-r01](https://github.com/wkchen5872/wk-agent-ops/pull/15#issuecomment-6874906177)，結論 changes-required。
- 受審快照：本地 HEAD `e903c81` 加 15 個未提交檔案，digest `dafc2ab5…d03f`。修正開始前重算，結果相同。
- 本紀錄只提供修正證據；Finding 是否 Resolved 由 Reviewer 複審判定。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

## codex-local-handoff-r01/F-01：無 PR 交接的實作者來源

**Red**：在 `tests/test_change_review.sh` 新增檢查，要求來源規則寫在 SKILL 本身的 Step 6.1，而不是由 fixture 補上。修正前執行結果為 exit 1，5 項 FAIL：

- `step 1 names the local implementation record as a source`
- `step 1 allows an explicitly user-named recipient`
- `step 1 forbids pulling records from another worktree`
- `case for '本地交接：只有本機實作紀錄'`
- `case for '本地交接：本機紀錄沒有身分'`

**修正**：

- SKILL Step 6.1 補上無 PR 時的來源，二擇一：
  - 本目錄 Work Item 中、同一 Change 的本機實作或修正紀錄（或使用者指定的紀錄）。讀取方式與 PR 相同：Author 欄位與代發標記。
  - 使用者明確指定、而且 Session 可核對的收件人。
- 保留的防護：
  - 不從其他 worktree 取紀錄，不建立 registry。
  - 不使用 Reviewer 自己或代發者的 ID。
  - 沒有來源就不送出。
  - Step 6.2 的工具、專案、原生 ID、管理 ID 核對不變。
- 新增案例：CR-89「本地交接：只有本機實作紀錄」、CR-90「本地交接：本機紀錄沒有身分」。CR-78 的 fixture 補註紀錄所在位置。

**Green**：

- installer exit 0，只同步 change-review 的安裝副本。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0。
- `openspec validate improve-change-review-local-handoff --strict` 通過；`git diff --check` 通過。

## 盲測重播

做法：新的 subagent 只讀已安裝的 change-review SKILL，輸入只有 fixture 與模擬回覆，不讀 case 檔、openspec 與 WI 目錄。

| 案例 | 實際判定 | 與預期 |
| --- | --- | --- |
| CR-78 本地交接：明確要求 | 依同一 Work Item 的本機實作紀錄核對後，送出一次 | 相符 |
| CR-81 本地交接：代發者 | 原作者無法核對，不送出，也不改送代發者 | 相符 |
| CR-82 本地交接：mapping 不符 | 不送出 | 相符 |
| CR-89 只有本機實作紀錄 | 依 Step 6.1 的無 PR 來源核對後，送出一次，沒有 PR URL | 相符 |
| CR-90 本機紀錄沒有身分 | 不送出，回傳可轉交訊息 | 相符 |

重播指出 CR-78 的 fixture 沒寫實作紀錄放在哪裡，已補註。

## 未執行

- 真實的 Session 訊息與 GitHub 寫入都沒有執行。
- 重播者與實作者是同一個模型家族。

---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-13-simplify-pr-r03
description: 針對 codex-simplify-pr-r02/F-01（取消的 Issue 被存成 completed）的修正與驗證：close 依證據設定 Issue 關閉原因並回讀；附有效的 Red、回歸檢查與安裝同步，另更正 r01 測試結果的取得方式。沒有任何遠端寫入。
tags: [verification, github-handoff]
generated: { by: claude-code/Claude Opus 5.5, at: 2026-11-13T23:59:00+08:00 }
sources:
  - id: review
    resource: /docs/verification/github-handoff/2026-11-13-simplify-pr-r02.md
    title: codex-simplify-pr-r02 審查紀錄（F-01）
  - id: r01
    resource: /docs/verification/github-handoff/2026-11-13-simplify-pr-r01.md
    title: 實作驗證紀錄 r01
---

# GitHub 交接驗證紀錄 2026-11-13-simplify-pr-r03

本輪只處理 [r02](2026-11-13-simplify-pr-r02.md) 的 F-01。F-01 的狀態仍由 Reviewer 判定，
本紀錄**不**把它標為 Resolved。r01 與 r02 保持原樣。

## 範圍與授權

- 執行者：Claude Code，模型 Claude Opus 5.5。
- 沒有任何遠端操作。沒有重開、修改或再次關閉 #5–#9，也沒有刪除測試 branch。Issue #8 的
  `closed / completed` 是缺陷證據，保持原樣。
- 只修改 template 來源，再以 installer 同步：
  - `template/common/skills/github-pr/SKILL.md`
  - `template/common/skills/github-pr/references/acceptance-cases.md`
  - `template/common/docs/github-handoff.md`
  - `tests/test_github_handoff.sh`

## 修正內容

- **skill close 的步驟 1（盤點）**：關閉原因也要有證據，並在寫入前決定。取消或被取代用
  `not planned`；工作確實完成才用 `completed`。兩者都沒有證據時先詢問。工具不能設定
  原因時，開始前回報。
- **skill close 的步驟 3**：
  - 命令改為 `gh issue close <N> … --reason "not planned" --comment …`，完成的工作改用
    `--reason completed`。使用 MCP 時設定等價的 `state_reason`（`not_planned`／`completed`）。
  - 回讀改為 `--json state,stateReason,url`，並核對原因。原因不符時回報「原因不符」，
    不算成功，也不 reopen。留言無法改變平台儲存的原因。
- **契約 §10**：新增一條規則，關閉 Issue 時平台儲存的原因要有證據，並回讀核對。
- **案例**：
  - close 的共同 fixture 改為「決定不做 → not planned，回讀 `NOT_PLANNED`」，共同禁止加上
    「不指定原因，或指定與證據不符的原因」。
  - GP-50（取消）明確要求 `--reason "not planned"`，並禁止 `completed`。
  - GP-53、GP-56、GP-57、GP-58 的預期呼叫補上原因。
  - GP-59 補上使用者確認工作已完成的證據，使用 `completed`，並禁止「只因 merged 就推定
    完成」。
  - 新增 GP-66：工作被取代、要求 not planned，但讀回 `COMPLETED`，應回報原因不符。

## 測試

`tests/test_github_handoff.sh` 新增 SGP-4 共 9 項檢查。修改前執行（`rc=1`），9 項全部 FAIL：

```text
FAIL close sets an explicit Issue close reason
FAIL cancelled or superseded work closes as not planned
FAIL close reads back the stored close reason
FAIL close names the MCP state_reason field
FAIL every github-pr Issue close command carries --reason
FAIL every expected Issue close call in the cases carries --reason
FAIL a case reads back NOT_PLANNED
FAIL a case keeps COMPLETED for finished work
FAIL contract §10 ties Issue close reason to evidence
```

修正後，第 6 項仍誤判模擬回覆中出現的 `gh issue close 7`（那是在描述工具的回傳，不是
預期呼叫），所以把這項的範圍收斂到 `預期呼叫` 行。範圍收斂之後，這項在舊版仍會失敗：
GP-50 的預期呼叫沒有 `--reason`。

修正後的結果：

- `bash scripts/skills/install.sh`：exit 0。
- 11 套 `tests/test_*.sh` 逐一以 `bash "$t"; rc=$?` 取得 exit code，全部 `rc=0`。
- `openspec validate simplify-github-pr --strict`：`rc=0`。
- `git diff --check`：`rc=0`。
- github-pr 的 `.claude`、`.agents` 副本與 managed 契約都和 template 一致（`diff -r`／`cmp` 的 rc 為 0）。

## 對 r01 的更正

r01 與這個 Session 中先前的「11 套測試 rc=0」，是用
`echo "$(basename $t) rc=$?"` 取得的。命令替換 `$(basename …)` 會比 `$?` 先展開，
所以印出的是 `basename` 的 exit code，而不是測試的結果。那些數字不能當作測試通過的證據。

本輪改用正確的取法，對目前的工作區重跑，11 套全部通過。由此只能確認**目前**的狀態是通過，
不能回頭證明 r01 當時的每一次執行。r01 中另外用 `grep FAIL` 確認過的聚焦結果不受影響。

## 已知限制

- 這次修正沒有在真實 GitHub 上重新驗證：沒有對任何 Issue 實際執行 `--reason "not planned"`
  並讀回 `stateReason`。完成條件中「取消情境實際讀回 `closed / not_planned`」仍待 Reviewer
  在授權的測試目標上確認。r02 清理 #9 時，`--reason 'not planned'` 已讀回 `not_planned`，
  可以作為 `gh` 參數本身有效的旁證。
- MCP 的 `state_reason` 欄位名稱依 GitHub REST 的 `state_reason` 撰寫，沒有在實際的 MCP 上
  驗證。
- 修正後沒有另外請 Agent 做離線重播。

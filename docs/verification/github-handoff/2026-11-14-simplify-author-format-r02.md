---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-14-simplify-author-format-r02
description: 回應本地 Review codex-author-r01/F-01（§7、§6.1 與 inline 期望仍保留舊 Author 規則）的修正驗證：Red／Green、installer、12 套檢查與 4 案盲測重播；沒有 GitHub 寫入。
tags: [verification, github-handoff, author]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T17:42:00+08:00" }
sources:
  - id: review
    resource: 本地 Review codex-author-r01（ignored Work Item，不發布）
    title: codex-author-r01
---

# GitHub 交接驗證紀錄 2026-11-14-simplify-author-format-r02

## 範圍

- Review：codex-author-r01，結論 changes-required。這是本機 Review，本 Change 沒有 PR，不寫入 PR #15。
- 受審快照：HEAD `f39ad08` 加 41 個未提交檔案，digest `473b8db2…03ed`。修正開始前重算，結果相同。
- 本紀錄只提供修正證據；Finding 是否 Resolved 由 Reviewer 複審判定。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

## codex-author-r01/F-01

**擴大掃描**：除了 Review 指出的三處，另在整個 template 中搜尋描述或期望舊欄位、而且不屬於 legacy fixture 或禁止事項的文字，又找到同類的一處：`github-issue/references/examples.md` 的「省略模型與未確認的人類」。其他「Author 在後」的描述都是 Agent 發文的情境，不需要修改。

**Red**：在 `tests/test_github_handoff.sh` 新增 5 項檢查。修正前執行結果為 exit 1，5 項全部 FAIL：

- `§7 Provenance names no mode/human Author line`
- `§6.1 does not require Author unconditionally`
- `§6.1 requires Author only when an Agent posts`
- `no expected output or judgement asks for a mode/human Author line`：掃描契約與所有 references 中「判定／預期呼叫／產出」開頭的行，看是否以 inline 方式期望 `` `方式: `` 或 `` `人類: ``。這就是先前測試漏掉的那一類。
- `Issue example no longer mentions an omitted human field`

**修正**（全部改在 template）：

1. 契約 §7 改為：Agent 參與時只用共用外框的 Author，也就是工具、已知模型與兩個 Session ID；沒有 Agent 參與的直接發文不加 Author。
2. 契約 §6.1 改為：Handoff、Goal、Next actions 必須出現；Agent 參與時最後是 Author，人類直接發文不加。
3. GI-01 的判定移除 `` `方式: Agent 協助` ``。
4. Issue examples 的缺值範例措辭改成只說省略模型。
5. 重播之後，§6 補一句：Agent 只幫忙檢查格式、內容由人類自己撰寫並發布時，仍屬人類直接發布。這與 GI-42、GP-49 的既有判定一致。

保留不變的部分：舊格式的讀取規則、批准事件的 `approved_by`、代發的 `原報告作者`、change-review 的 mapping 防護。

**Green**：

- 修改後、installer 前，新檢查全部通過，只剩安裝副本同步兩項。
- installer exit 0。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0；test_github_handoff 為 511 ok。
- `openspec validate simplify-github-author-format --strict` 通過；`git diff --check` 通過。
- 加入第 5 點後，再次 install 並重跑 12 套，結果相同。

## 盲測重播

做法：

- 新的 subagent 讀契約 §6～§7、github-issue SKILL 與 github-pr 的 reply 段落，並被要求指出 §6、§6.1、§7 之間是否互相矛盾。
- 輸入只有 fixture 與模擬回覆。
- 它分段讀檔時讀超過 §8 標題，看到 §8 與 §9 開頭，但沒有讀到附錄 A；它的答案不依賴這兩節。

| 案例 | 實際輸出 | 依據 | 與預期 |
| --- | --- | --- | --- |
| GI-01 Agent 新建 Issue | Handoff → Goal → Acceptance criteria → References → Next actions → Author（四種欄位） | §6.1、§6、§7 | 相符 |
| GI-42 人類自行發布 | 沒有 Author 段落 | §6、§6.1、§7 | 相符 |
| C-08 PR 回覆 | 四種欄位，`XIRP-SESSION-ID: null` | §6、§6.2、§7 | 相符 |
| C-28 人類直接發布 | 沒有 Author 段落 | §6、§6.1、§7 | 相符 |

重播判斷三節之間沒有矛盾。它提出的「Agent 參與」範圍不清，已由上述第 5 點補上。另外兩點是閱讀上的提醒，不是缺陷，本輪不修改：

- Handoff 的 `null` 佔位與 Session 欄位的 `null` 屬於不同欄位。
- §7 的表格只用於批准事件與完整基線。

## 未執行

- 真實的 Issue／PR 發文沒有執行。
- 重播者與實作者是同一個模型家族。

---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-14-simplify-author-format-r01
description: simplify-github-author-format（Issue #18）的 Apply 驗證：Red／Green、installer、12 套檢查、strict validate、OpenSpec verify 與 14 案盲測重播；沒有 GitHub 寫入或 Session 通知。
tags: [verification, github-handoff, author]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T18:10:00+08:00" }
sources:
  - id: cases
    resource: template/common/docs/github-handoff.md 附錄 A 與 github-issue／github-pr／change-review 的 references（工作區未提交版本，base f39ad08）
    title: 共同與入口的可重播案例
---

# GitHub 交接驗證紀錄 2026-11-14-simplify-author-format-r01

## 範圍與版本

- Change：`simplify-github-author-format`，分支 `feature/simplify-github-author-format`，base main `f39ad08525a8c64dcfa74037ce43d967bc5293c7`。本 Change 沒有 PR。
- 授權：使用者明確指示「請 Claude 實作」，經協調者轉達，涵蓋目前的 proposal／design／specs／tasks。依新版契約 §9，不需要 PR 批准事件，也不需要確認帳號。
- 規劃快照：以授權時的算法重算為 `144b20956e4c0f3ebc81181a24a663007a1f4a007ca1fce6b54b8d1ed066c6c8`，與授權值相同。實作期間只勾選 tasks。
- Skill 調用：`openspec-apply-change`（SKILL.md 的 sha256 開頭為 `ed76b497`）、`openspec-verify-change`。調用時間記錄在 job 暫存證據中。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

| 層級 | 狀態 |
| --- | --- |
| 靜態檢查（`test_github_handoff.sh` 的 SAF-1／2 段、`test_change_review.sh`） | 已執行，通過 |
| 語意（盲測重播） | 14 案已執行 |
| installer（本 repo；臨時 repo 新裝、重裝與三工具入口鏈） | 已執行，通過 |
| GitHub 真實寫入、Session 通知 | **未執行**，也沒有為測試發文 |

## Red

先改測試，再改來源。

**改寫的舊斷言**：有 4 項舊斷言要求已移除的欄位，依新語意改寫：

- §6 共用外框原本要求含 `方式: Agent 協助`、`方式: 人類直接發布`、`人類:`。
- Issue examples 原本要求含 `方式: 人類直接發布`。
- PR examples 原本要求含 `方式: Agent 協助代發`，改為要求含 `原報告作者:`。
- change-review cases 原本要求含 `方式: Agent 協助`，改為要求含 `Co-Authored-By: Claude Code`。

**新增的 SAF 段**：在舊來源上執行的結果如下。

- `test_github_handoff.sh`：exit 1，22 項有效 FAIL，例如：
  - `no §6 template writes a mode or human-account line (14)`
  - `pure human-direct posts omit Author`
  - `agent-on-behalf posts keep Agent metadata`
  - `github-issue/SKILL.md no longer instructs mode/human lines`
  - `change-review identifies relays by the original-author line`
  - examples 與 cases 中仍寫出 `方式`／`人類` 行的計數
- `test_change_review.sh`：exit 1，2 項 FAIL，即新格式代發與舊代發標記的案例。

另有一項是測試本身的錯誤，不算 Red：§6 的 Agent Author 範本實際只有 6 處（§6.6／§6.7 寫的是 `<依共用外框>`），門檻原本寫成 ≥7，已改成 ≥6。

## 實作

**契約**：

- §6 共用外框的 Author 移除「方式」與「人類」兩行，只保留工具、已知模型與兩個 Session ID，也不換成同義欄位。
- 人類直接發布、沒有 Agent 參與時不加 Author；由 Agent 代為整理或發布時，仍寫 Agent 的 Author。
- 代發只看 `原報告作者` 與來源辨識。
- 舊紀錄的 `方式`、`人類` 與舊代發標記仍可讀；舊代發標記不能單獨證明原作者的 Session。
- §6.1、§6.2 的 6 個範本與 §6.1 的說明文字同步修改。
- 附錄案例：C-08、C-28、C-29、C-30 改寫；新增 C-47「Agent 代人類發布」、C-48「新格式代發」、C-49「舊格式後追加新內容」。
- 批准事件的 `approved_by` 維持不變。

**入口**：

- github-issue／github-pr SKILL 的 Author 段落改為只寫四種欄位，並寫明人類直接發布時沒有 Author。
- change-review Step 6.1 以 `原報告作者` 辨識代發，舊的 `方式: Agent 協助代發` 仍可讀。

**references**：

- github-issue examples／cases、github-pr examples／cases、change-review cases、openspec-commit examples：移除 44 行 `方式`／`人類`，人類直接發布的範例改為沒有 Author。
- 新增 GI-51、CR-91，並將 GP-48、CR-68 改為新格式，CR-81 改為舊代發標記案例。

**文件**：README、AGENTS.md 的說明同步。

## Green

- 最後一次 installer 的 exit 為 0，只同步 managed 契約與 4 個 Skill 的安裝副本。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0：test_github_handoff 506 ok，test_change_review 181 ok，test_github_pr_publication 23 ok。
- `openspec validate simplify-github-author-format --strict` 通過；`git diff --check` 通過。

## 盲測重播

做法：新的 subagent 讀契約 §6～§6.7、github-issue／github-pr SKILL 與 change-review 的 Step 6；輸入只有 fixture 與模擬回覆，不讀 references、openspec 與 Work Item。它曾以 grep 列出契約標題，看到 §7～§13 的標題，但沒有讀內容。

| 案例 | 實際輸出或判定 | 與預期 |
| --- | --- | --- |
| C-28 人類直接發布 | 沒有 Author 段落 | 相符 |
| C-29 未知模型、只有 Xirp ID | 工具、`SESSION-ID: null`、`XIRP-SESSION-ID: xirp-9`，省略模型 | 相符 |
| C-47 Agent 代人類發布 | 四種欄位，沒有 `人類` 行 | 相符 |
| C-48 新格式代發 | `原報告作者` 行加上發布者的四種欄位 | 相符 |
| C-49／GI-51 舊格式後追加 | 舊正文不動，新留言只有四種欄位 | 相符 |
| GI-43 Issue 結案 | Closure 的 Author 為四種欄位 | 相符 |
| GP-38 兩個 Session 都缺 | 工具與兩個 `null`，省略模型，不借用他人的值 | 相符 |
| GP-47 PR 準備合併的 Closure | 四種欄位 | 相符 |
| GP-48 代發 Review | `原報告作者`（含其工具與模型）加上發布者欄位 | 相符 |
| GP-49 人類直接回覆 | 沒有 Author 段落 | 相符 |
| CR-68 新格式代發，原作者可核對 | 只通知原實作者 `mgr-123` | 相符 |
| CR-81 舊代發標記 | 不送出 | 相符 |
| CR-91 新格式，只有代發者可核對 | 不送出 | 相符 |

重播提出的模糊處都是案例 fixture 的資料缺口，例如部分案例引用其他案例的前提、`cli-9` 是哪一種 ID 沒有寫明。沒有發現規則上的缺口，因此本輪沒有再修改規則。

## OpenSpec verify

- Completeness：完成本紀錄後為 6/6 tasks；7 項 MODIFIED requirement。
- Correctness：7 項 requirement 都已實作，30 個 scenario 都在契約、Skill 或案例中有對應。
- Coherence：遵循 design 決策 1–4。
- 結果：沒有 CRITICAL 或 WARNING，有 1 項 SUGGESTION：§6.6 與 §6.7 的 Author 寫的是 `<依共用外框>`，依賴 §6 的單一來源。

## 未執行

- 真實的 Issue／PR 建立與留言、Session 通知都沒有執行。
- 歷史貼文沒有任何改寫。
- 重播者與實作者是同一個模型家族。

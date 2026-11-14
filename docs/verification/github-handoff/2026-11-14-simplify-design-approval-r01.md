---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-14-simplify-design-approval-r01
description: simplify-github-design-approval（Issue #17）的 Apply 驗證：Red／Green、installer、12 套檢查、strict validate 與 18 案盲測重播；沒有 GitHub 寫入。
tags: [verification, github-handoff, design-approval]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T15:05:00+08:00" }
sources:
  - id: cases
    resource: template/common/docs/github-handoff.md 附錄 A、github-pr／change-review 的 references/acceptance-cases.md（工作區未提交版本，base b9112e0）
    title: 共同與入口的可重播案例
---

# GitHub 交接驗證紀錄 2026-11-14-simplify-design-approval-r01

## 範圍與版本

- Change：`simplify-github-design-approval`，分支 `feature/simplify-github-design-approval`，base `main` `b9112e0`。
- 受驗內容：`b9112e0` 加上未提交的修改。規劃 artifacts 也是本機未提交檔案；本 Change 沒有 PR。
- 授權：使用者經協調者轉達的明確指示，涵蓋目前 proposal／design／specs／tasks 的實作與驗證，並明確表示本次不需要 PR 批准事件，也不需要確認帳號或記錄者資格。這正好是本 Change 要落實的規則。
- 規劃快照：
  - 協調者提供的 `72a82437…` 無法以已知算法重現。
  - 本 Session 改以逐檔 SHA-256 作為基線（7 個檔案，最後修改時間 14:47:04）。
  - 實作期間 artifacts 只勾選了 tasks，內容沒有修改。
- Skill 調用：`openspec-apply-change`，已安裝 SKILL.md 的 sha256 開頭為 `ed76b497`。調用時間記錄在 job 暫存證據中。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

| 層級 | 狀態 |
| --- | --- |
| 靜態檢查（`tests/test_github_handoff.sh` 的 SDA-1～3 段） | 已執行，通過 |
| 語意（盲測重播） | 18 案已執行 |
| installer（本 repo；臨時 repo 新裝、重裝與入口鏈） | 已執行，通過 |
| GitHub 真實寫入、Session 通知 | **未執行**，也沒有為了測試建立平台批准事件 |

## Red

先擴充 `tests/test_github_handoff.sh`，在舊契約上執行：exit 1，31 項 FAIL，原本的 431 項 ok 不變。失敗原因都是目標行為尚未存在，例如：

- `§4.3 drops the recorder allowlist`
- `§9 no longer requires a PR event before Apply`
- `§6.3 approved_by is optional`
- `shared case for '沒有 PR 事件但已有明確實作指示'`
- `github-pr drops the recorder gate`
- `diagram drops the named-recorder wording`

途中有一項新期待與既有規則「Skill 不重述契約 schema」衝突。處理方式是調整新期待的措辭，並保留既有規則，不刪除。

## 實作

- **契約**：
  - §4.3：授權來自使用者指示，不來自帳號。
  - §6.3：`approved_by` 選填、事件外層採共同外框、實際作者只代表發布帳號，並說明來源種類與時間精度。
  - §9：明確的使用者指示即可 Apply，PR 事件不是必要條件；列出不構成授權與需要釐清的情形，以及新 Session 的接手步驟。
  - §10：第 04 步改寫。
  - 附錄：重寫 C-01～C-04、C-14、C-27；新增 C-37～C-42；fixture 移除記錄者名單。
- **入口**：
  - `openspec-workflow.md` §3。
  - template `AGENTS.md`。
  - github-pr 的 Approval events，以及 GP-45、新增 GP-87。
  - change-review Step 3、checklists，以及 CR-21、新增 CR-70。
  - 交接圖第 04 步。
- **未修改**：上游安裝的 `openspec-apply-change`。

## Green

- 最後一次 `scripts/skills/install.sh` 的 exit 為 0，只更新 managed 目標與兩份 Skill 副本；root `AGENTS.md` 是 seed，維持原狀。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0；test_github_handoff 為 462 ok。
- `openspec validate simplify-github-design-approval --strict`：通過。
- 交接圖第 04 步通過 `xmllint`，以 `rsvg-convert` 渲染後檢視，文字沒有溢出。

## 盲測重播

做法：

- 新的 subagent 只讀契約 §1–§10、github-pr 與 change-review 的 SKILL、`openspec-workflow.md` §3，不讀附錄、case 檔與 openspec。
- 輸入只有 fixture 與模擬回覆。
- 由主 Session 對照各案例的判定。

| 案例 | 實際判定 | 與預期 |
| --- | --- | --- |
| C-01 已發布紀錄跨機器 | 可 Apply | 相符 |
| C-02 來源不明的宣稱 | 不可 | 相符 |
| C-03 技術 pass | 不可 | 相符 |
| C-04 已取代 | 不可，針對 d2 的改變釐清 | 相符 |
| C-14 只有 pass | 不可 | 相符 |
| C-27 repo 權限 | 不可，理由是沒有使用者指示 | 相符 |
| C-37 未知人類帳號 | 可 Apply，不發文 | 相符 |
| C-38 API 帳號不同 | 可發布，省略 `approved_by` | 相符 |
| C-39 交接指示、無 PR 事件 | 可 Apply | 相符 |
| C-40 只建立 Change | 不可 | 相符 |
| C-41 撤回 | 不可，不主動發文 | 相符 |
| C-42 正文自稱 | 不可 | 相符 |
| C-19 gh 不可用改用 MCP | 可 | 相符 |
| C-21 可讀但寫入被拒 | 停止，不換工具 | 相符 |
| C-24 逾時 | 先查核，不重送 | 相符 |
| GP-87 未知帳號的批准紀錄 | 可發布，省略 `approved_by` | 相符 |
| CR-21 作者有權限、沒有指示 | 照常審查，Apply 不成立 | 相符 |
| CR-70 指示涵蓋實作 | 照常審查，授權來源另記 | 相符 |

重播發現四個措辭缺口，已在契約與 github-pr 中補上：

- 事件外層採共同外框。
- 設計在批准版本之後改變時，當前指示必須涵蓋改變的部分。
- 暫停也停止 Apply，只在使用者要求時才發布 `superseded` 事件。
- 發布前先讀既有事件，用來填 `supersedes`。

尚未處理的缺口：

- `artifact_revision` 只在本機時怎麼寫。
- 當下批准的 `approved_at` 用日期還是時間。
- 已知唯讀 token 時是否要在寫入前就停止。
- 逾時後能否改用另一個工具做唯讀查核。

## 接續 improve-change-review-local-handoff 前須核對

- 兩個 Change 的 spec 沒有重疊的 requirement 名稱。
- 共同修改的檔案：
  - `change-review/SKILL.md`：本 Change 只改 Step 3 的批准段落。
  - `references/acceptance-cases.md`：本 Change 改了 fixture 開頭與 CR-21，並新增 CR-70；新案例請從 CR-71 起編號，並保留沒有記錄者名單的 fixture。
  - `checklists.md`：本 Change 改了一列。
- 該 Change 先前只因缺少 PR 批准事件而暫停。本 Change 合併並安裝後，使用者的明確實作指示即可接續。
- 該 Change 的分支 `feature/improve-change-review-local-handoff` 在本輪沒有被修改。

## OpenSpec verify

- Completeness：6/6 tasks。
- Correctness：
  - github-change-handoff 的 2 項 MODIFIED requirement 與 12 個 scenario。
  - github-pr 的 1 項 MODIFIED 與 5 個 scenario。
  - change-review 的 1 項 MODIFIED 與 5 個 scenario。
  - 都在契約、Skill、案例或重播中找到對應。
- Coherence：遵循 design 決策 1–4；規則集中在 repo 擁有的契約，入口只引用。

## 未執行

- 真實的 GitHub 批准事件發布與讀回、Session 通知、branch protection 都沒有實測。
- 重播者與實作者是同一個模型家族。

## 補充：規劃快照指紋已核對（2026-11-14，回應 codex-sgda-r01）

上方「範圍與版本」記載的「`72a82437…` 無法以已知算法重現」保留為當時的歷史說明，原文不改。當時我嘗試的算法是逐檔 SHA-256 或 `shasum` 清單，沒有使用 Reviewer 的算法。

Reviewer 在 codex-sgda-r01 指出的算法如下：

1. 在 Change 根目錄下，依相對路徑排序每個檔案。
2. 依序串接「相對路徑、NUL、檔案內容、NUL」後取 SHA-256。
3. 計算前只把 `tasks.md` 的 `- [x]` 還原成 `- [ ]`。

本 Session 以此算法重算，結果為 `72a824378d8328a8134e1f25e365e72053066199044c90cb338028d4d4a60a8c`，與原授權相同。因此授權時的規劃內容與實作所依據的內容一致，只差在 tasks 的勾選。這個算法之後寫入契約 §6.3，作為 `unpublished-snapshot` 指紋；直接執行契約中的指令也得到同一個值。後續修正見 [r02](2026-11-14-simplify-design-approval-r02.md)。

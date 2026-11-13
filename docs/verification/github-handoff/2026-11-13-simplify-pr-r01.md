---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-13-simplify-pr-r01
description: simplify-github-pr 實作的驗證：create／update／reply／close 四個操作與不寫 Git 的邊界、來源到 PR／Review／Fix 的實際生成與審閱、決策重播、change-review 與批准事件的相容，以及靜態測試與安裝；沒有真實 GitHub 寫入。
tags: [verification, github-handoff]
generated: { by: claude-code/Claude Opus 5.5, at: 2026-11-13T23:10:00+08:00 }
sources:
  - id: cases
    resource: /template/common/skills/github-pr/references/acceptance-cases.md
    title: github-pr 可重播案例 GP-21–GP-65（工作區版本，尚未 commit）
  - id: contract
    resource: /template/common/docs/github-handoff.md
    title: 共用契約第 1–11、13 節與附錄 A
  - id: change
    resource: /openspec/changes/simplify-github-pr/
    title: OpenSpec Change simplify-github-pr
---

# GitHub 交接驗證紀錄 2026-11-13-simplify-pr-r01

## 範圍與授權

- 執行者：Claude Code，模型 Claude Opus 5.5。生成與重播交給五個獨立的子 Agent
  （general-purpose，同一模型）。負責生成的子 Agent 被禁止讀取 `references/`，避免看到參考答案。
- 使用者在 apply 前明確批准了這條邊界：create／update 不 commit、不 push；移除 publish；
  close 不 merge。
- 沒有遠端寫入授權。沒有建立、更新、留言或關閉任何 PR／Issue，也沒有拿 PR #6／Issue #5
  或任何既有紀錄做 close 測試。

## 靜態測試

修改實作之前，先新增檢查並確認失敗（Red）：

| 套件 | 新增或改寫的檢查 | Red（修改前） |
| --- | --- | --- |
| `tests/test_github_handoff.sh` SGP-1 | 四個操作、沒有 publish 操作、§6.2 的 Handoff／Author 框架、`branch` 拼字、`SESSION-ID`、移除 managed／Provenance／design-approval／Reviews／phase／owner、skill 不指示 Git 寫入與 commit writer、整合對話、直接讀 Work Item、3 個來源到內容案例，以及 15 類決策案例 | 35 項 FAIL，`exit 1` |
| SGP-2／SGP-3 | 審查回覆與修正回覆的框架、reply 使用 `gh pr comment` 並綁定 reviewed head、2 個回覆生成案例、批准事件自帶 `status`、§9 不靠正文區塊也能找到批准；close 依序關閉、不 merge、不刪分支、不 reopen，8 類 close 案例，4 種操作各自的「回讀失敗」與「結果不明」案例 | 與 SGP-1 一起：66 行 FAIL |
| `tests/test_change_review.sh` | 以 `github-pr reply` 發布、遠端不再要求完整基線表、保留三種 verdict、Reviewer 不走 create／update／close，也不維護 Review 索引 | 6 項 FAIL |
| 重播後補上 | 連結 tasks 時不列出群組、讀取 reviews 找批准、design pass 提醒 Apply 仍需批准、審查回覆有下一步、已結束的 PR 視為已確認 | 5 項 FAIL |

已依新規格改寫、不再成立的舊斷言：`github-pr defines create publish update` 改為 create update reply close；push 目的地檢查改為「沒有 publish 操作」；`### GP-19` 改為檢查 fork 案例；change-review 的 COMMENT／`commit_id` 改為 `github-pr reply`。這些都換成新的行為檢查，沒有只刪不補。

最後一次執行：`bash scripts/skills/install.sh`（exit 0）之後，11 套 `tests/test_*.sh` 全部 `rc=0`；`openspec validate simplify-github-pr --strict` 為 valid；`openspec doctor` 正常；`git diff --check` 通過。github-pr、change-review、managed 契約與交接 SVG 的安裝副本，都以 `diff -r`／`cmp` 確認與 template 一致；`.codex/` 沒有變更。

## 離線生成：來源 → PR／Review／Fix

來源實文與 GP-30（Work Item、對話新決策、未發布的修改）、GP-31（只有 Change 的設計 PR）、GP-32（只有分支與對話）、GP-40（審查筆記）、GP-41（修正 commit 與測試輸出）相同。

| 輪次 | 指示版本 | A | B | C | D Review | E Fix |
| --- | --- | --- | --- | --- | --- | --- |
| 基準 | 修改前的 skill／契約快照 | 阻擋（要求 Change 與 Issue）；若能進行會 push；正文帶 managed 標記、9 個 `null` 的批准欄位與 Provenance | 阻擋（要求 Issue）；Summary 寫「tasks.md 共 16 項（同步匯出、背景匯出、前端、測試）」 | 阻擋（要求 Change 與 Issue） | — | — |
| 1 | 修改後 | pass | **FAIL**：以一句話列出 tasks 的四個群組 | pass | pass | pass |
| 2 | 最終版本 | — | pass | — | — | — |

### 第 1 輪 A 的產出（未修改）

```markdown
## Handoff

- branch: feature/export-retry
- work-item: WI-20261105-export-retry

## Goal

夜間 02:00 的訂單匯出排程在月底資料量大時會超過 30 分鐘上限而逾時。逾時後整批失敗且不會重試，客服隔天早上拿不到前一日報表，需要人工重跑。

這張 PR 讓排程在逾時或暫時性錯誤時自動重試，全部失敗時通知值班。

不在範圍內：匯出格式、排程時間。

## Implementation

已發布版本 `a3f1c2e`：

- 新增 `jobs/retry.py`：最多嘗試 3 次（`MAX_ATTEMPTS = 3`），每次間隔 10 分鐘（`INTERVAL_SECONDS = 600`）。只對 `TimeoutError` 與 `TransientDBError` 重試，其他錯誤不重試。
- 全部嘗試都失敗時，呼叫 `notify("#ops-oncall", …)` 通知值班頻道。
- `jobs/export_orders.py` 改為透過上述重試機制執行匯出。

重試上限原本規劃為 5 次，已在本次討論中確認改為 3 次，間隔維持 10 分鐘。

## Verification

- CI 在 `a3f1c2e`：`tests/test_export_retry.py` 6 passed。

## Open questions

- 重試會重複寫入同一天的匯出檔案。「同日檔案已存在時的保護」仍在本機修改中，**尚未發布**，不包含在這個版本裡，之後推上同一分支並更新說明。

## Author

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
SESSION-ID: sess-7781
```

審閱：3 次取代紀錄中的 5 次；冪等保護明確標示尚未發布，驗證只列 `a3f1c2e` 的結果；沒有 Sessions、`codex-s02` 或 D-01；Handoff 沒有空欄位。

### 其他產出的審閱重點

- **B（第 2 輪）**：說明這是設計版本，沒有程式碼也沒有測試；附上 5,000 筆門檻的理由；保留未決的 bucket 問題；只以連結指向 `tasks.md`，不列群組或數量。
- **C**：問題、範圍與退路都來自對話；搜尋服務的頻率限制寫成「使用者已確認」，沒有說成是這張 PR 的測試結果。
- **D（Reviewer 回覆）**：寫出 reviewed head `a3f1c2e`、phase、Review-ID 與 changes-required；F-01 寫明影響（只看排程狀態的人發現不了）、位置與證據、完成條件；已檢查與未驗證分開。
- **E（實作者回覆）**：對應到 F-01，列出修正 commit `c4d5e6f` 與 7 passed，明說本機排程檢查沒有重跑、冪等保護仍未發布；請 Reviewer 複審，沒有自行標為 Resolved。

## 離線決策重播

- **第 1 輪**（36 例：GP-21–28、33–38、42–45、50–65，C-01、03、04、06、14、15）：33 例 pass。GP-42、GP-45、C-15 失敗，原因是文字或 fixture 不足，沒有觸發禁止的呼叫。重播另外指出 9 個矛盾：
  - close 遇到已 merged 的 PR 時，與「PR 確認關閉前不關 Issue」互相衝突；
  - 「記錄已取代」被要求先有新的批准；
  - 審查回覆缺少「下一步」與「Apply 仍需人類批准」的提醒；
  - GP-38 與 GP-45 的 fixture 不足；
  - Step 4 沒有讀取 reviews；
  - 遇到並行寫入者時措辭像是要求直接發回覆；
  - 另行授權的 push 與 skill 的措辭有落差。

  這些都已修正，並加上「重播後補上」那 5 項靜態檢查。
- **第 2 輪**（GP-37、42、43、45、59，C-06、15）：全部 pass。剩下的小問題也已處理：C-15 的 fixture 補上使用者的要求；C-06 標明 push 是另行授權、不屬於 `github-pr` 的步驟；§6.2 補上標題規則。之後沒有再重播。

## 需求與證據對照

| 需求（spec） | 證據 |
| --- | --- |
| 來源整合對話的新決策 | 生成 A；SGP-1；skill 的 Step 1 |
| 區分已發布與計畫中的內容 | 生成 A、B；GP-26；skill 的 Step 1 與 Step 4 |
| 精簡框架與選填的關聯 | §6.2；SGP-1；生成 A–C；GP-33 |
| Author 如實記錄 | §6.2；GP-38；C-08、C-09 |
| create 核對已發布的分支，不重複建立 | GP-21–25、GP-28；重播 pass |
| PR 操作不寫 Git | SGP-1；GP-27；C-06（push 為另行授權的步驟） |
| update 保留無關內容 | GP-33–37；§11 |
| reply 提供可交辦的證據 | 生成 D、E；GP-42–44；SGP-2 |
| close 只處理確認的直接 Issue | GP-50–59；SGP-3；重播 pass |
| 每個操作都回讀並查核結果不明的寫入 | GP-60–65；SGP-3 |
| 共用審查與批准的意義不變 | change-review 測試；C-01、03、04、14、15；GP-45 |

`openspec-verify-change` 這個 Skill 本輪**沒有執行**；上表是同等的人工對照，不代表那個 Skill 的評分結果。

## SVG

`template/common/docs/diagrams/github-handoff.svg` 與 change-review 的 `review-loop.svg` 都已用 `rsvg-convert` 實際渲染，人工檢查改過的文字：沒有超出框線，也沒有重疊；`xmllint --noout` 通過。修正步驟 08 的文字之後，只確認 XML 合法，沒有再看一次渲染圖；新字串的長度與原本相近。

## 已知限制

- 真實 GitHub 的 create、update、reply 與 close **都沒有驗證**，需要另外授權一個測試目標。
- `gh api …/compare/<base>...<head-owner>:<branch>` 的 jq 欄位（`ahead_by`、`commits[-1].sha`）沒有在真實 repository 上實跑過。
- change-review 的 CR 案例只改寫了與發布形式相關的部分，本輪沒有逐案重播。
- 上游 `add-github-change-handoff` 與 `add-change-review-skill` 尚未封存；封存本 change 之前，必須依 design Migration Plan 第 5 步調和主規格。

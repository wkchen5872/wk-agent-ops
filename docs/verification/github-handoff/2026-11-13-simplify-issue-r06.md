---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-13-simplify-issue-r06
description: simplify-github-issue 依 review r06 修正後的驗證：來源到內容的品質案例、對話新決策整合、依賴解除條件，以及 C-20 等受影響案例的補重播；含獨立 Agent 實際生成並審閱的 Issue，沒有真實 GitHub 寫入。
tags: [verification, github-handoff]
generated: { by: claude-code/Claude Opus 5.5, at: 2026-11-13T21:10:00+08:00 }
sources:
  - id: cases
    resource: /template/common/skills/github-issue/references/acceptance-cases.md
    title: github-issue 可重播案例，含 GI-35–GI-37 來源到內容案例（工作區版本，尚未 commit）
  - id: r05
    resource: /docs/verification/github-handoff/2026-11-13-simplify-issue-r05.md
    title: 前一輪紀錄（C-20 修正後未重播）
---

# GitHub 交接驗證紀錄 2026-11-13-simplify-issue-r06

本紀錄接續 [r05](2026-11-13-simplify-issue-r05.md)。r05 記載「C-20 修正後未再重播」，
那反映當時的狀態，原文保留不改；本輪補做了重播（見「離線決策重播」）。

## 範圍與授權

- 執行者：Claude Code，模型 Claude Opus 5.5。生成與重播交給四個獨立的子 Agent
  （general-purpose，沿用同一模型），只給它們 skill 與契約；生成的子 Agent 被禁止讀取
  `references/`，避免看到參考答案。
- 處理三項 review finding：（1）來源到內容的品質案例；（2）明確指定來源時仍要整合本輪
  對話的新決策；（3）範例中的依賴解除條件。
- 沒有遠端寫入授權，**沒有**建立 Issue 或留言。

## 靜態契約測試

`tests/test_github_handoff.sh` 新增 SGI-4 共 14 項檢查。每一批都先在修正前執行並得到 FAIL（`exit 1`），之後才修正：

| 批次 | 檢查 | Red |
| --- | --- | --- |
| 1 | 至少 3 個案例具備「來源實文／產出 Issue／內容判定」；有對話新決策的案例；移除只寫「18 項細節任務」的案例；skill 不再寫 `stop at the first that applies`，改為一律整合對話；§6.1 有「不沿用 Work Item 的紀錄格式」；範例的依賴改連到 `/pull/`，不再寫「issues/7 合併」 | 10 項 FAIL |
| 2 | skill 與 §6.1 規定 Tasks 寫可檢查的結果，不照搬實作計畫 | 2 項 FAIL（由生成第 1 輪的 B 失敗引出） |
| 3 | 指定的來源不存在時，停下並在任何遠端呼叫前詢問；§3 允許另一個已配置的工具補足缺少的能力 | 2 項 FAIL（由重播的 GI-22 漏洞與 §3／C-20 不一致引出） |

最後一次執行：`bash scripts/skills/install.sh`（exit 0）之後，`tests/test_*.sh` 共 11 套全部 `rc=0`。`openspec validate simplify-github-issue --strict` 為 valid（25 個 scenarios）。`git diff --check` 通過。template 與 `.claude/skills`、`.agents/skills` 下的 github-issue、change-review，以及 managed 契約，都以 `diff`／`cmp` 確認一致。

靜態測試只證明文字存在、安裝一致，**不證明摘要品質**。摘要品質由下一節的實際生成檢驗。

## 離線生成：來源到內容

來源實文和 GI-35（Work Item 加上對話新決策）、GI-36（只有 Change，含完整 tasks）、GI-37（只有對話）相同。判定依各案例的「內容判定」。

| 輪次 | 指示版本 | A（GI-35） | B（GI-36） | C（GI-37） |
| --- | --- | --- | --- | --- |
| 基準 | 修正前的 skill／契約快照 | **FAIL**：寫成「目前的決策：最多重試 5 次」，漏掉對話已確認的 3 次；保留紀錄式的確認者與日期；沒有完成條件 | **FAIL**：Tasks 是 tasks.md 四個群組（含「測試」）刪短後貼上 | 大致可用，沒有完成條件 |
| 1 | 修正後（Tasks 規則尚未加入） | pass | **FAIL**：仍依同步／背景／前端／測試分組，並列出 export job、物件儲存 | pass |
| 2 | 最終版本 | pass | pass | pass |

### 第 2 輪產出的 Issue（獨立 Agent 生成，未修改）

A，標題「夜間訂單匯出逾時自動重試與失敗通知」：

```markdown
## Handoff

- openspec-change: null
- work-item: WI-20261105-export-retry
- pull-request: null

## Goal

每天 02:00 的訂單匯出排程，在月底資料量大時會超過 30 分鐘的執行上限而逾時。逾時後整批失敗且不會重試，所以客服隔天早上拿不到前一天的報表，要有人手動重跑。

目標是讓暫時性的失敗自動恢復，在有人上班前產出報表；全部重試都失敗時，通知值班人員。

範圍：
- 逾時與暫時性錯誤時自動重試
- 連續失敗時通知

不處理：
- 匯出檔案格式
- 排程時間

## Decisions

- 重試最多 3 次，每次間隔 10 分鐘。原本記錄的是 5 次；使用者在本輪改成 3 次，因為 5 次的最後一次會拖到接近 03:30，而客服在 09:00 上班前還要人工確認。
- 連續失敗時通知值班頻道 #ops-oncall。

## Tasks

- [ ] 匯出逾時或遇到暫時性錯誤時，自動重試最多 3 次，每次間隔 10 分鐘
- [ ] 連續失敗時，在 #ops-oncall 收到通知
- [ ] 匯出格式與排程時間維持不變

## Open questions

- 冪等性：重試可能重複寫入同一天的匯出檔。需要確認匯出是否冪等，尚未結論；這會影響重試能否安全上線。
- 是否為這項工作建立 OpenSpec Change：等冪等問題有結論後決定。

## References

- `work-items/WI-20261105-export-retry/`（local-only，尚未發布）

## Author

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
```

審閱：3 次來自對話中的新決策，5 次只作為被取代的背景出現；問題、影響、範圍與不處理事項都在；冪等列為待確認，並說明它影響什麼；沒有 Sessions、coordinator 或 D-01。可改進處：References 指向一個不會發布的本機 Work Item 路徑，對遠端讀者沒有用處，但已標明 local-only，不算違規。

B，標題「訂單列表匯出 CSV」，Tasks 段落：

```markdown
- [ ] 有「訂單檢視」權限的使用者，可在訂單列表依目前的篩選條件與日期區間匯出 CSV
- [ ] 匯出欄位與順序和列表目前的可見欄位一致，檔名為 `orders-YYYYMMDD-YYYYMMDD.csv`
- [ ] 匯出前列表會顯示筆數提示；5,000 筆以內直接下載
- [ ] 超過 5,000 筆時改在背景產生，期間列表顯示進行中狀態；完成後收到站內通知與 24 小時有效的下載連結，連結過期後無法下載
- [ ] 背景匯出失敗時，使用者會收到通知並可重試
- [ ] 沒有「訂單檢視」權限的使用者無法匯出
```

審閱：從使用者看得到的結果改寫，沒有 tasks.md 的群組、編號或實作步驟；Goal 寫明 5,000 筆門檻的理由，也列出不處理的事項（來自 Non-Goals）；References 標明 local-only。

C，標題「退款建立後 1 分鐘內可在後台搜尋到」：單筆索引更新標為「規劃方向，待確認後定案」，每分鐘排程標為「已否決」；Tasks 是「1 分鐘內可搜尋到」「訂單與會員搜尋不變」；沒有捏造頻率限制的數值或負責人。

## 離線決策重播

- C-13、C-19–C-24、GI-06、GI-17–GI-26、GI-31、GI-32：一個獨立 Agent 依案例的 Fixture 推導，結果除 GI-22 外全部 pass，**C-20 pass**（skill Step 3 已允許改用另一個已配置的工具）。它指出兩個問題：GI-22 只寫「回報」、沒有要求停下；契約 §3 第 4 點與 C-20 不一致。這兩點已修正，並加上第 3 批靜態檢查。
- 修正後由另一個獨立 Agent 重播三個情境：F1（GI-22，指定的 Work Item 不存在）停下並詢問，沒有任何遠端呼叫，也沒有改用分支的 Change；F2（C-20，MCP 缺少留言能力、`gh` 可用）在同一授權內改用 `gh` 重新核對，留言後回讀，回報為留言；F3（C-21，403）停下並回報拒絕，沒有改用 MCP 重送。三者都 pass。

## 已知限制

- **真實 GitHub 的 create 與 comment 都沒有驗證**（沒有授權）。
- 生成與重播都由同一模型家族的子 Agent 執行，是離線的決策證據，不是真實執行結果。
- C-21 的禁止項文字（「換另一個工具重送而不先說明拒絕」）仍與 §3「明確拒絕就停止」的語氣不完全一致；這是既有的共用案例，本輪沒有修改。F3 的實際行為符合 §3。
- 上游 `add-github-change-handoff` 尚未封存，封存前仍須依 design Migration Plan 第 5 步處理。

---
type: Reference
title: change-review 驗證紀錄 2026-11-13-simplify-cr-r01
description: simplify-change-review 的驗證：以 Change／Issue／PR 進入、PR 改為選用、openspec-verify-change 必用、未通過才以 github-pr reply 發布並回讀、核對後通知本機實作者；包含靜態 Red→Green、舊行為基準、四種完整結果的生成審閱與 29 例決策重播；沒有真實遠端寫入或 Session 通知。
tags: [verification, change-review]
generated: { by: claude-code/Claude Opus 5.5, at: 2026-11-13T23:59:00+08:00 }
sources:
  - id: change
    resource: /openspec/changes/simplify-change-review/
    title: OpenSpec Change simplify-change-review
  - id: diagram
    resource: /docs/diagrams/change-review-workflow.svg
    title: 使用者確認的流程圖（設計依據）
---

# change-review 驗證紀錄 2026-11-13-simplify-cr-r01

## 範圍與授權

- 執行者：Claude Code，模型 Claude Opus 5.5。舊行為基準、內容生成與決策重播分別交給三個獨立的子 Agent（general-purpose，同一模型）。
- 使用者以 `/openspec-apply-change simplify-change-review` 要求實作；流程圖在 proposal 中已註明經使用者確認。
- 沒有對 GitHub 寫入，也沒有通知任何 Session；所有 PR、留言與 `xirp` 的結果都來自模擬回覆。
- 工作區中另有其他 Agent 的未追蹤檔案（`docs/verification/github-handoff/2026-11-13-streamline-pr-r02.md`、`test_sand.tmp`），本輪沒有動它們。

## 靜態測試：先 Red 再 Green

修改前，`tests/test_change_review.sh` 的 `rc=1`，共 44 項 FAIL。這些新增的檢查涵蓋：

- PR 與 phase 不再是必要輸入；skill 涵蓋 Change name、Issue URL、`#N`、no PR、unknown、local version。
- verify 必用：checklists 不再寫「有已安裝的 verify 時」，並列出各工具的調用方式與原始分級。
- pass 與無 PR 的結果直接回報；通知對象是實作者的 Author；無法通知時回傳可轉交訊息；尊重 local-only。
- 至少 4 個完整報告案例，以及 23 類矩陣案例。
- skill 自帶的流程圖顯示必用的 verify 與無 PR 分支；README 不再要求 PR 與 phase。

依新規格改寫、不再成立的舊案例：

- CR-01 不再詢問 phase，改為預設實作驗收；
- CR-22、CR-23：沒有 verify 由「改以基線對照」改為 `blocked`；
- CR-31：只有使用者要求時才發布 pass；
- CR-33：改為平台 Review 不可用的情況；
- CR-43、CR-44：pass 直接回報。

既有的 COMMENT、`commit_id` 斷言在前一個 change 已改為 `github-pr reply`。

修改後（每次以 `bash "$t"; rc=$?` 取得結果）：12 套 `tests/test_*.sh` 全部 `rc=0`；`openspec validate simplify-change-review --strict` 與 `git diff --check` 通過；installer 的 rc 為 0；change-review 與 managed 契約的副本都與 template 一致。

## 舊行為基準（修改前的 skill 快照，獨立 Agent）

- **F1**（Change 名稱，只在本機，沒有 PR）：停下，理由是 PR reference 為必填，要求先另外 create PR。
- **F2**（驗收 #7）：先詢問 phase 並等確認；發布後**沒有**通知實作者，即使 `mgr-123` 可以在本機核對。
- **F3**（PR #21，verify 未安裝）：要求補 phase；缺少 verify 時寫「改以基線逐條對照」而不是 blocked。

## 生成審閱：四種完整結果（最終版 skill；子 Agent 不讀參考答案）

| 情境 | 結果 | 審閱重點 |
| --- | --- | --- |
| S1 無 PR | pass | 確認沒有 PR，記錄本機 `c1` 與未提交的 `exports/csv.py`；verify 的原始分級照錄（1 WARNING → F-01，寫明影響與完成條件）；直接回報，沒有發布或通知；`code-review` 標為不適用 |
| S2 PR 失敗可通知 | pass | 在 `a3f1c2e` 的隔離 checkout 驗證；發布前重讀 head；`github-pr reply` 之後回讀留言 901，確認後才以 `xirp session get mgr-123` 核對工具、專案與 `cli-456`，再送出；訊息包含結論、報告 URL、PR 號碼與 URL、head、Finding ID 與要修正的事項；sent 不等於已讀 |
| S3 PR blocked 無法通知 | pass | 區分「沒有缺陷」與「無法判定」，寫明解除條件；回讀確認；兩個 ID 都是 null，回傳可轉交訊息（fixture 沒有給 head，以 `<head>` 代替） |
| S4 PR pass（複驗） | pass | 綁定 `c4d5e6f`，F-01 有修正與測試證據才 Resolved；直接回報，沒有發布或通知 |

S2 的 PR 回覆主體（子 Agent 產出，未修改）：

```markdown
版本：a3f1c2e（implementation）。Review-ID：rev-s01-r01。結論：changes-required。

- [ ] rev-s01-r01/F-01：最後一次重試失敗後，job 仍被標成 success；排程與監控會把失敗的匯出當成成功，只剩通知能讓人發現。
  位置／證據：jobs/export_orders.py 在 notify("#ops-oncall") 之後直接 return；在 a3f1c2e 以強制 timeout 執行排程，job status 為 success。tests/test_export_retry.py 只斷言有送出通知，沒有斷言 job 狀態。完成條件：最後一次重試失敗時 job status 為 failed，且仍送出通知；有一個測試斷言 failed 狀態並通過。
```

## 決策重播（29 例）

CR-01、02、04、06、16、22、23、26、31、33、36、43–59、64 全部 pass。沒有任何一例出現下列行為：

- 要求 PR 或 phase；
- 把查找失敗當成沒有 PR；
- 發布 pass 或無 PR 的結果；
- 在回讀確認前通知；
- 使用未在本機核對的 ID；
- 輪詢或寫入 Git。

重播指出 5 個文字缺口，都已修正：

- **C1**：PR 含多個 Change 時，只透過 Issue 得到的關聯不算選定，必須詢問。
- **C2**：expected-head 不符只回給呼叫者，不發布也不通知。
- **C3**：Reviewer 端造成的 blocked（缺少 skill 或環境）照常發布，但不當成修正要求通知實作者；CR-23、CR-26 的禁止項同步補上。
- **C4**：CR-43、CR-44 的預期呼叫補上 verify；CR-44 的第三輪註明 Apply 仍需人類批准。
- **C5**：CR-46 的 fixture 補上結論、回讀確認與可以通知的前提。

另外，契約 §8 補上「使用者要求時才發布 pass」。修正後已重新安裝並重跑全部套件，但沒有再重播。

## 流程圖

`references/review-loop.svg` 依已確認的 `docs/diagrams/change-review-workflow.svg` 改寫：拿掉「提案」字樣，入口加上 PR，加上圖例，步驟 03 改寫兩個 Session ID。已用 `rsvg-convert` 實際渲染並檢查，沒有溢出或重疊；`xmllint` 通過。修正步驟 03 與圖例的文字之後重新渲染過，但沒有再看一次圖。repo 中的那張討論稿保持不變，也沒有新增 installer 管理的路徑。

## 已知限制

- 沒有真實的 GitHub 回覆、`xirp` 核對或 Session 通知；這些需要另外授權具體的 repository、PR 與 Session。
- `openspec-verify-change`、`code-review`、`ponytail-review` 在本輪的生成與重播中都是模擬結果，沒有在真實的 Change 上調用。
- `openspec-verify-change` 沒有對本 change 執行。
- §6.2 的模板欄位仍叫 `phase`，skill 改稱「purpose」，兩者的意思相同。
- 上游的 change-review 主規格已由其他 Agent 同步。封存本 change 時，必須把「PR 必填」「verify 選用」等條款改寫成 MODIFIED deltas。

# PR 候選範例

本檔供後續更新 `template/common/skills/github-pr/references/examples.md` 時參考，並供 change-review 的回覆案例使用。欄位權威來源為實作後的共用交接契約。本次尚未修改已安裝 Skill。

人名、repo、編號、版本、Session、執行結果全部為虛構。共同情境為 PR #57「新增訂單 CSV 匯出」、Issue #42、Change `add-order-export`。實作初版為 b2c3d4e，修正後為 d4e5f6a。F-01 的原始 ID 在後續輪次保持相同。此案例已確認單次最多 5,000 筆。

## 建立 PR

初版已 commit 與 push，標題為「新增訂單 CSV 匯出」。

```markdown
## Handoff

- branch: feature/add-order-export
- openspec-change: add-order-export
- issue: https://github.com/acme/widgets/issues/42
- work-item: WI-20261114-order-export（local-only）

## Summary

客服逐筆複製資料容易漏項，本次提供依日期區間下載訂單 CSV 的功能。

## Changes

- 匯出訂單編號、日期、金額與狀態。
- 空資料區間仍提供欄位標題。
- 單次最多 5,000 筆，超過時回傳明確訊息。

## Verification

發布版本為 b2c3d4e。日期篩選、空資料與上限測試通過。尚待 Reviewer 獨立檢查權限與實作。

## Next actions

Reviewer 對 b2c3d4e 檢查權限與上述驗收條件。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## Review 發現問題

github-pr reply 新增一則 Review 留言。

```markdown
## Handoff

- pull-request: https://github.com/acme/widgets/pull/57
- branch: feature/add-order-export

## Review

- reviewed-head: b2c3d4e
- review-id: reviewer-b-r01
- result: changes-required

### reviewer-b-r01/F-01

未授權使用者仍可直接呼叫匯出 API，可能取得無權檢視的資料。
位置為 src/orders/export.ts。完成條件為未授權請求回傳 403，並有對應測試。

## Verification

已重現未授權請求取得 CSV。既有日期篩選、空資料與上限測試通過。

## Next actions

實作者修正 F-01，Push 後回覆修正版本與測試證據，再交回 Reviewer。

## Author

方式: Agent 協助
人類: @kai
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-review-session
XIRP-SESSION-ID: example-xirp-review
```

## 實作者回覆修正

修正版本已 push，既有 Review 留言保留。

```markdown
## Handoff

- pull-request: https://github.com/acme/widgets/pull/57
- branch: feature/add-order-export

## Changes

### reviewer-b-r01/F-01

已在匯出 API 加入既有訂單檢視權限檢查。修正版本為 d4e5f6a。
未授權回傳 403，有權限可正常匯出。新增權限測試與既有匯出測試均通過。
目前為已修正、待 Reviewer 複審。

## Next actions

Reviewer 對 d4e5f6a 複審 F-01 與受影響行為。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 複審通過

遠端 pass 也發到同一 PR。這個結果只涵蓋所列版本與範圍。

```markdown
## Handoff

- pull-request: https://github.com/acme/widgets/pull/57
- branch: feature/add-order-export

## Review

- reviewed-head: d4e5f6a
- review-id: reviewer-b-r02
- result: pass

### reviewer-b-r01/F-01

狀態為 Resolved，已確認未授權請求被拒絕，有權限者仍可匯出。

## Verification

已檢查權限、日期篩選、空資料及 5,000 筆上限，相關測試通過。原範圍內無阻擋問題。

## Next actions

交由負責人進行交付整理。產生新版本時補上對應差異複審。

## Author

方式: Agent 協助
人類: @kai
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-review-session
XIRP-SESSION-ID: example-xirp-review
```

## 更新 PR 說明

update 修改已授權的正文段落，保留無關人類註記與所有歷史留言。以下為完整的精簡正文。

```markdown
## Handoff

- branch: feature/add-order-export
- openspec-change: add-order-export
- issue: https://github.com/acme/widgets/issues/42

## Summary

提供指定日期區間、最多 5,000 筆訂單 CSV 匯出。

## Changes

日期區間、空資料與上限行為已完成，並修正未授權使用者可匯出的問題。

## Verification

發布版本為 d4e5f6a，日期、權限、空資料及上限測試通過。Reviewer 已在 reviewer-b-r02 對該版本回覆 pass。

## Next actions

完成交付整理與最終版本確認後，交由負責人依授權合併。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 暫停時的 Checkpoint

進行接手摘要，不重貼每輪 Findings 全文。

```markdown
## Handoff

- pull-request: https://github.com/acme/widgets/pull/57
- branch: feature/add-order-export
- openspec-change: add-order-export

## Checkpoint

### Current state
發布版本為 d4e5f6a，實作複審通過，尚未完成交付整理及合併。

### Confirmed results
F-01 已複審為 Resolved，證據見 reviewer-b-r02。

### Open questions
原範圍內無未決事項，額外背景匯出提案見 Issue #63。

## Next actions

接手者確認目前 head 及後續留言，再完成交付整理。新增 commit 後安排差異複審。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 成功交付的 Closure 回覆

假設 d4e5f6a 已是完成交付整理後的最終受審版本。以 reply 發布摘要，merge 由既有授權流程處理。

```markdown
## Handoff

- pull-request: https://github.com/acme/widgets/pull/57
- branch: feature/add-order-export
- issue: https://github.com/acme/widgets/issues/42

## Closure

### Outcome
最終受審版本為 d4e5f6a，準備合併。

### Delivered
完成日期區間 CSV 匯出、權限檢查、空資料與上限行為及必要文件。

### Verification
最終版本測試與 Review 通過，F-01 已 Resolved。證據見 reviewer-b-r02。

### Remaining work
原範圍內無未完成項目。額外提案見 Issue #63。

## Next actions

負責人依授權合併 PR，並核對 Issue #42 的完成條件後另行結案。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 放棄方案的 Closure 回覆

這是與成功合併互斥的替代案例。使用者已授權關閉 PR #57。先發布及回讀摘要，再 close PR。

```markdown
## Handoff

- pull-request: https://github.com/acme/widgets/pull/57
- branch: feature/add-order-export
- issue: https://github.com/acme/widgets/issues/42

## Closure

### Outcome
本方案由 PR #61 取代，準備關閉本 PR，保留分支。

### Result
後續採用既有報表匯出介面，避免增加另一套維護路徑。

### Verification
本 PR 未合併。現有 Review 只對本方案的受審版本有效。

### Remaining work
Issue #42 仍需完成，由 PR #61 接續。此次不關閉 Issue。

## Next actions

關閉 PR #57，後續 Review 接續於 PR #61。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 代發報告的作者來源

保留原報告的作者及可公開來源，另列本輪發布者。原作者的工具、模型與 Session 只能取自其明確提供的紀錄。摘要整合多份來源時，以 References 指向來源，避免宣稱單一來源作者完成所有內容。

```markdown
## Author

原報告作者: @kai，來源為已核對的 Review 報告連結
方式: Agent 協助代發
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-publisher-session
XIRP-SESSION-ID: null
```

## 結案讀回與部分失敗

- PR close 成功並回讀 CLOSED，回報摘要 URL 與實際狀態。Issue 仍維持原狀。
- close 遭拒或結果不明，回報摘要已確認、PR 狀態未確認或仍為 OPEN，查清楚後再接續。
- 目標已 MERGED，保留實際狀態。若使用者要求補摘要，記錄已合併的證據，不再次 close。
- 模型未知時省略 AI-Assisted-By。原生與管理 ID 各自未知則各自 null，回報實際查詢限制。

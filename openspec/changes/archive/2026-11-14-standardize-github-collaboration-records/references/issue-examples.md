# Issue 候選範例

本檔供後續更新 `template/common/skills/github-issue/references/examples.md` 時參考。欄位權威來源為實作後的共用交接契約。本次尚未修改已安裝 Skill。

以下人名、repo、編號、版本、Session、測試與驗收結果全部為虛構。共同情境為 Issue #42「新增訂單 CSV 匯出」、PR #57、Change `add-order-export`。a1b2c3d 是設計草案，d4e5f6a 是修正後實作。正式發布優先使用已查核的遠端 URL。

## 建立 Issue

情境為需求已討論一部分，準備跨成員交接。標題為「新增訂單 CSV 匯出功能」。

```markdown
## Handoff

- openspec-change: add-order-export
- branch: feature/add-order-export
- work-item: WI-20261114-order-export（local-only）

## Goal

客服目前逐筆複製訂單，整理大量資料時容易漏項。希望有訂單檢視權限的使用者，能依日期區間匯出 CSV。本次涵蓋訂單基本資料，付款明細與附件另行處理。

## Acceptance criteria

- 可以下載指定日期區間的 CSV。
- 欄位包含訂單編號、日期、金額與狀態。
- 沒有訂單檢視權限的使用者無法匯出。
- 空資料區間仍可取得含欄位標題的 CSV。

## Checkpoint

### Current state
設計草案已發布於 a1b2c3d，尚未實作及建立 PR。

### Confirmed decisions
採 CSV，沿用既有的訂單檢視權限。

### Open questions
需確認一般匯出資料量，再決定大量資料的處理方式。

## Next actions

@mei 提供常見資料量，設計負責人補齊限制與驗收方式後安排設計審查。

## References

- 規格草案位於 feature/add-order-export 的 openspec/changes/add-order-export/，版本 a1b2c3d。
- 本地討論位於 work-items/WI-20261114-order-export/，僅供原工作環境查閱。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-planning-session
XIRP-SESSION-ID: example-xirp-planning
```

## 追加進度或回覆

update 新增一則留言，原始正文與舊留言保留。

```markdown
## Handoff

- issue: https://github.com/acme/widgets/issues/42
- openspec-change: add-order-export
- pull-request: https://github.com/acme/widgets/pull/57

## Changes

已確認單次支援 5,000 筆，超過時回傳明確訊息。此限制已納入設計並取得人類確認。PR #57 已發布初版，正在等待權限與日期篩選 Review。

## Next actions

Reviewer 對 PR #57 的發布版本檢查上述驗收條件。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 換人時的 Checkpoint

已有多輪留言，需要讓另一個環境接手。讀取時仍需核對此留言之後的事件及目前版本。

```markdown
## Handoff

- issue: https://github.com/acme/widgets/issues/42
- openspec-change: add-order-export
- pull-request: https://github.com/acme/widgets/pull/57

## Checkpoint

### Current state
實作已發布至 d4e5f6a，權限問題已修正並通過複審，尚未合併。

### Confirmed results
日期篩選、空資料及權限測試通過。單次上限為 5,000 筆。證據見 PR #57 的 reviewer-b-r02 回覆。

### Open questions
原範圍內無未決需求。高於上限的背景匯出為額外提案，追蹤於 Issue #63。

## Next actions

接手者核對目前 head 及後續留言，再由負責人完成交付整理與授權的合併操作。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 完成結案摘要

此例假設 PR 已合併且原範圍驗收有證據。先新增並回讀摘要，再將 Issue 以 completed 關閉並回讀。

```markdown
## Handoff

- issue: https://github.com/acme/widgets/issues/42
- pull-request: https://github.com/acme/widgets/pull/57
- openspec-change: add-order-export

## Closure

### Outcome
原範圍已完成，準備以 completed 關閉。

### Result
客服可以匯出最多 5,000 筆指定日期區間的訂單 CSV，權限沿用訂單檢視權限。

### Acceptance
已驗證欄位、日期區間、空資料、上限及未授權拒絕。證據見 PR #57 的最終驗證回覆。該 PR 已合併。

### Remaining work
原範圍內無未完成事項。超過上限的背景匯出提案由 Issue #63 追蹤。

## Next actions

關閉本 Issue，額外提案接續於 #63。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 取消結案摘要

這是另一個取消情境，與前述完成案例互斥。close reason 使用 not planned。

```markdown
## Handoff

- issue: https://github.com/acme/widgets/issues/42

## Closure

### Outcome
使用者已取消本需求，準備以 not planned 關閉。

### Result
團隊決定沿用既有報表，不新增 CSV 匯出。

### Remaining work
PR #57 仍需負責人另外決定是否關閉，此次 Issue close 不操作該 PR。

## Next actions

關閉本 Issue，將 PR #57 的處置交給負責人確認。

## Author

方式: Agent 協助
人類: @mei
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: example-impl-session
XIRP-SESSION-ID: example-xirp-impl
```

## 人類直接建立的最小案例

沒有 OpenSpec 或 branch 的初步問題，也能由人類發布。

```markdown
## Handoff

目前尚無 Change、branch 或 PR 關聯。

## Goal

客服發現跨月查詢結果與月報不同，請協助確認日期邊界是否一致。

## Next actions

@mei 補上可重現的日期區間與已去識別化資料。

## Author

方式: 人類直接發布
人類: @mei
```

## 模型與 Session 無法取得

Agent 已查核可用來源但模型未知、沒有原生 ID，只有已確認的 Xirp ID。省略模型，原生 ID 寫 null，操作回報說明查核限制。

```markdown
## Author

方式: Agent 協助
Co-Authored-By: Codex
SESSION-ID: null
XIRP-SESSION-ID: example-xirp-planning
```

## 摘要成功但 close 失敗

已回讀 Closure 留言後，狀態操作遭拒。操作回報寫「摘要已發布，Issue 仍為 OPEN，關閉失敗」，附已確認的留言 URL。重試先查目前 state、reason 與摘要是否仍適用，再執行缺少且仍獲授權的操作。摘要中原本的「準備關閉」不改寫為成功。

# github-issue 範例

範本與規則見 `docs/github-handoff.md` 第 6.1 節；這裡只示範如何依內容整理。範例中的
編號、日期與名稱都是虛構的。

## Change 與 Work Item 一起登錄

來源是 `add-export` 與 `WI-20261101-export`。Goal 讓只讀 Issue 的人看懂問題與預期結果，
Tasks 只列有意義的完成條件，不搬 `tasks.md`；規格尚未 push，所以 References 標明
local-only：

```markdown
## Handoff

- openspec-change: add-export
- work-item: WI-20261101-export
- pull-request: null

## Goal

客服目前只能逐筆複製訂單資料。新增 CSV 匯出，讓客服依日期區間下載訂單，檔名帶日期，
欄位與後台列表一致。

## Tasks

- [ ] 依日期區間匯出 CSV，欄位與列表一致
- [ ] 大量資料時以背景工作產生，完成後通知
- [ ] 匯出權限沿用既有的訂單檢視權限

## References

- `openspec/changes/add-export/`（local-only，尚未發布）

## Author

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
```

## Session-only，包含依賴與未決事項

沒有 Work Item 或 Change，內容來自本次 Session 的討論。三個 Handoff 欄位都是 `null`；
中間段落依工作調整，沒有 Tasks／References 可寫就省略：

```markdown
## Handoff

- openspec-change: null
- work-item: null
- pull-request: null

## Goal

夜間匯出排程在資料量大時逾時，整批失敗且不會重試。目標是逾時的批次自動重試，
連續失敗才通知值班人員。

## Dependencies

- 等 https://github.com/acme/widgets/pull/12 合併後再開始：重試要沿用 PR #12 引入的新匯出格式；PR #12 合併即解除，不需等部署。

## Open questions

- 重試次數與間隔尚未決定。

## Author

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
```

模型無法確認時省略 `AI-Assisted-By` 那一行，並在回報中說明。

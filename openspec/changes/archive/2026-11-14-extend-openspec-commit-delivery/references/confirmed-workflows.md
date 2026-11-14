# 已確認的本機四流程

此檔是正式文件與圖稿遷移的自足輸入，不要求取得原始對話或 ignored Work Item。使用者於 2026-11-14 確認以下流程。這份確認不代表全部整合已實作，也不授權立即對 GitHub 寫入。

| 流程 | 主路徑 | 分支與輸出 |
| --- | --- | --- |
| 開立規格 | 需求／Bug 討論 → 必要的本地協作 → 準備工作分支 → openspec-ff-change → 人工確認規格與後續動作 | Issue 按需要建立；是否發布設計 PR 由人類決定，團隊要求遠端設計批准時先完成該步。輸出 Change、分支、已確認範圍與授權。 |
| 實作與發布 | 取得已確認設計 → openspec-apply-change 與測試 → 本地 verify → 人工發布檢核 | 選擇發布才處理必要 commit／push，建立 Draft PR 或更新同工作的既有 PR；暫不發布也能進入本地 Review。驗證失敗回實作。 |
| Review 與交接 | 指定 Change／Issue／PR → 固定受審內容 → openspec-verify-change、適用品質審查與必要測試 → 保存報告 → 有 PR 時 reply／回讀 | pass 交給交付整理；changes-required 交實作者；blocked 補必要證據。修正、發布及回覆後，再明確啟動新一輪。無 PR 正常回報本地結果，不自動補建 PR。 |
| 封存交付 | 已驗收 Change 與當次範圍 → openspec-archive-change → doc-updater → git-commit-writer → 依授權處理遠端交付 | 成功版本需確認最終 head 與 Review，Closure 後等待另外授權的 merge；取消／被取代才委派 PR close。Issue 另依原範圍驗收及授權結案。 |

前兩流程不新增 workflow skill。第三流程沿用 change-review；本次之外的 Review 優化可獨立進行。第四流程前半既有，後半由本 Change 實作。每張圖標示已確認流程、主要呼叫、人工檢核點、停止／回復條件與交接產物，保留手機 PNG。

正式落點為 repo 自有 `docs/workflow/local-development.md` 與 `docs/diagrams/local-development-{define,implement,review,finish}.{svg,png}`，不要求 installer 對其他 repo 部署個人流程。搬遷不刪除原 Work Item。共用 GitHub 格式直接連 managed github-handoff 契約，不另複製一套欄位。

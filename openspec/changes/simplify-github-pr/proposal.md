# Proposal

## Why

現行 github-pr 強制綁定 Change、Issue 與大量交接欄位，並混合 commit、push、正文更新及批准紀錄。需要把 Work Item、Change、branch 與 Session 當作素材，整理成沒有參與原對話的人也能理解的 PR，並提供清楚的 Review／Fix 回覆及關閉流程。

## What Changes

- 三組功能、四個操作：`create`／`update` 維護 PR 說明，`reply` 新增 Review／Fix 等回報，`close` 關閉 PR 及確認直接對應的 Issue。
- 支援指定 Work Item、Change 或兩者；未指定時確認目前分支的關聯與實際內容，一律整合相關 Session。沒有本機紀錄也可建立 PR，但仍須有可用的已發布分支差異。
- 正文與回覆採 `Handoff → 工作主體 → Author`；使用正確的 `branch` 欄位。可選關聯有才列，之後可補入；主體重組為可理解的工作、可檢查結果與未決事項，不搬內部紀錄格式。
- Author 記錄本次執行工具、已知模型與可確認的 Session ID；未知值不猜測，不把其他 Agent 或來源作者當貼文者。
- **BREAKING**：提案預設 create／update 不自動 commit 或 push，移除 `publish` 操作及 commit-writer 委派；呼叫者須另行發布分支，舊操作不能默默映射成 Git 寫入。
- **BREAKING**：PR 不再強制 managed markers、完整 provenance、Review 索引或正文的批准欄位；保留人工文字與歷史留言。正式設計批准仍是可另外記錄並驗證的事件，不由技術 pass 推導。
- `reply` 支援精簡的 Review／Changes 與逐項 task／todo：保留被審查版本、具體問題、修正 commit、已執行檢查與限制，避免狀態與證據失真。
- **BREAKING**：新增 close，定義為關閉而非 merge。只關直接對應的 Issue，不處理依賴或參考項目；逐項回讀，部分成功可續做，不刪除分支。

## Capabilities

### New Capabilities

- `github-pr`: PR 來源整理、精簡正文與回覆、版本核對，以及 PR／直接對應 Issue 的關閉契約。

### Modified Capabilities

無目前主規格中的 capability 需要直接修改。舊行為位於待封存 `add-github-change-handoff` 的 `github-change-handoff` 與 `add-change-review-skill` 的 `change-review` deltas；本 change 明確替換其 PR 操作、遠端呈現與正文耦合要求，保留審查判斷及授權語意。封存前須調和相同主規格，不能讓相反條款同時生效，亦不在此次 ff 改寫上游 artifacts。

## Impact

- template github-pr skill、其 acceptance cases／examples；共用 `github-handoff.md` 與流程 SVG；change-review 的發布格式、案例、檢查清單與必要圖文引用。
- README、AGENTS、architecture、受影響的共用 workflow／rule／Work Item 說明，以及 `tests/test_github_handoff.sh`、`tests/test_change_review.sh`；只改受影響部分。
- 實作後依 installer 同步 Claude Code、Codex 共用入口與 Antigravity；不手改安裝副本、不新增 GitHub client、wrapper 或背景同步。
- 不更動已完成的 github-issue 正文／更新語意；不在本次規劃中修改或關閉任何現有 Issue／PR。
- Work Item 規範只管理本機紀錄，移除其中 GitHub 交接小節；GitHub 契約自行定義遠端 Finding 語意，skills 僅單向讀取 Work Item 素材，不反向要求欄位或發布流程。
- 驗收必須包含完整來源到 PR、Review、Fix 的生成結果及不合格對照，也涵蓋後補關聯、來源與遠端差異、fork、舊正文、重複建立、close 歧義與部分失敗。文字存在測試不能代替內容或實際操作驗證。

本次規劃採「PR 操作不自動 commit／push、close 不 merge」作為明示的提案設計，尚未代表使用者批准實作；其餘流程依本 change 的 design 與 tasks review 後執行。

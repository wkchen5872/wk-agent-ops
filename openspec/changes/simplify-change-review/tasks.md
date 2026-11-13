# Tasks

## 1. 入口解析與有無 PR 的分流

- [ ] 1.1 先補 Change／Issue URL／#N／直接 PR 的完整來源 fixtures 與聚焦檢查，取得舊 skill 的有效 Red／舊行為基準，再修改 template 入口與對應使用文件。測試要求：涵蓋有／無 PR、查找 unknown、repo 不明、多個 Change／PR、Issue 無 Change、Work Item 缺少；不得任選候選、要求建立追蹤資料或把失敗查找視為無 PR。保存實際輸入、產出與調用序列，說明被新行為取代的舊斷言。
- [ ] 1.2 將有 PR 的 head／diff／修正留言核對與無 PR 的本機版本記錄整合成精簡 workflow，更新相關案例及版本說明。測試要求：本機 dirty 與遠端不同、expected-head 不符、head 移動、PR 多範圍；必要檢查只對實際受測版本回報，不能 stash／reset 他人的工作，也不能把本機修正證明為已發布。

## 2. 必要驗證與品質技能調度

- [ ] 2.1 先新增 verify 必用、目的適用性與選用技能矩陣的 Red，再修改 skill／checklists 的調度與相關跨工具說明，刪除重複驗證流程。測試要求：實際調用 openspec-verify-change 並保留原始 grading；缺少必用技能為 blocked；選用插件缺少不單獨阻擋，PR-only 插件不硬套無 PR；Codex／Claude Code／Antigravity 使用可用調用機制，不能只列命令冒充執行；明確設計審查不因未勾實作 tasks 單獨失敗。
- [ ] 2.2 整合 Review、驗收與必要測試的結果，精簡 checklists 並新增完整報告／失敗對照範例。測試要求：無 PR 報告、PR pass、具體 defect、必要測試不可跑與 pending 真實資料等結果；讀者不依賴 Work Item 也懂問題與下一步；保留 scope／版本／檢查／限制，沒有證據不算 pass，不製造 filler tasks。

## 3. PR 回覆與本機修正交接

- [ ] 3.1 為 failed／blocked 預設 reply、pass 直接回報與 local-only 限制補有效 Red，修改 skill、必要 shared contract 及相關文件。測試要求：有 PR 且未通過只走 github-pr reply；回讀 parent／repo／reviewed head／完整內容與 URL 後才算 confirmed；正文與舊留言不變；403、timeout、回讀失敗或內容不符時分開報告 publication，先查核、不盲目重送，不提前通知。
- [ ] 3.2 補 Author 選取與本機 Session 核對的 fixtures／Red，再實作只用現有 session 技能／工具的通知交接，更新使用與限制說明。測試要求：實作 Author 與最新 Reviewer Author 不同、Co-Authored-By 工具與 SESSION-ID、null／缺少欄位、多位實作者、native／管理 ID 映射、本機同專案可達、非本機／session 已消失／工具不可用；不得猜 ID、通知錯人、啟動第二個 writer 或上傳私有紀錄。
- [ ] 3.3 完成本輪結束與修正後複驗的流程及完整交接範例。測試要求：確認 PR reply 在通知之前；訊息具 Review 結果與報告 URL、PR 號碼／URL、版本、Finding IDs 及修正要求；sent 不等於已讀或已修；不能通知時回傳可轉交訊息；明示不通知優先；一次一輪不輪詢，複驗以 fixing revision／測試核對原 finding，不能從實作者聲稱直接 Resolved。

## 4. 圖稿、安裝與整體驗收

- [ ] 4.1 依已確認的 repo 流程圖更新 skill 內 `references/review-loop.svg` 與連結，完成 README、AGENTS、architecture、shared contract 和現行 callers 的受影響說明。測試要求：搜尋不再將 PR／phase 列為每次必填、不再聲稱 verify 選用或所有結果都必貼 PR；跨檔連結可達，SVG 實際渲染檢視；下游不依賴 repo-only 圖稿，不增 installer 目標、不改 Work Item policy，歷史驗證紀錄保留原樣。
- [ ] 4.2 執行既有 installer，同步 template 與受管理副本並完成整體回歸。測試要求：tests/test_change_review.sh、受影響 github-handoff／Work Item 套件與全部必要 tests exit 0；installer 可重跑、無關第三方內容保留、所有 managed 副本一致；openspec strict validate 與 git diff --check 通過，不手改安裝副本。
- [ ] 4.3 以最終版 skill 重新生成無 PR、PR 失敗可通知、PR blocked 無法通知、pass 四種完整結果，重播調度、版本與失敗分支，保存正式驗收紀錄。測試要求：逐項審閱摘要品質、必要技能真實執行、回覆與通知順序、已執行／未驗證界線、跨輪 finding；獲具體目標授權才做真實遠端／跨 session 測試，不杜撰遠端結果；未測分支明列，不把上游案例的通過當成本 skill 已驗收。

## Workflow follow-up

- 使用者已確認討論流程圖；本次 ff 只將其轉成規劃，實作依這份 design 與 tasks 接續，不自動開始 apply。
- 封存前檢查 add-change-review-skill、simplify-github-pr 與當時主規格的同步狀態；依既有授權流程處理上游，再將此 capability deltas 與 proposal 調和，保留未被取代的既有需求，避免相反規則同時生效。
- 真實 GitHub／session 驗收只使用另行授權的精確目標；此次規劃不授權修改既有 PR／Issue、通知指定 session 或啟動修正。
- Archive、commit、push 與發布 PR 依後續交付要求處理，不由本次 ff 自動執行。

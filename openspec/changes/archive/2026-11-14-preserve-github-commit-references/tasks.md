# Tasks

## 1. Writer 引用政策與跨工具一致性

- [x] 1.1 在現有 commit 契約測試補上 references 輸入、Refs 排版、跨 repo、去重、無關聯／歧義及不重寫歷史的期待，固定 Agent replay 輸入與預期。測試要求：先記錄符合新需求缺失的 Red（命令、案例、exit code、最小輸出），不能把環境失敗當 Red。
- [x] 1.2 修改 template 的 git-commit-writer Skill 與 Claude／Codex commit agents，依設計接受直接關聯與證據、輸出標準引用，保留原有 archive guard、Conventional Commits 與 tool/model attribution。同步 writer 範例及驗收案例。測試要求：focused assertions Green；以 disposable Git repo 的實際 commit message 或 Agent replay 驗證 Issue-only、Issue+PR、複數直接 Issue、跨 repo 同號、重複及缺值，分別記錄自動化與回放結果。

## 2. Caller 交接與 publication 邊界

- [x] 2.1 為 openspec-commit 的委派清單與缺值／離線／恢復案例先補 Red，再修改 template Step 5 與範例，保留 archive/docs/context/provider routing。測試要求：test_openspec_commit.sh 通過；replay 證明已知編號交接不遺失、無 metadata 不要求登入、既有 commit 不 amend。
- [x] 2.2 為 github-pr create 的直接 scoped commit 引用與首次 PR 未知編號先補 Red，再更新 template Skill、範例及 acceptance cases；必要時僅補 shared handoff 的政策連結。測試要求：test_github_pr_publication.sh 與 test_github_handoff.sh 通過；disposable Git／replay 驗證混合 staging 保留、首次 PR 不猜號、已有 commit 沿用及 update/reply/close 無 commit。

## 3. 安裝與整體驗收

- [x] 3.1 執行 installer 並核對來源與受管理副本，更新必要的 README／AGENTS／相關文件。測試要求：Claude、Codex、Antigravity 對應入口與 template 一致；installer 新裝／重裝相關測試通過，沒有手改 installed 配置。
- [x] 3.2 完成 design 中的全套語意回放及既有流程回歸，提交可讀的正式驗證紀錄。測試要求：逐案記錄輸入、預期、實際結果與證據；背景 #13/#17 不誤列、#17 不要求本人帳號、#13 本地 Review 可運作、#18 Author 不回退；未實測路徑明示，不把靜態 grep 或回放當完整線上驗收。
- [x] 3.3 進行最終 OpenSpec verify 與整體 checks，依結果更新 task 狀態。測試要求：執行全部 tests/test_*.sh、本 Change strict validate、git diff --check；所有失敗有處理或明確阻擋紀錄，未通過不得宣稱完成。

## Workflow follow-up

- 目前僅建立規劃，實作須待使用者檢查設計後明確指示。
- 驗收通過後，僅在另有授權的範圍內進行 archive、spec sync、commit、PR 發布、merge 與 Issue 結案；不將規劃完成視為交付完成。
- #13 與 #17 已完成的實作不重做；其尚未關閉的 GitHub 狀態另依既有驗收及結案授權處理。

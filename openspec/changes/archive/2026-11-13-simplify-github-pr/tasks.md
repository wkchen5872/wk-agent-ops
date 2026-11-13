# Tasks

## 1. 來源與正文整理

- [x] 1.1 在 github-pr references 建立三組完整來源到內容 fixtures 與失敗對照，先以舊 skill 取得內容基準，並補有效 Red。測試要求：涵蓋 WI／Change／branch／Session、舊紀錄 5 次被對話新決策 3 次取代、remote diff 與本機未發布內容不同、沒有追蹤資料；每例包含來源實文、實際完整產出、可檢查內容判準，不以 ID 或章節存在代替摘要品質。
- [x] 1.2 修改 template github-pr 與共用契約的 create／update、Handoff／Author 及來源整合規則，刪除 publish 與自動 Git 發布委派，補精簡 examples。測試要求：先補四個操作、無 Git 寫入、optional associations、branch 拼字、模型／Session 未知值與 fork 核對的聚焦檢查，再使之 Green；舊 publish 呼叫只回報新邊界，無 commit／push。
- [x] 1.3 完成 create／update 的既有 PR 與正文相容處理，並補後續關聯的例子。測試要求：重播唯一／多個 PR、同名 fork、缺 remote／空 diff、設計-only、dirty checkout、plain body／legacy markers／人工附註、並行 writer 與後補 Issue；確認無重複建立、無空 commit、未發布結果不被寫完成、人工文字逐字保留。

## 2. Review／Fix reply 與批准相容

- [x] 2.1 補 reply 的內容與副作用 Red／生成案例，再實作頂層留言操作及唯一共用模板。測試要求：由具體 defect 產出帶實際 reviewed head、影響、證據、完成條件、checks／limits 的 Review；由 fix commit 與測試輸出產出逐項 Changes，明示剩餘事項，不假造測試、不替 Reviewer 提前 Resolved；既有留言不變，回讀 parent PR／repo／內容及 URL。
- [x] 2.2 同步 change-review 的發布路徑、案例、檢查清單與必要圖文，保留審查與 finding 語意，移除大型遠端格式及正文 Review 索引的強制要求。測試要求：`tests/test_change_review.sh` 先新增 reply 發布、head 變更仍綁原版本、pass／blocked／changes-required 及穩定 finding ID 的檢查，再 Green；Reviewer 不觸發 create／update／close／Git 寫入。
- [x] 2.3 調整共用批准事件的發布與查找，支援沒有正文 approval block 的新 PR 並保留舊 source_ref。測試要求：聚焦案例先 Red，涵蓋有明確授權的代記、未授權作者、未知時間精度、不同 artifact revision、superseded event；讀實際留言作者，不以技術 pass 或正文改寫產生批准。

## 3. Close 與結果查核

- [x] 3.1 補 close 的明確範圍與部分失敗 Red／重播案例，再實作 template close 指令與文件。測試要求：先建立 PR／直接 Issue／依賴清單，確認 PR 關閉後才關直接 Issue；涵蓋 A 對應與 B 依賴、無 Issue、歧義、多個直接 Issue、PR close 失敗或回讀不明、Issue 部分失敗、已 closed／merged 重跑；禁止 merge、刪 branch、連帶關依賴、重做已完成動作或把關閉說成驗收完成。
- [x] 3.2 統一 create／update／reply／close 的目標、能力、拒絕、逾時及回讀行為，更新相關 shared acceptance cases。測試要求：每種操作皆有 success／readback-failed／uncertain 的預期呼叫與禁止副作用；回讀前不能報 confirmed，權限拒絕不換認證重送，多步操作逐項報告，測試套件轉 Green。

## 4. 文件、安裝與整體驗收

- [x] 4.1 更新 README、AGENTS、architecture 與受影響的共用 workflow／rule／Work Item 引用、交接 SVG，移除仍把 github-pr publish 當有效操作的現行指令。測試要求：搜尋有效 callers 不再依賴舊操作；獨立 Git 發布仍有可理解的分工說明；連結可達、圖文一致，實際渲染 SVG，歷史 verification 紀錄保持原樣。
- [x] 4.2 透過 `bash scripts/skills/install.sh` 同步並完成整體驗收與正式證據。測試要求：來源與受管理副本一致，installer fixture 保留無關內容；重跑 github-handoff、change-review、Work Item 及專案全部必要測試、OpenSpec validate／verify；重新生成完整 PR／Review／Fix 並逐項審閱，保存實際結果，區分靜態、離線行為及真實遠端驗收。未獲具體遠端目標授權時，不測試關閉任何既有 PR／Issue。

## 5. Work Item 與 GitHub 解耦

- [x] 5.1 移除 Work Item 規範中的 GitHub 小節，保留通用的本機隱私與正式成果交接規則；GitHub 契約自行定義 Finding 狀態，並由 installer 同步。測試要求：先取得 Work Item 不依賴 GitHub 的有效 Red，再確認 source／安裝副本沒有 GitHub 契約依賴，GitHub 契約不匯入 Work Item schema；Work Item、handoff、change-review 測試與 OpenSpec strict validate 通過。

5.1 驗證：新增 `tests/test_work_items.sh` 的獨立性檢查，修改前聚焦執行為 `FAIL Work Item convention contains no GitHub workflow or contract dependency`（exit 1），修改後同一檢查 exit 0。installer 同步成功；本輪重跑 `test_work_items.sh`、`test_github_handoff.sh`、`test_change_review.sh` 均 exit 0，`openspec validate simplify-github-pr --strict` 與 `git diff --check` 通過，兩份受管理文件與 template 逐位元一致。

## Workflow follow-up

- 本次 ff 只建立規劃 artifacts。使用者 review 時須特別確認「create／update 不自動 commit／push、移除 publish、close 不 merge」的提案邊界；批准後才 apply。
- 封存前確認上游 github-change-handoff 與 change-review 的主規格狀態；必要時先走上游的獨立授權流程，再於本 change 加入完整 MODIFIED requirement deltas、更新 proposal 能力清單並 validate，確保無相反有效條款。
- 真實 create／update／reply／close 測試使用另外授權的精確目標，不能把重構 skill 的授權當作關閉 PR #6／Issue #5 的授權。
- Archive、commit、push、發布 PR 與 merge 各依後續要求處理，這份清單不自動執行交付操作。

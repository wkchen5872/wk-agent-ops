# Tasks

## 1. 共用內容契約與追蹤

- [x] 1.1 先擴充 `tests/test_github_handoff.sh` 與對應來源到輸出案例，覆蓋 Handoff／Next actions／Author、人工與 Agent、Issue 雙 Session、未知 metadata、代發及 legacy 讀取。測試要求為先執行並記錄因舊契約缺少目標行為而失敗的有效 Red，靜態存在性與語意重播分開記錄。
- [x] 1.2 更新 `template/common/docs/github-handoff.md` 的共用格式及欄位語意，對齊本 Change 的 shared delta，移除與目前操作衝突的舊 publish／managed／完整 provenance 要求並保留 legacy 讀取。測試要求為 1.1 對應檢查轉 Green，人工與缺值案例沒有捏造資訊，三工具共用相同欄位語意。
- [x] 1.3 定義 Checkpoint、Next actions 與 Closure 的格式、適用時機、版本／證據及狀態前後順序，更新共用 acceptance cases 與必要的既有交接圖。測試要求為新增再驗證接手缺本地資料、摘要過時、平行摘要衝突、close 部分失敗、重試與 target 變更案例，SVG 更新須實際渲染檢查。

## 2. Issue 入口與完整參考案例

- [x] 2.1 調整 `template/common/skills/github-issue/SKILL.md` 的 create／update 格式引用、Issue reply 的 update 語意、local-only 關聯與工作識別。測試要求為先調整 GI-29 等案例取得 Red，再驗證同工作不同 WI 可接手、相同本地 ID 不足以查重，以及原正文／歷史留言保留。
- [x] 2.2 新增 Issue close 的操作順序、completed／not planned 判斷、Closure 發布回讀、state／reason 回讀及部分結果恢復。測試要求為先新增會對舊入口失敗的契約檢查，再重播完成、取消、驗收未完成、已關閉、狀態理由不符、逾時及摘要成功但 close 失敗，不操作其他 PR／Issue。
- [x] 2.3 依 [Issue 候選範例](references/issue-examples.md) 更新 `template/common/skills/github-issue/references/examples.md` 與 `acceptance-cases.md`，包含完整 create、progress、Checkpoint、完成／取消結案、人工及未知資訊案例。測試要求為逐案比對來源與預期貼文，確認 Handoff、Next actions、Author 及內容自足，全部模擬值有明示。

## 3. PR／Review 入口與完整參考案例

- [x] 3.1 更新 `template/common/skills/github-pr/SKILL.md` 的正文與 reply 格式、來源作者與發布者、Checkpoint 與結案摘要。測試要求為先擴充對應契約／重播案例取得 Red，再驗證 create、update、Review、fix、pass、無關人類文字保留及受審版本一致性，跑既有 `tests/test_github_pr_publication.sh` 保護 scoped commit 與 push 行為。
- [x] 3.2 調整 PR close 為只處理指定 PR，先發布及確認 Closure，再 close 與回讀，替換 GP-50／GP-53 等連帶關閉 Issue 的期待。測試要求為先記錄舊行為對新範圍的 Red，再驗證完成準備 merge 只回覆摘要、取消 close、被取代、已 merged／closed、重試及關聯 Issue 保持原狀。
- [x] 3.3 更新 `template/common/skills/change-review/SKILL.md` 與案例，使已授權遠端 pass 也發布及回讀，補齊 Next actions／Author，保留 local-only 與版本判定。測試要求為先擴充 `tests/test_change_review.sh` 取得 Red，再驗證三種 verdict、無 PR／PR unknown、本地限制、pass 不發修正通知、發布失敗及受審 head 移動。
- [x] 3.4 依 [PR 候選範例](references/pr-examples.md) 更新 PR 與 change-review 的 examples／acceptance references，讓同一需求的完整生命週期可連續閱讀。測試要求為核對 Finding ID、版本、實作者／Reviewer／發布者、Next actions 及結案語意一致，保留人類、fork、legacy、缺值、代發與失敗回復案例。

## 4. 安裝同步與整合驗證

- [x] 4.1 更新 README／AGENTS.md／架構文件與相關 rule 的受影響說明，透過 `scripts/skills/install.sh` 同步 template，並在臨時 Git repo 驗證新裝及重裝。測試要求為比較來源與 managed 目標、Skills reference 連結、Work Item 保留、三工具入口及 installer 範圍外配置保護，執行 `bash tests/test_github_handoff.sh`。
- [x] 4.2 執行受影響套件、專案必要檢查、`openspec validate standardize-github-collaboration-records --strict` 與適用的 OpenSpec verify，將實作驗證與案例重播證據放入 `docs/verification/github-handoff/`。測試要求為所有本次要求有對應證據，檢查格式、語意、installer、Git 本地 remote 與真實 GitHub 寫入各自標明範圍，未執行的遠端驗證如實記錄，無不明原因跳過的失敗。

## Workflow follow-up

- 完成設計 Review 與適用的人類確認後，使用 `openspec-apply-change` 實作本清單。
- 驗證完成後依後續交付授權處理 spec sync、archive、commit、push 與 PR。這些動作各自保留證據，建立本 Change 不代表已執行。

## 5. Review 修正

- [x] 5.1 修正 codex-sol-r01/F-01（Review 報告位於本地 Work Item `WI-20261114-workflow-skills-review`）：`change-review` 通知實作者前，須分辨代發報告的原實作者與發布者，依已核對來源定位原實作者，無法核對時回傳可轉交訊息，不預設通知發布者。測試要求為先擴充 `tests/test_change_review.sh` 取得 Red，新增「A 可定位」與「A 不可定位但 B 可定位」兩個 CR 案例並做語意重播，經 installer 同步後重跑受影響 suites。

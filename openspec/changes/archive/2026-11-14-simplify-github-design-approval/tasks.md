# Tasks

## 1. 授權來源與平台記錄分離

- [x] 1.1 先擴充 `tests/test_github_handoff.sh` 及契約案例，涵蓋未知人類帳號、API 帳號不同、無 PR 留言但已有明確實作指示，再修改 template 契約 §4.3／6.3／9 與 workflow 引用。測試要求：保存舊版有效 Red 與新版 Green；不要求第二次批准、專屬記錄者名單或帳號本人確認，亦不把 repo access 當授權。
- [x] 1.2 更新獨立批准事件範本、欄位說明與相容案例，保留來源／範圍／版本／時間與發布者，未知 approved_by 可省略。測試要求：先 Red 再 Green，驗證日期精度、歷史紀錄不改寫、來源不明／撤回／設計變更時停止受影響工作；不得因可讀取 repo 就宣稱寫入已允許或成功。

## 2. 各入口與重播案例一致

- [x] 2.1 同步 github-pr 的批准 reply 步驟、github-issue 相關引用、change-review checklist／examples／acceptance cases 與必要的圖文。測試要求：先捕捉殘留舊關卡的 Red，再確認所有 repo 擁有的入口使用相同來源與版本語意；不修改上游已安裝的 openspec-apply-change，不擴大各 GitHub operation 權限。
- [x] 2.2 建立並執行跨 Session 盲讀重播，對應本 Change 每項 scenario。測試要求：明確指示與可追查交接可繼續；只有 pass、只要求建立 Change、無來源的批准宣稱、授權撤回及變更設計不能冒當批准；另覆蓋工具未登入、可讀但寫入拒絕與寫入結果不明。逐案記錄實際判定，未測項明記，離線結果不宣稱遠端驗收。

## 3. 安裝與整合驗證

- [x] 3.1 執行 installer 同步 template 與 managed 目標，在臨時 repo 驗證初裝、重裝及 Claude Code／Codex／Antigravity 入口。測試要求：來源與安裝副本相同，參考連結可達；不改既有 Work Item 或 installer 範圍外配置；圖稿有修改時確認 XML、渲染與視覺結果。
- [x] 3.2 跑受影響的 handoff／review／workflow suites、專案完整必要檢查、本 Change strict validate 與 OpenSpec verify，保存正式驗證紀錄。測試要求：requirement／scenario 與證據逐一對照，保留既有基線限制，明示未執行的 GitHub 真實寫入／Session 通知；提供原 Review Change 接續前須核對的重疊規則，不修改其分支。

## Workflow follow-up

- 本輪僅建立 Issue #17 的獨立規格；不代表實作、批准事件發布或新規則已生效。
- 設計確認後實作本 Change；封存、commit、push、PR／Issue 結案與 main 整合依各自授權處理。
- 本修正完成並驗收後，再回到 `feature/improve-change-review-local-handoff` 合併更新、檢查重疊 delta 與授權來源後接續 Apply；保留其現有規劃與 PR #15。

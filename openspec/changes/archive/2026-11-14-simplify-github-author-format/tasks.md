# Tasks

## 1. 共用 Author 與純人類例外

- [x] 1.1 先擴充 handoff 測試及案例，再修改 template 契約 §6／各用途範本／§7，讓 Agent Author 移除「方式／人類」並保留既有四種 metadata，純人類直接發文省略空 Author。測試要求：取得舊版有效 Red 與新版 Green；覆蓋純人類與 Agent 代人類發文的不同輸出，不以同義欄位補回被刪資訊。
- [x] 1.2 同步正常、缺模型、缺一個／兩個 Session、實作與結案摘要的共用範例及對應案例。測試要求：正向核對工具／已知模型／雙 ID、原本的省略與 null 規則，禁止從 API 帳號推定本人或從來源紀錄猜 metadata；Issue #17 的批准來源與 approved_by 規則保持不變，歷史 fixture 可讀。

## 2. GitHub 入口與代發辨識

- [x] 2.1 更新 github-issue／github-pr 的格式說明、references 與相關測試，對齊建立／更新／回覆／結案所有入口。測試要求：先 Red 再 Green；新產生內容均符合精簡格式，舊正文與舊留言不被自動改寫，不改 Git side effects、close 範圍或寫後回讀。
- [x] 2.2 同步 change-review 的原實作者來源、checklists 與代發案例，確認新格式以原報告作者與來源辨識，舊方式標記仍可讀。測試要求：先 Red 再 Green並執行盲讀重播；原作者可核對時才送到原作者、僅代發者可核對時不送、來源未知不猜 ID，版本／Finding ID 與本地報告保存保持；不得新增通知或身分確認關卡。

## 3. 安裝與整合驗證

- [x] 3.1 執行 installer 同步來源與 managed 文件／Skills，在臨時 repo 驗證新裝與重裝，更新必要的專案說明。測試要求：Claude Code／Codex／Antigravity 入口皆可取得同一規範，來源與副本一致，references／連結可達；不碰 installer 範圍外配置、既有 Work Item 或歷史報告；圖稿若需改動，驗證 XML、渲染及目視結果。
- [x] 3.2 跑 handoff／PR publication／change-review suites 與專案完整必要檢查、本 Change strict validate 及 OpenSpec verify，保存 requirement／scenario 對照與語意重播結果。測試要求：涵蓋所有新舊格式與代發／缺值邊界；將靜態、語意、installer、真實 GitHub／Session 寫入分開記錄，未實測項與既有基線限制明記，不把離線案例宣稱為端到端成功。

## Workflow follow-up

- 本輪僅建立 Issue #18 的規格；使用者檢查設計後，再另行開始實作。
- 不重複建立 Issue，不因 FF 完成而自動 commit／push／建立 PR。後續 Issue 關聯更新、Review、封存與 GitHub 交付依各自授權執行。
- 保留已合併的 Issue #17 批准簡化與 Issue #13 本地 Review 行為；Issue #19 commit 引用自動化另案處理。

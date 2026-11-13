# Tasks

## 1. create 的完整發布流程

- [x] 1.1 在 github-pr references 建立未 commit、已 commit 未 push、已發布、唯一既有 PR、前置 base 未發布的完整 fixtures；先取得舊 skill 的有效 Red／舊行為基準，再修改 template create 與必要的 shared contract／使用說明。測試要求：建立要求即包含必要 checks／commit／push／Draft PR／回讀，不再詢問正常準備工作的額外授權；從 repo／branch／session 解析 base，唯一既有 PR 直接回傳，無真實差異不湊空 commit，不恢復 publish 操作。
- [x] 1.2 加入並驗證必要 Git 提交範圍、push 目的地與版本回讀，更新具體命令案例及部分成功說明。測試要求：以臨時 Git repo／本機 bare remote 實際驗證本次檔案進 commit、無關 dirty／untracked／staged 內容與 index 保留、既有 commit 不重做、遠端 SHA 相符；混合工作不能盲用整個工作區的 commit writer；hooks 不 bypass、push 不 force，前置 base ref 的發布只用既有正確版本。
- [x] 1.3 補權限／認證拒絕、test／hook 失敗、非 fast-forward、push 後 create 失敗／逾時與回讀不明的 Red／replay，再完成階段回報與重試規則。測試要求：分開回報 commit、push、PR、readback；重試先核對已完成狀態，不重複 commit／push／create、不換認證盲送；舊 GP-24 與全域禁止 Git 發布的斷言需有對應的新驗收，不只刪掉測試。

## 2. 雙 Session Author 與消費端相容

- [x] 2.1 新增 runtime ID 可用卻被漏查、兩者都有、只有原生、只有 Xirp、兩者皆無、來源衝突的有效 Red／完整輸出案例，再修改 template github-pr 與共用 Author 契約／examples。測試要求：先實際查詢可用 runtime／本機 metadata，再填 SESSION-ID 與 XIRP-SESSION-ID；兩欄均存在，各自 null、不互填、不問使用者手抄，不因缺 ID 阻擋發文；僅讀必要 ID，不 dump 全部 env／對話／credential，也不由 env 猜模型。
- [x] 2.2 更新 change-review 的最小 Author 讀取／交接說明及測試，涵蓋雙 ID 與 legacy namespace。測試要求：明確 Xirp ID 只作本機工具的 lookup hint，核對工具／專案／native 對應後才通知；只有原生或舊 `(xirp)` Author 可讀，缺新欄位不拒讀，不重寫歷史紀錄；最新 Reviewer 與實作者不同時不能通知錯人；無本機映射時回傳限制而非猜測。保持 change-review 的無 Git 寫入邊界。

## 3. 各操作界線與文件同步

- [x] 3.1 更新 README、AGENTS、architecture、shared contract 與必要圖文／caller，補 create 與 metadata 操作的分離案例。測試要求：現行指令不再將 create 的 commit／push 列為另行授權；update／reply／close 在 dirty checkout 不做 Git 發布，保留正文／歷史內容、close 依賴排除與 Issue reason 回讀；新 PR／Review／Changes 的 Author 都用雙欄，相關連結可達，改到的 SVG 實際渲染檢視，不修改 Work Item 或 github-issue 的獨立契約。

## 4. 安裝與整體驗收

- [x] 4.1 經既有 installer 同步 template 至受管理副本，執行相關與整體回歸。測試要求：tests/test_github_handoff.sh、tests/test_change_review.sh、tests/test_work_items.sh 與全部必要 tests exit 0；installer 可重跑且無關第三方內容保留；github-pr、change-review、managed contract 等副本與來源一致；openspec strict validate、git diff --check 通過，不手改安裝副本。
- [x] 4.2 以最終版 skill 重播並審閱完整建立流程與雙 ID 正文／回覆，保存正式驗收紀錄。測試要求：至少未 commit／未 push 到 PR、部分失敗重試、既有 PR、未知 ID 不阻擋、消費端本機定位等完整輸入到輸出及調用序列；本機 Git 使用真實臨時 repo 驗證，GitHub／session 遠端整合僅對具體授權 fixture 執行；區分靜態、Agent 決策、Git、GitHub 與通知證據，沒有跑的不能算通過。

## Workflow follow-up

- 此次 ff 只建立規劃。實作從這份 design／tasks 接續，不自動套用新的 create 行為來發布本 change。
- 封存前依當時 canonical github-pr 與上游 simplify-github-pr／GitHub handoff 狀態調和完整 deltas，取代 create 禁止 Git 發布與單 Session 的相反規則，保留其他未變要求。
- simplify-change-review 是獨立 change；後續實作須讀取更新後 Author 契約，本次不重寫其歷史規劃或擴充成另一輪 review workflow 實作。
- 真實 GitHub／通知驗收需具體目標授權；不把本次規劃授權當成可修改既有 PR #12 或通知現有實作者的授權。
- Archive、commit、push、發布 PR 與 merge 依後續交付要求處理，不屬於這次 ff 的自動動作。

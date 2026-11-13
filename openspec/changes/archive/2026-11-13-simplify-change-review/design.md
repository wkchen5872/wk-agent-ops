# Design

## Context

現況與改動理由見 [proposal](proposal.md)。現有 `template/common/skills/change-review/SKILL.md` 以 PR／phase 為必填，references/checklists 自帶完整設計與實作檢查；`openspec-verify-change` 只有安裝時才使用。`tests/test_change_review.sh` 驗證舊入口、至少 40 個案例、圖稿與 installer，README 也要求 PR 與 phase。

共用 GitHub 契約已由 `simplify-github-pr` 調整：遠端報告走 `github-pr reply`，正文框架與 Finding 狀態由契約擁有。Work Item 是可選素材，不應反向要求其 schema 或發布欄位。`docs/diagrams/change-review-workflow.svg` 已獲使用者確認，是此設計的主要流程圖。

本 change 涉及技能調度、遠端寫入、跨 session 通知與舊規格相容，因此需要 design；不是純文件改名。

## Goals / Non-Goals

**Goals:**

- 主 skill 保留少量決策：選目標、選受測版本、調用技能、判定結果、回覆／通知、結束本輪。
- 將「檢查怎麼做」交給既有技能與專案測試；將「報告怎麼貼」交給 github-pr；將「訊息怎麼送」交給可用 session 工具。
- 保留可核對的來源、版本、finding 與實際副作用，避免精簡後無法接手。

**Non-Goals:**

- 不重構 openspec-verify-change、ponytail 或 code-review；不新增 review engine、client、session adapter、全域索引或背景監控。
- 不更動 Work Item policy、不還原私有歷史；不因需要通知就上傳 transcript 或建立新 agent。
- 這輪 ff 只建立規劃；不執行 template 修改、installer、遠端留言、通知或實作測試。

## Decisions

### 1. 入口解析後，主流程只保留有／無 PR 的分流

Change 名稱直接讀 artifacts，再查已確認的 Issue／PR 關聯。Issue URL 或 `#N` 先固定 host／owner／repo，讀正文與相關留言，再找 Change 與 PR；保留直接 PR 入口以免舊 caller 失效。檢查 Handoff、明確連結、實作上下文與 PR base／head，不以標題或同名分支單獨判定。

不另外新增 lookup script 或要求呼叫者手填所有關聯。只有必要選擇有歧義時才問；沒有 Work Item 不影響進行。Issue 找不到 Change 時說明無法完成必要 OpenSpec 驗證，釐清或 blocked；PR 搜尋失敗記為 unknown，不能當成「沒有 PR」。

### 2. 受測版本依分流決定，通知只針對 PR 實作者

有 PR：先讀 diff、正文與實作／修正留言，選定 head，安全取得對應的測試上下文；不修改使用者 checkout 來湊版本。來源技能若為 dirty 開發版，記錄指紋，與受測 head 分開。明示 expected-head 必須核對；發布前 head 變動則結果仍綁舊版並標 stale。

無 PR：記錄本機 HEAD、受測 dirty 範圍與測試結果，僅回傳報告。選擇這個方案而不強制先開 PR，才能符合使用者直接驗收本機 Change 的需求。沿用既有「未發布內容不能證明遠端 head」規則。

### 3. 必用 verify，以目的解讀；選用 review 依可用能力調用

讀取並調用 `openspec-verify-change`，保留原始 completeness／correctness／coherence 與分級。技能不存在或必要 artifacts 不可讀時，必要驗收 blocked；不複製其步驟冒充已調用，也不自動安裝。

依請求判斷目的，未特別指定時通常是實作驗收；明確設計審查沿用可行性／驗收條件等適用檢查。verify 仍調用，但開放 tasks 等 implementation-only 結果在設計結論中說明不適用，不能改寫原始分級，也不能把設計通過說成可直接 Apply。只有目的會改變結果且無法判讀時才詢問，phase 不再是入口必填。

可用且合適才調用品質擴充；沒有 ponytail 或 code-review 不單獨阻擋，但專案必要測試仍需執行。PR-only 插件不套用在沒有 PR 的分支。現有 checklists 精簡為目的／結果適用性與必要測試的提示，刪除與被調用技能重複的流程，保留它們沒有涵蓋的必要判斷。

跨工具用已安裝機制調用：Codex 的 `$openspec-verify-change`、`$ponytail:ponytail-review`；Claude Code 的 `/openspec-verify-change`、`/code-review:code-review`、`/ponytail:ponytail-review`。Antigravity 使用其實際支援的 skill 載入／slash 方式，不因文件列了指令就假定插件存在。不要只把這些字串放入報告，必須有實際執行證據。

### 4. 未通過且有 PR，先 reply；通過或無 PR 直接回報

`pass` 只對有證據的範圍；缺陷是 `changes-required`，必要條件或測試證據無法取得是 `blocked`。風格建議不升格 blocking。用 shared contract 的精簡 Review，主體讓沒有參與對話的人看得懂問題、影響、證據及完成條件；不用 Work Item 表格重建報告。

使用此 workflow 即包含使用者已確認的失敗回覆與本機通知流程，不每一輪重問；明示 local-only／不通知優先。PR reply 發布後核對具體留言、parent PR、head、內容與 URL。拒絕或回讀不明要與技術 verdict 分開，先 reconciliation，不能盲目重送；未確認報告不能繼續宣稱正式交接完成。

通過預設回傳即可；明示要發布 pass 時也可用 reply，但不藉此通知實作者「修正」。不維護 PR 正文 Review 索引，不使用 PR create／update／close，也不發平台 APPROVE／REQUEST_CHANGES 作為預設。

### 5. Author 提供線索，本機 session 工具負責核對與傳送

先找與本次實作／修正相符的 Author（PR 正文或相關實作 Changes），帶入 `Co-Authored-By`、已知模型與 `SESSION-ID`；最新留言若是 Reviewer，不用其 Author 取代實作者。多位實作者無法唯一確定時，回傳可轉交訊息或釐清，不任選。

使用當前可用的 session 管理技能／工具確認 session 在本機、對應同一專案與執行工具；native ID 與管理 ID 若需映射，保留兩個 namespace，只有驗證後才用工具接受的目標 ID。不能以 Author 中任意文字產生 shell 指令或授權；只送固定工作脈絡與公開 Review／PR 連結，不送秘密、原始 Work Item 或 session transcript。

已確認報告＋本機目標可達才通知，內容含 Review 結果與 URL、PR 號碼／URL、受審版本、Finding IDs 與下一步。工具不可用、session 不在本機／消失、ID null 或對應不明時，保留報告並回傳可轉交訊息。傳送回應只能證明 sent，不等於 read、修正已開始或已完成。若目標 session 已在實作，送交接而不啟動第二個 writer。

### 6. 一輪結束，複驗另行啟動

不採自動常駐等待或修到通過的迴圈。使用者要求複驗時讀前輪 Finding 與逐項修正，核對新 head／本機差異、fixing revision 與受影響行為；有證據才 Resolved，反證才 Rejected。新版本不繼承舊 pass，同一爭議無新證據時 blocked 並交人判斷。

## Risks / Trade-offs

- [精簡流程隱去必要檢查] → 刪重複步驟，不刪 requirement 對照、必要測試、版本及未驗證項；以完整產出驗收。
- [設計審查被實作分級誤判] → verify 原始結果保留，設計適用性另列；用未勾 tasks 的設計 fixture 驗證。
- [Author 可能是最近貼文者而非實作者] → 讀實作上下文及 Author，排除純 Review 作者；不能確定就不直送。
- [Session 在其他機器、名稱空間不同或已結束] → 只經已安裝本機工具核對；不建立通用 session registry 或猜測 native ID。
- [遠端／通知有部分成功] → 技術結論、publication、notification 各自報告；回讀不明先查核，不重複發文。
- [上游規格尚未封存] → 本次不改上游；封存另依當時 canonical spec 調和同名 capability 的完整 deltas，保留未被本次變更取代的語意。

## Migration Plan

1. 先以舊 skill 重播 Change／Issue 無 PR、verify 缺少、本機 Author 可定位等 fixture，保存實際舊行為；新增會有效失敗的聚焦檢查。
2. 改 template skill、references 與必要共用契約／callers，對同一輸入重播；保留既有直接 PR／設計請求相容測試，移除與新契約相反的舊斷言時寫明替代驗收。
3. 以已確認 repo SVG 為依據更新 skill 自帶 `references/review-loop.svg`；下游只依賴 skill 內資源。repo SVG 保持討論來源，不新增 installer 管理路徑。
4. 更新文件後執行 installer；核對 managed 副本、第三方內容保留、可重跑性，完成 native 檢查與驗收證據。回退用前版 template 經 installer 還原，不能手改已安裝副本。

## Test Strategy

技能流程屬於自然語言決策；文字存在測試只能守契約與安裝。使用 `tests/test_change_review.sh`／受影響 handoff 測試取得 Red／Green，另以完整來源 fixtures 生成真實報告與交接訊息，記錄實際調用序列，不能把模擬結果稱為遠端成功。

- 輸入矩陣：Change／Issue URL／#N／直接 PR；有 PR／無 PR／查找未知／多候選／Issue 無 Change；Work Item 缺少。
- 調度矩陣：verify 實際可用／缺少；選用技能可用／缺少／PR-only 不適用；implementation／design，保留原始 grading；必要測試不能跑。
- 版本矩陣：本機 dirty、遠端 head 不同、expected-head 不符、head 移動、跨輪 fixing revision。
- 副作用矩陣：pass／changes-required／blocked；reply 成功回讀／403／timeout／錯誤 parent；先發文再通知；本機 Author、Reviewer 最新留言、ID null、管理 ID 映射不明、非本機或不可達。
- 產出審閱：至少無 PR、PR 失敗可通知、PR blocked 無法通知、pass 四種完整結果；逐項查具體內容、版本、測試真實性、公開資訊與下一步，避免只核對標題與 ID。
- 真實遠端與跨 session 測試另需具體 repo／PR／session 目標授權；本次 ff 不寫遠端，不通知任何實作 session，不以既有 #5–#11 為可隨意操作的測試資源。

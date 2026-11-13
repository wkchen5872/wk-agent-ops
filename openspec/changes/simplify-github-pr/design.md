# Design

## Context

動機見 [proposal.md](proposal.md)。`template/common/skills/github-pr/SKILL.md` 現有 create／publish 會委派 commit-writer、push 再修改 PR；update 只支援 managed block。`template/common/docs/github-handoff.md` 第 5、6.2、6.4、7、9–11 節分別耦合精確鍵、正文、Review、provenance 與批准。change-review 直接引用這些格式，現有測試也斷言 publish、push 目的地及大型 Review 欄位。

主規格目前沒有 github-pr、github-change-handoff 或 change-review；後兩者仍在待封存的上游 changes。本規劃延續 `simplify-github-issue` 的素材整理方式，建立 PR 專屬 capability，不改寫上游 artifacts 或既有遠端 PR。

## Goals / Non-Goals

**Goals:**

- 用單一共用契約服務 Claude Code、Codex、Antigravity；Skill 是操作入口，格式只存在於共用契約，references 放具體素材與產出。
- 以可理解的任務、設計或實際修改為主體，讓 Review 與 Fix 能逐項接續。
- 簡化呈現，同時保留版本與狀態證據、正確目標及失敗恢復。

**Non-Goals:**

- 不提供 Git 發布、自動 merge、branch cleanup、部署、archive 或背景派工。
- 不新增 wrapper、資料庫、PR 對照檔、隱藏的內容同步服務或新發布 skill。
- 不全面改寫 github-issue，也不讓一般 PR 操作要求建立 OpenSpec。

Work Item 的規範與 GitHub 發布解耦：Work Item 只管理本機紀錄、檔案責任與正式成果交接；
GitHub skills 可讀其素材，但不能要求它描述 Issue／PR 操作。共用 GitHub 契約自行定義
遠端 Review／Finding 格式與狀態，不匯入 `work-items/AGENTS.md` 作為 schema 依賴。

## Decisions

### 1. 操作只管理遠端 PR 與明確的關閉目標

本提案採用下列操作邊界，須隨設計一起經使用者 review；不將先前未回答的 commit／push 問題當成已批准。

| 操作 | 寫入範圍 | 前置條件 |
| --- | --- | --- |
| create | 一張 Draft PR | 確認 base、head 與有差異的已發布分支；沒有唯一既有 open PR |
| update | 本次授權的 PR 正文／關聯 | 已辨識 PR 與最新正文，更新範圍可區分 |
| reply | 一則新增的頂層留言 | 已辨識 PR、本輪回報內容與版本 |
| close | PR 及明確直接對應的 Issue | 關閉範圍與操作能力確認，無關聯歧義 |

這四個操作均不執行 `git add`、commit、push、merge、改 base 或刪 branch。需要 Git 發布時，交由另外的明確指令與既有 Git／commit 流程；不新增 publish 的別名或默默保留舊副作用。舊呼叫 `github-pr publish` 回報新邊界與需要獨立發布，不自動當作 update。保留舊 publish 作相容 alias 會延續原本的耦合，故不採用。

### 2. 選來源與確認實際 PR 版本分開

資料保持既有形式：本機紀錄路徑／ID、分支 refs、PR／Issue URL 與當前對話，不新增 parser 或中間資料模型。

明確指定 Work Item／Change 優先，缺少時停下詢問；沒有指定就讀目前 branch、實際 diff 與可證實關聯。直接讀 ignored 的 `work-items/WI-*/README.md`，不新增 branch 欄位。所有路徑均整合相關對話；使用者較晚確認的決策取代舊紀錄，無法判定才問。沒有 Work Item／Change 也可以以 branch 與 Session 為素材。

PR 目標獨立核對 full host／owner／repo、base、head owner／repo／branch，fork 同名不算同一目標。明確 PR URL 優先；否則以實際 head／base 找候選，再讀正文與 metadata。來源 ID 是輔助證據而非必填門檻；唯一 open PR 的重複 create 只回 URL，歧義先問。只有 closed／merged 歷史 PR 時不自行 reopen，也不把它當作仍可發布的 open PR；回報狀態，由使用者明確選擇新 PR 的工作範圍。

create 要有可取得的 remote branch 與非空比較；只有 Session 或未提交內容可先整理文案，不能用空 commit 或 placeholder 檔案製造 PR。update／reply 以所選 PR 的實際 remote head 說明已實作部分。本機 dirty／ahead 不阻擋純文字操作，但不能被當作已發布版本的證據。設計-only PR 可說明設計，不因尚未實作而虛構完成結果。

### 3. 正文固定框架，主體依內容調整

共用契約第 6.2 節定義唯一正文範本。下列欄位只是呈現示例；除 branch 外的關聯未知就整行省略，不寫空欄位或 null 佔位。

```markdown
## Handoff

- branch: feature/export-orders
- openspec-change: export-orders
- work-item: WI-20261113-export-orders
- issue: https://github.com/acme/widgets/issues/7
- depends-on: https://github.com/acme/widgets/pull/12（合併後可開始）

## Goal

<問題、影響與預期結果>

## Implementation

<這個已發布版本的實際改變與可檢查結果>

## Author

Co-Authored-By: <本次工具>
AI-Assisted-By: <已知當下 root-session 模型>
SESSION-ID: <本次 Session ID 或 null>
```

`Goal`、`Design`、`Implementation`、`Verification` 等主體標題按適用內容選擇，不要求同時出現。來源重組為問題、範圍、改變、完成條件與未決事項；不搬 coordinator、Sessions、決策編號或逐 Agent 行動清單。明示直接對應的 `issue` 與僅供參考的 `references`、`depends-on`，供 close 正確判定範圍。關聯的其他 PR 有用才列；reply 的 `pull-request` 則填當前已確認 PR URL。

Author 只記貼文者，不追查或冒用素材作者。SESSION-ID 優先可確認且允許揭露的原生 ID；未知／不公開用 null 並在操作回報說明，不造 alias 充數。使用者明確指定管理器 ID 時可寫 `SESSION-ID: <id> (xirp)` 等有來源的 namespace，不把管理器 ID 冒稱原生 ID。未知模型省略並回報；不為 metadata 猜模型、機器或時間。

### 4. update 更新目前說明，reply 保留每輪歷史

新正文不要求 HTML markers。update 先讀最新正文，只改授權的 Handoff／主體／本次 Author；保留無關人工文字、批准證據與留言。舊格式若 markers 完整，可更新其原管理範圍並保留外部文字，不要求先 adoption；plain body 以明確的既有段落處理。相同標題重複、邊界不明或已知有其他 summary writer 時先釐清，不能因為「重構格式」就覆寫整篇。

需要保存某輪判斷、修改理由或驗證結果時使用 reply，永遠新增頂層留言，不編輯／刪除過往回覆。主體標題預設 Review 或 Changes，可改為 Report／Fix 等適合名稱；保留 Handoff 與 Author 框架。

Reviewer 使用可交辦的清單，例如：

```markdown
## Review

版本：<reviewed head>。結論：changes-required。

- [ ] F-01：大量匯出失敗時沒有通知，使用者無法判斷狀態。
  證據：<位置或實際結果>。完成條件：失敗後可看到通知並重試。

已檢查：<實際執行結果>。未驗證：<具體限制>。
```

實作者回覆逐項對應 finding：修了什麼、fix commit、驗證結果、剩餘或有證據的不同意。使用者看得懂的結果優先，必要技術定位與 stable finding ID 保留；實作者的「已修」不是 Reviewer 的 Resolved。沒有 finding 不湊 todo；必要驗證不能做就寫 blocked。

### 5. change-review 與批准只保留有用證據

change-review 保留 phase、head 核對、connected code／tests、stable finding IDs、重新驗證與交接規則；修改其遠端呈現，透過 `github-pr reply` 發布簡潔頂層留言，不要求每次貼完整 Scope and Baseline 大表或 Review 索引。單行 scope／reviewed-head／verdict 與必要 checks／limits 放在主體；checkout 與 remote head 不同時仍須點明，複雜補充證據可連到已發布的驗證文件，不發布本機私有路徑。一般 reply 不代替審查執行，也不自動產生技術結論。

GitHub 平台 APPROVE／REQUEST_CHANGES 與 Agent verdict 仍分開，普通 reply 不呼叫平台批准端點。現行 COMMENT review 的歷史仍可讀；新一般回報使用 conversation comment，避免讓格式重構暗中授予 merge approval。

移除每篇正文必備的 design-approval 區塊，但不移除正式批准。明示要求代記人類批准時，可經 reply 發布可獨立辨識的批准事件，保留既有來源、範圍、revision、實際作者與記錄權限查核。Apply 可從舊 body 的 source_ref 或 PR 的獨立批准留言找到事件；無批准仍不准靠技術 pass 推導，未知時間保留其精度。此整合不要求一般 PR 一定有 Change 或批准欄位。

### 6. close 先確定整組目標，再依序關閉

使用者要求 close 即授權該 PR 與確認直接對應的 Issue，不再逐項重問已清楚的目標。寫入前列出精確 inventory：PR、明確對應的 Issue、其 repository 與當前狀態；不要把任何 `Refs`、討論中的 URL、依賴或被取代的歷史關聯都當關閉對象。Handoff 的 `issue`、GitHub 明確關聯與工作範圍相互核對，必要時讀關聯 Issue；有合理但無法分類的候選先問。已知工具缺少整組所需能力時先回報缺口，不把明知無法完成的組合當成成功。

先 close PR、不 merge、不刪 branch；回讀確認 closed 後，才逐個關閉直接 Issue 並回讀。沒有 Issue 就只關 PR。已 closed／merged 的 PR 不重做，回報真實狀態並可完成尚未關閉的已確認 Issue。PR 不確定是否關閉時不先關 Issue；Issue 部分失敗逐項回報，不 reopen 已關閉項目或換工具盲目重送。

關閉不證明已完成、merge、部署或驗收；理由只寫有依據的取消、取代或完成原因，不因預設 close 行為捏造成功。重跑讀實際狀態，只做剩餘且仍有授權的動作。不採用搜尋所有提及的 Issue 後批次關閉。

## Risks / Trade-offs

- [舊 publish 使用者需要改呼叫方式] → 清楚回報移除及獨立 Git 發布步驟，更新所有有效文件與 callers，不增加隱藏 alias。
- [純 Session 無 remote diff 不能開真正 PR] → 保留可讀文案並指出缺少的分支差異，不產生空變更。
- [正文不靠 markers，局部更新可能有歧義] → 保留人工段落、只動授權 section，無法分界時先問；不新增 ownership 資料庫。
- [Close 涉及多個不可原子完成的 API 寫入] → 完整目標 inventory、PR 先回讀、逐 Issue 回讀、部分成功可續做。
- [簡化 Review 可能漏證據] → finding、版本、checks／limits 作內容判準，不以欄位數當完整性；相應生成案例驗收。
- [上游未封存 deltas 與新契約衝突] → 保留其歷史 artifacts；封存時必須先取得上游主規格並以完整 MODIFIED blocks 調和相關條款。

## Migration Plan

1. 以本 spec 寫有效 Red 與完整生成／操作 fixtures，再改 template skill、契約與 references，不手改安裝目標。
2. 將現行 create／publish／update 的 callers 分成獨立 Git 發布、PR create／update、reply；更新 change-review 的發布指令與共用批准事件查找方式。刪除入口中的 Git 委派，不改獨立 commit-writer。
3. 更新受影響文件、範例與 SVG，跑 installer 同步、聚焦測試、全部必要套件與 OpenSpec verify；只對實際執行的重播／生成／遠端操作記錄結果。
4. 回退以回復這次 template 與相關文件並重跑 installer 為限；不自動刪除回覆或重新開啟已關閉的遠端紀錄。
5. 封存前重新確認 github-change-handoff 與 change-review 上游狀態；主規格已存在時補完整 MODIFIED deltas 及 proposal 能力清單，若尚未同步則先走上游獨立授權流程，不在 ff 階段替其 archive。本 change 不能在留下相反有效條款時宣稱整合完成。

## Test Strategy

- 現有 `test_github_handoff.sh` 的 publish／push 與大型模板斷言須依新 spec 改成四個操作與無 Git 寫入的行為；保留 fork、目標、授權、回讀及 installer 保護測試。`test_change_review.sh` 改為驗證 reply 發布及必要內容證據，不能只刪掉不再符合的測試而不補新行為。
- 至少三組完整來源實文：A，WI 記錄重試 5 次、本輪改 3 次、remote diff 只實作 3 次，生成 PR；B，無 WI／Change／Issue 的真實 branch diff 與 Session，後補 Issue 關聯再 update；C，Review 的具體 defect、fix commit 與測試輸出，依序產出 Reviewer reply 與 implementer reply。失敗對照包含只貼 ID、搬內部群組、把未發布修正寫完成、假造測試及提前 Resolved。
- 生成先不給參考答案，要求輸出完整標題與正文，再依問題、範圍、結果、未決事項與來源忠實性判定。實際輸出與差異保存至新的 verification 紀錄，不能把「會使用正確工具」當成摘要品質通過。
- Close fixtures 包含：直接 Issue A 與依賴 B、無 Issue、多對應 Issue、一個失敗、PR close 回讀不明、已 closed／merged 重跑；每例明列預期寫入與禁止目標，核對不 merge／不刪 branch。
- 完整遠端 close 僅在另外明確授權的測試目標執行；一般實作／verify 不得拿既有 PR #6 或其他工作做破壞性測試。沒有遠端操作的項目明示未驗證，不要求安裝或登入工具來湊驗收。

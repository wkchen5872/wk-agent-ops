# Design

## Context

這是待人類審閱的目標設計，尚未實作。動機見 [proposal.md](proposal.md)。共用契約的設計由 `add-github-change-handoff` 持有，對應 capability 為 `github-change-handoff`；實作時必須取得該 Change 已交付的契約版本，不能依賴暫存 Work Item 或固定的活動 Change 路徑。

已讀取的現況有兩個重要限制。

- `openspec-verify-change` 是實作完整性／正確性／一致性的 advisory 驗證，未完成任務會被報為 CRITICAL。設計階段不應整套套用；實作階段保留原始結果及各檢查的 not applicable／not verified 語意。
- `ponytail-review` 是外部擴充，不由本 repo 的 template 保證交付。已安裝時可加強品質審查，未安裝記為未執行，不單獨阻塞。本 Skill 自帶規格、相連程式、測試與回歸檢查基線，不把外部 Skill 缺席當成可以省略審查。

## Goals / Non-Goals

**Goals:**

- 使用者提供 PR 和審查階段後，Reviewer 能找出可驗證的正式版本，形成可追查報告與明確下一步。
- 保留既有審查方法與 Session 通知，以少量組合規則完成跨工具操作。
- 讓新的 Reviewer 或 implementer 不需原 Session，也能沿同一 PR 繼續修正與複審。

**Non-Goals:**

- 第一版不新增 Claude／Codex 專用 Agent 定義、通知後端、遠端啟動器或自動修復 worker。
- 不把技術判斷等同人類設計批准、平台 required review、merge／deploy 或正式資料驗收。
- Reviewer 不整理、提交或推送被審查的程式，不走 custom PR 的 create／publish 路徑。
- 第一版 GitHub 存取只走 `gh`，不新增 MCP 適配或驗收分支，也不重寫上游帳號檢查腳本。

## Decisions

### 1. 單一 Skill 的兩個階段，加可選複審上下文

來源為 `template/common/skills/change-review/SKILL.md`。入口語意是 PR reference 加 `phase=design|implementation`；複審額外提供上一輪 report reference，通知目標為可選輸入。這是語意契約，不保證所有工具有同一種命令列參數語法。

三種 Agent 的 GitHub 讀取／報告發布統一使用 `gh`，可以使用其 `api` 能力提交具有精確 commit_id 的原生 Review。依上游 Decision 4a 從已固定的可信 revision 取得檢查腳本到專用暫存目錄，核對 script blob 後執行 api 檢查；目標 cwd 仍為真正操作的 PR checkout，不直接執行候選 head 的同名腳本。使用者已信任且指紋不變的既有安裝來源亦可沿用；無可信來源則回報 bootstrap 缺口。只有 pass 才繼續已授權的遠端寫入；缺少 gh、非 pass 或權限不足時不自動登入或切換 MCP。

phase 缺漏而上下文無法唯一判定時先釐清，不從 Draft／Ready 狀態猜測。Change 若有多候選，要求選定。未來可另加 Agent runtime 配置，但這次不需要固定另一個模型或 provider。

### 2. 每輪先固定範圍與版本

由 PR 取得實際 repo、Issue／Change 關聯、base／head 及 artifact revision，確認可取得的程式／文件與測試環境。已有匹配且安全的 checkout 就使用；不匹配時取得經授權的隔離 review context，保留原 dirty checkout，無法做到則 blocked。

PR 報告只涵蓋已發布的審查內容。本地未提交檢查若有參考價值，另標為草稿／未版本化，不能掛同一 head 冒稱遠端通過。審查結束前重讀 remote head；移動時保留舊版報告並標示 stale，不將 pass 套到新版。

獨立首輪依使用者需求、正式 artifacts 與程式先形成初版結論，再交叉比較其他 Reviewer 未確認分析。複審明確使用上一輪 Findings 與實作者回覆，不把前人觀點冒稱新的獨立發現。

### 3. 階段專用的檢查與結論

| 階段 | 檢查 | 不能推導的結果 |
| --- | --- | --- |
| design | 需求一致、範圍、介面、依賴、可行性、風險、測試策略、觀測期間與驗收標準 | 任務已實作、執行測試已通過、人類已批准 |
| implementation | 基線逐條對照 requirement／scenario、相關 callers、測試、風險與回歸；組合當時可用的 OpenSpec verification 與可選品質 Review | 必定可 merge、部署已成功、必要真實資料驗收已完成 |

OpenSpec artifacts 與必要測試證據是基線前提；本 Skill 自己的檢查清單涵蓋完整性、正確性與一致性。已安裝 `openspec-verify-change` 時使用它並保留原始結果；若沒有該入口，逐項執行基線對照並明記實際方法，不能聲稱調用過 Skill。`ponytail-review` 等外部品質 Skill 缺席僅列未執行，缺少的是必要檢查／證據時才 blocked。專案另有明確 mandatory 檢查時仍遵守其規則。

適用且必要的檢查無法完成時，選定驗收範圍回報 blocked，列出已通過部分。若只要求明確的子範圍，可以回報該範圍 pass，但必須列出未完成的整體 acceptance，不修改原 Change 的完成條件。原始 verify advisory 分級要保留並逐項解釋採納／不適用理由；不能把「建議」直接轉成強制重構。

### 4. Findings 綁來源、證據與狀態

Finding 的 ID、verdict、狀態及基礎欄位只引用上游 `github-handoff.md` 的遠端 schema 與其指向的 Work Item §9；本 Skill 不重定義。報告發布前即有 ID，複審沿用 origin ID；實作者回覆不直接改成已驗證。

輸出必須使用共用契約的 `## Scope and Baseline`、`## Findings`、`## Summary and Limitations` 章節，參照使用者指定的 Work Item Review 形狀。Scope 明確填寫原生 Session-ID 與 source、獨立 alias，以及實際 Git 分支／base／head／checkout／未提交內容，不只在結尾附一段 provenance。未知、未取得或不允許公開時如實說明，不猜模型、Session 或 SHA。

遠端揭露預設引用上游已確認政策：保留工具、已知模型與原生 Session ID；機器僅用已配置別名或 null，不抓 hostname。具名批准代記的效力也由上游契約持有，本 Skill 不另設更嚴的「人類必須再次到 GitHub 留言」條件。

本 Skill 負責用實際檢查決定狀態及阻塞性。純風格偏好、可選微優化、範圍外功能不阻塞；安全、Bug、資料風險、未達正式要求或必要驗證缺口才形成相應的 blocking 結論。Accepted 且未處理的必要事項依上游規則移入正式 task／risk 追蹤，不只留在 PR。

### 5. 報告發布與 PR 說明維護分開

Reviewer 寫入前呼叫上游共用腳本，依固定的可信政策版本核對 repo／gh API actor，不信任被審查 head 改寫的帳號期望。預設以 `gh api` 提交 `event=COMMENT` 並明確指定 reviewed head，三種 Agent verdict 都寫在報告內；這不需要假設多位 Agent 使用不同 GitHub 帳號。若所需原生 Review 操作不可用但 gh 的一般 Conversation 留言可用且已授權，正文記明 head／phase 及形式限制。帳號不符時只保留授權的本地草稿或回傳報告，publication 標記未完成，不以留言繞過 actor 檢查。

共用契約區分 Agent verdict 與平台事件。同一 GitHub 帳號不能假裝多位平台 approver；只有帳號與權限允許、且另有明確意圖時才使用 APPROVE／REQUEST_CHANGES，不把它們列為預設必經分支。COMMENT、commit_id 與其他事件的 API 形狀已由 [GitHub Review 官方文件](https://docs.github.com/en/rest/pulls/reviews#create-a-review-for-a-pull-request)確認，實際帳號及工具支援仍須整合測試，不宣稱 required review 已滿足。

每位 Reviewer 保存自己的各輪報告。實作者／協調者需要更新 PR 摘要、證據或報告索引時，另用 `github-pr update`；Issue 的下一步另用 `github-issue update`。Reviewer 可在有明確摘要 ownership 時使用純 update 操作，但永不使用 create／publish，也不覆寫他人報告。

### 6. 一次一輪，明確交接後再複審

[修正複審 SVG](diagrams/review-loop.svg) 展示以下流程。

1. Reviewer 對三種結論都保存報告到 PR，取得可核對的 report URL 與 reviewed head；因無目標 PR／權限等原因無法發布時返回報告並標記缺口。
2. changes-required 時，預設回傳可轉交原實作者的訊息，內容含 PR／報告 URL、head、Findings 與下一步。若呼叫者另指定已確認可用的 Session 定向工具且已授權，才直接發送並記實際結果；repo 的通知人機制不當成 Session 工具。這次不新增通知器。
3. 實作者按自己的授權讀 PR、修正／測試、透過版本發布流程 push，逐項回覆修正 commit／證據，再通知 Reviewer。
4. Reviewer 再執行一輪，確認新 head、逐項驗證與受影響行為，保留前輪結果，發布 pass／changes-required／blocked。

每次 Skill 呼叫完成當前輪次並返回；「直到通過」表示沿此流程繼續接手，不是常駐無限輪詢。沒有新版或新證據而同一爭議重複時，立即報告 blocked 並交人裁決，不設定任意無意義重跑次數。報告發布不等於通知成功，通知送出不等於已接收或啟動。工具不支援時，返回使用者可轉交的訊息；原 Session 不在時，新 Agent 用 PR 接手。

人類設計批准的可恢復紀錄、實質設計變更後重新批准，以及 archive／doc 更新後必須發布並複審最終 head，均依上游契約執行。發現 active Change 已 archive 時，從 PR 的精確關聯取得 archived artifacts 及正式 spec，不把目錄搬移當作需求遺失。只有可證明為純交付整理的差異才縮小最後複審範圍。

### 7. 單向依賴，獨立驗收

先交付 `add-github-change-handoff` 的共用契約、Issue／PR 入口與 Work Item 分流規則，再整合本 Skill。前一 Change 用人工 Review 報告驗收，所以不依賴本 Skill。上游若已 archive，以已安裝契約／正式 capability 為準，不要求活動 Change 目錄還在。

## Risks / Trade-offs

- 各機器 gh／Git 認證與 provider 的 Session 通知能力可能不同。第一版維持 gh 單一路徑，逐機器記錄實際版本／actor；通知可降級為人工轉交，但不切換 GitHub 後端或以另一機器的登入代證。
- Review 使用錯誤 checkout 可能產生無效測試證據。每輪比對實際版本並在 head 移動後限制結論。
- 只看原 Finding 的一行可能漏掉回歸。複審包含受影響的相連程式與必要檢查，未變輸入的證據可有理由重用。
- 共享帳號不能證明平台上的獨立批准。報告記錄 Agent 身分，merge gate 另由 repository 管理。
- 缺少測試環境或需要等待 N 天不能在本輪解決。保留 blocked、負責人與可執行下一步，不能用推測補成 pass。

## TDD strategy and verification boundary

Skill 為指令文件，沿用上游人工重播方法，不新增 harness。案例來源放在 `template/common/skills/change-review/references/acceptance-cases.md`，格式只引用共用契約。先保存 fixture、固定模擬回覆、預期的 preflight／gh 呼叫與禁止行為，再用正常啟動的 Agent Session 人工比對；記錄實際工具、模型與版本。覆蓋 missing gh／script、mismatch、unverified 皆不寫入且不切換 MCP。正式去敏證據放在專案 `docs/verification/change-review/<run-id>.md`，tasks／PR 連到該版本，不只存在 WI；離線決策不能宣稱 gh 已完成遠端操作。

逐次驗證文件採上游規定的 OKF `type: Reference` 與必要 metadata／sources，作為有時間與版本的歷史 run 紀錄保存，不因後來修正而改寫舊結果。

新增 `tests/test_change_review.sh` 或沿用既有 contract 風格，檢查必要入口與禁止 create／publish 的界線，並以暫存 target 驗證安裝與重跑一致。實際 Review 行為需運行一個 Agent 並記錄工具 transcript／報告，不能以字串比對宣稱驗收通過。

Review 圖稿及案例都在 `template/common/skills/change-review/references/`，安裝後由 Skill 相對路徑引用；第二次安裝必須一併更新，不在 seed docs 留另一份圖。共用操作入口仍由 managed `docs/github-handoff.md` 引用 Skill，避免建立另一份功能手冊。

跨 Session 測試使用明確指定的測試 PR 與通知對象，重播「報告 → 通知 → 新 head／修正回覆 → 複審」。真實跨機器、三種工具 runtime 及 required-review 行為若未執行，分別明列未測；不為了跑測試而建立新的通知基礎設施。

## Migration Plan

1. 人類審閱設計，確認上游契約已交付且可取得。依 tasks 在 template 實作，不手改安裝目標。
2. 先在暫存 repo 安裝驗證，再透過既有 installer 安裝本 repo；更新 README／操作入口，保留原有 verify 和品質 Review 的獨立使用方式。
3. 不批次改寫既有報告。首次複審時引用其原版本與 ID，必要時建立有來源的對照，不冒充原始作者。
4. 回退時回復本 Change 的來源修改並重裝，不刪除既有 PR 報告或更改第三方 Skill。

## Open Questions

各工具的測試 PR、Session 目標與可用通知通道在測試前提供。缺少時報告相應整合未測或 blocked，不改變本 Change 的介面、流程或交付範圍；GitHub 通道已固定為 gh，並非未決事項。

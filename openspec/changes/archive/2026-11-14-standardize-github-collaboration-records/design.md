# Design

## Context

動機與範圍見 [proposal.md](proposal.md)。本 Change 橫跨共用契約、三個 Skills、參考案例與 installer 的 managed 產物，因此建立設計文件。

目前共用契約位於 `template/common/docs/github-handoff.md`。Issue 提供 create／update，後續更新只追加留言，Author 只記工具與模型。PR 提供 create／update／reply／close，create 含必要的 scoped commit 與正常 push，close 連帶關閉直接對應的 Issue。`change-review` 對失敗結果發布留言，pass 預設只回傳。

`openspec/specs/github-change-handoff/spec.md` 尚保留 publish、managed body 與完整 provenance 的舊敘述，與較新的個別能力及 Skill 不一致。本次 delta 將受影響的共用要求對齊目前入口及新格式。

## Goals / Non-Goals

**Goals**

- 團隊讀者可從每則內容找到相關工作、有效版本、實際證據、下一步及作者來源。
- Issue、PR、Review、修正、Checkpoint、Closure 共用最小外框，正文隨用途調整。
- gh 與已配置的 GitHub MCP 執行相同授權範圍，產出同樣可回讀的結果。
- Claude Code、Codex 與 Antigravity 使用同一套內容語意，個別 runtime 僅供取得可確認的 Session metadata。

**Non-Goals**

本次只優化團隊發布格式與必要操作。個人 OpenSpec 四階段封裝、Projects、排程、自動派工、跨機器啟動 Agent 及新增 PR merge 入口另行處理。既有設計批准的信任規則及安全 Git 發布能力保持其既定責任。

## Decisions

### 1. 共用契約擁有格式，Skills 擁有操作順序

`template/common/docs/github-handoff.md` 定義欄位、內容要求與缺值規則。Skills 引用該契約，負責來源整理、目標核對、操作與回讀。`references/examples.md` 提供完整案例，`references/acceptance-cases.md` 提供來源輸入、預期輸出與禁止動作。

採用集中格式可避免 Issue、PR、Reviewer 各自維護不同版本的模板。Skill 參考範例須能獨立理解，但回連共用契約作為欄位權威來源。

### 2. 每則內容保留 Handoff、正文、Next actions、Author

| 用途 | 正文內容 |
| --- | --- |
| Issue create | Goal、已知 Acceptance criteria，必要時加 References、Open questions |
| Issue update／使用者要求回覆 Issue | Changes，或交接用 Checkpoint |
| PR create／update | Summary、Changes、Verification，以實際發布版本為依據 |
| PR reply／Review | reviewed-head、review-id、result、穩定 Finding ID、Verification |
| PR reply／修正 | 對應 Finding 的改動、修正 commit、驗證與待複審狀態 |
| Checkpoint | Current state、Confirmed decisions／results、Open questions／Blockers、版本與證據 |
| 結案 | Closure 的 Outcome、Delivered／Result、Verification／Acceptance、Remaining work |

Next actions 說明立即可接續的動作，已知時附負責方及完成或解除條件。沒有後續工作就如實寫明，未知時指出待確認事項。保留內容完整性，不以空欄位湊模板。

Handoff 優先使用明確 URL、已確認的 Change、branch、相關 Issue／PR。PR 正文保留實際 head branch，fork 保留 owner。未知的選用關聯省略，完全無關聯時以一句話交代現況。舊 null 欄位仍可讀。Work Item 標記 local-only 與 repo-relative 位置，同一工作可由不同本地紀錄接手。僅有本地 ID 相同或不同都不足以證明工作相同或衝突。

PR 的直接工作、參考連結與依賴各自標明。依賴須寫解除條件。正文更新仍保留無關人類文字，Issue 一般 update 仍追加留言。

### 3. Author 同時服務人類識別與 Agent 品質追蹤

採用本次對話中的可讀欄位，精確文字集中在共用契約。

```markdown
## Author

方式: Agent 協助
人類: @已確認且允許公開的使用者
Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: <當輪原生 ID 或 null>
XIRP-SESSION-ID: <當輪 Xirp ID 或 null>
```

人類直接發布時只列方式與已確認的人類身分。Agent 參與時，模型保留當輪已知精度，未知則省略並回報。兩個 Session ID 各自查核，各自缺值時為 null，並在操作回報說明原因。人類身分未知或不公開時省略該選填行，不從 API 帳號推定實際委託者。工具／模型／Session 對應本輪發布者，不能沿用上一則回覆或來源作者的資訊。

代發他人撰寫的 Review 或實作報告時，在 Author 附原作者與來源報告連結，必要時保留其明確提供且可公開的工具、模型與 Session 資訊，發布者仍另列。重新整理多份素材的作者歸屬與整份轉交的原作者要區分，避免錯把代貼 Session 當作產生原結論的 Session。

這些 ID 僅作追查線索，通知或接手前仍需確認工具、專案與原生 ID 對應。歷史 Co-Authored-By 或單一 Session 欄位保持可讀，正常更新不重寫舊作者記錄。

### 4. Checkpoint 是既有留言操作的一種內容

暫停、換人、換機器或多輪討論需要整合時，以 Issue update 或 PR reply 新增 Checkpoint。日常進度不強制新增完整摘要，因此不新增獨立 resume／status／checkpoint 命令。

摘要保存足夠接手的現況，並連到正式規格、任務與已發布版本。尚未 push 的實作須明記無法從遠端取得。接手時閱讀摘要後續留言與目前 head，不能僅以時間最新判定有效。多人摘要衝突時揭露差異，協調主要整理者，不以 read-before-write 宣稱具備鎖定能力。

### 5. Issue 與 PR 的 close 各自處理目標

Issue 新增 close。一般 update 仍不改標題、狀態、labels 或 assignees。使用者說回覆 Issue，對應既有 update 留言語意。PR close 改為僅關閉指定 PR，不從關聯推定 Issue 關閉授權。

共同 close 順序如下。

1. 讀取目標最新正文、留言、版本及狀態，確認要求與理由。
2. 準備並發布 Closure 摘要，回讀父目標與全文。
3. 再核對摘要涵蓋的狀態，必要時處理新出現的差異。
4. 執行已授權的 close，回讀 state，Issue 同時回讀 reason。
5. 分開回報摘要 URL、狀態操作與剩餘事項。

完成 Issue 需有原範圍的驗收依據，取消則說明理由與替代工作。PR 放棄方案可 close，完成實作準備合併時以 reply 發布 Closure，Next actions 指向授權的 merge 流程。此回覆不自動 close 或 merge。已合併 PR 可依明確要求補結案摘要，保留實際 merge 證據。

狀態已完成或結果不明時，讀取實際留言與 state 再接續。若摘要已發布但 close 失敗，保留 URL 並回報仍未關閉。重試時沿用仍適用的已確認摘要。若工作或 head 已改變，新增涵蓋差異的摘要。已關閉但缺摘要的目標，僅在本次 close／摘要授權內補必要摘要，不重新開啟。錯誤的 Issue reason 回報不符，不自行 reopen。

### 6. 遠端 Review 保留通過結果

呼叫 `change-review` 且已確認 PR 時，沿用現有遠端發布授權語意，對 pass 也以 github-pr reply 發布及回讀。local-only、沒有 PR 或查詢 PR 狀態未知仍維持本地回報。修正通知只適用需要且可處理的回饋，pass 不通知實作者修正。

Review 判定、必要驗證、Finding ID、受審 head、移動 head 的 stale 判斷與人類設計批准繼續依既有規則執行。一般團隊發文可沒有 Change，而 change-review 仍以可解析的 OpenSpec Change 作驗收對象。

### 7. 用完整案例驗收內容

本 Change 的 [Issue 候選範例](references/issue-examples.md) 與 [PR 候選範例](references/pr-examples.md) 作為後續改寫 Skill references 的輸入。實作時以共用契約對照整理，避免案例變成額外規範來源。每組案例有連續一致的工作、版本、Finding 與作者，並明確標示虛構。

## Risks / Trade-offs

- Session metadata 增加曝光與查詢成本。只讀當輪必要鍵，遵循明示不公開要求，未知不阻擋一般發文。
- 摘要可能過時。保留版本與來源，接手及結案前對照後續留言及實際狀態。
- Closure 與 close 為分開的遠端寫入。分段回讀與恢復，允許回報部分完成，不假裝具備交易原子性。
- PR close 範圍改變。同步替換舊共用圖、Skill、規格與 GP-50／GP-53 等案例，文件明列需要另行操作 Issue。
- 加入欄位可能讓簡單討論變長。保留最小外框，正文選用有內容的段落，Checkpoint 按交接需求使用。

## Migration Plan

1. 實作前先新增會對舊行為失敗的契約檢查及案例期待，記錄有效 Red。
2. 修改 template 的共用契約、入口、Skill 與 references。更新既有交接圖及 README／AGENTS.md 相關說明。
3. 以 installer 同步來源至本 repo 安裝目標，並在臨時 repo 驗證新裝與重裝。保護既有 Work Items，保留第三方及 installer 管理範圍外的配置。
4. 對照舊 null、managed markers、單 Session 欄位與舊模型資訊做讀取相容案例。新發文採新格式，歷史不批次改寫。
5. 回復時還原此次 template 變更並重跑 installer，保留已發布 GitHub 歷史，後續以澄清留言處理差異。

## TDD and Verification

契約與 installer 的機械保證沿用 `tests/test_github_handoff.sh`，遠端 Review 行為沿用 `tests/test_change_review.sh`，Git 發布回歸沿用 `tests/test_github_pr_publication.sh`。需要時增加小型 fixture，但不新增正式 GitHub client 或 wrapper。

語意品質透過 references 的來源到輸出重播。每個案例記錄來源、操作、預期正文、禁止動作與實際結果，覆蓋人工、Agent、未知資訊、更新、複審、Checkpoint、結案與部分失敗。靜態檢查或模擬結果不代表真實 gh／MCP 寫入成功。真實遠端驗證如未執行，須明示未執行。

本階段只建立規劃文件，尚未執行實作測試、installer 同步或真實 GitHub 寫入。實作完成需跑受影響套件、專案必要檢查及 OpenSpec verify，保留實際證據。

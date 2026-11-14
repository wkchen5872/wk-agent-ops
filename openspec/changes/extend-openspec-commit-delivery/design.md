# Design

## Context

動機與範圍見 [proposal.md](proposal.md)。既有 `openspec-commit` v2.2 使用 archive → stage → doc-updater → git-commit-writer，支援未提交 archive 的接續及三工具 routing，完成後只回報本地結果。`github-pr` 已具備 update／reply／close，且後三者都不替 caller commit 或 push；close 已負責 Closure 先行與回讀，因此本 workflow 只組合既有能力。

本次是個人流程的收尾整合。團隊欄位及 PR／Issue 獨立結案規則已存在，不重新定義，也不依賴另個 Review 優化 Change 先完成。

## Goals / Non-Goals

**Goals**：保留可用的本地完成流程；將已授權的遠端交付依實際結果接上既有 PR 操作，並能在部分成功後恢復。正式四流程文件可脫離 Work Item 閱讀。

**Non-Goals**：自動建立 PR／Issue、merge、連帶關 Issue、刪除分支、force push、等待 CI／修正無限循環、前兩階段新 Skill，或改寫 provider-specific agent routing。

## Decisions

### 1. 先解析本次意圖與範圍，保留本地預設

無遠端交付要求時，`openspec-commit <change>` 維持本地完成，不因查到 PR 就自動 push／close。若當次或既有明確授權包含遠端交付，先確認 PR 的完整 repository／head repository、對應 Change、分支及操作；目標不明只阻擋依賴它的遠端步驟，不讓可完成的本地工作卡住。

明確列出本地、成功 PR 交接、放棄 PR close 三種路徑與停止點。單純「關閉 PR」仍使用 github-pr close；本 workflow 的取消分支適用已授權的封存交付與 PR 關閉組合，不能略過 archive 自己的警告處理，也不能把取消當作實作完成。

### 2. 本地核心能力與既有保護保持

保留選定 Change、exact archive path、spec-sync 結果、warnings、provider-native doc／commit subagent、root-session attribution 與 pre-commit gate。整個工作區 staging 只適用既有契約要求的隔離 feature worktree；若有無關變更，先停止／隔離，不藉 workflow 掃入另一個 Change。

archive 或文件步驟失敗時仍停止其 downstream；遠端失敗不撤銷成功的 archive 或 commit。已完成的本地結果、尚未完成的遠端交付分開報告。

### 3. 成功交付使用 reply，不 close 或 merge

授權發布後，caller 負責正常 push 到已核對的 head repository／ref，再讀取 remote／PR head 確認等於欲交付 commit，然後使用 github-pr update 描述該版本。推送被拒不換工具繞過、不 force。

封存與文件整理產生新 head 時，舊 pass 不自動涵蓋它。若已有對應新版本的有效 Review 可沿用；否則在授權包含時呼叫 change-review 做一個有界回合。未授權複審、changes-required、blocked 或版本移動時，停在已知階段，回報需完成的下一步，不自動修正或重複 Review。

最終受審內容與 PR head 相符、必要證據足夠後，使用 github-pr reply 發布／回讀 Closure，Next actions 指向另外授權的 merge。Closure 不代表 merge、部署或 Issue 驗收已發生。具體 merge 執行不在本 Change。

### 4. 取消／被取代委派既有 close

使用者已明確指定取消／被取代的 PR、理由及 close 授權時，呼叫 github-pr close，由它發布、回讀 Closure、核對變動、close 與回讀狀態。不要先再發同一則 Closure；不要求 cancelled work 有成功 pass，也不為了 close 自動 push 被放棄的本地成果。Issue、依賴及分支維持原狀。

已 merged／closed 的 PR 依既有 Skill 回報實際狀態，不 reopen、不重複 close。缺少理由或操作授權時保留本地完成結果，停在待確認的遠端動作。

### 5. 以現存證據恢復，涵蓋 commit 之後

不建立新的持久 workflow state registry。由明確 Change／archive 路徑、本地 Git history、已知 commit、remote head 與 PR 留言重建進度：

| 已確認結果 | 接續方式 |
| --- | --- |
| archive 已完成，尚無 commit | 沿用 exact archive，從文件／提交的缺少步驟繼續 |
| commit 已完成，尚未 push | 核對該 commit 的 archive 與範圍；只補已授權 push，不再 commit |
| push 已確認，PR update 失敗 | 確認目前 head，保留 push 結果，只補缺少的 update |
| Closure 已確認，close 失敗 | 由 github-pr close 讀取狀態，沿用仍有效的摘要，只補 close |
| 任一寫入結果不明 | 先讀現況，無法判定就回報 uncertain，不盲目重送 |

已提交 archive 不再從 `git status` 單獨推斷；只用明確名稱或已確認 PR 關聯對應到 archive 及 commit，再驗證內容。多個候選須釐清，不能以 newest 取代關聯。恢復時沿用仍適用的既有授權，不由舊 context 擴張至新目標或新動作。

### 6. 四流程正式文件只在本 repo 維護

交付 `docs/workflow/local-development.md` 與 `docs/diagrams/local-development-{define,implement,review,finish}.svg`，保留手機 PNG。它們不是每個安裝目標必須採用的團隊規範，不放進 managed agent-protocol。文件說清前兩階段已有能力與人工發布檢核、第三階段 Review、第四階段本次整合及成功／取消分支。

使用者已確認的 Work Item 圖稿可作搬遷素材，但正式文件不能只連 ignored 路徑。若實作時該 Work Item 不在 checkout，依本 Change 的流程規則與 references 自足重建，不要求還原原始對話。已確認整體流程與尚未實作能力分開呈現。遷移不等於刪除 Work Item。

## Risks / Trade-offs

- 遠端步驟是多次非原子操作：分別回報狀態、URL 與版本，失敗保留已完成證據。
- 取消 close 與成功 merge 容易混淆：明確意圖才分流，成功永遠不委派 close。
- archive 新 commit 使舊 Review 過時：只接受實際最終 head 的證據，不靠日期或分支名繼承 pass。
- 兩個 Change 可能同時更新 README：各自只改相關區段，不回退對方內容；不新增彼此的硬依賴。

## TDD and Verification

先擴充 `tests/test_openspec_commit.sh`，對舊 Skill 記錄有效 Red，再改來源與 references。語意重播涵蓋本地／無 PR／unknown、未授權遠端、正常交付、取消、已結束 PR、最終 head 改變、Review 未通過、archive／docs／commit／push／update／Closure 各段失敗與重試。Git push 用 disposable 本地 bare remote，GitHub 回讀用明示模擬；未授權不做真實寫入。

安裝同步、現有 Git publication suites、provider routing、attribution、archive guard 均回歸。四張正式圖做 XML、實際渲染與視覺檢查；在無 Work Item 的臨時 checkout 驗證文件及連結。最後 strict validate、適用 verify，分開記錄各層證據。本階段尚未執行實作測試。

## Migration Plan

保留入口名稱與既有本地用法，先改 template 與薄入口／reference，再 installer 同步。只在本 Change 實作時遷移正式文件。回復還原本次來源並重裝；已發生的 commit、PR 留言或 close 不以 rollback 自動反向操作。

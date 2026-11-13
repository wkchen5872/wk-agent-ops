# Design

## Context

這是本次工具與認證責任調整後的目標設計；既有實作尚需依本版調整。動機與驗收範圍見 [proposal.md](proposal.md)。

本機已確認的接入點如下。

- `template/common/skills/` 已由 `scripts/skills/install.sh` 整目錄同步至 `.claude/skills/` 與 `.agents/skills/`，不需新增安裝引擎。
- installer 的 `MANAGED_FILES` 決定既有專案會更新哪些共用文件；其餘文件只是 seed。新契約必須加入 managed 清單。
- `git-commit-writer` 會 `git add -A`，其 archive 參數為成對輸入，並不檢查推送帳號。PR 入口必須在委派前檢查完整 dirty 範圍，記錄有效提交身分；只有適用的明示身分限制才嚴格比對，不假設 writer 已處理。
- `template/common/work-items/AGENTS.md` §9 已區分本地 Review 預設與 PR 正式交接；WI 的本地儲存／不可同步規則保持不變。
- 既有版本已交付兩個 Skill 與 identity-check 腳本；本版改由原生 Git／gh／MCP 管理認證，移除腳本與強制 bootstrap。舊驗收證據只代表其受測版本，不能證明本版已完成。

## Goals / Non-Goals

**Goals:**

- 用兩個入口與一份契約完成格式適配、目標／操作核對、關聯查重、版本發布及摘要更新。
- 人工可以逐階段啟動；同一份資料也可讓之後的 Review Skill 使用。
- 明確區分「已在本機完成」「已發布到指定 remote」與「已驗收」，失敗後能回報已完成的步驟而不盲目重做。

**Non-Goals:**

- 不建立多機 scheduler、Session registry、GitHub client、看板同步或通用 hook。
- 不更改 Git Commit Writer 的 standalone 行為或 runtime model，也不修改第三方 Skills。
- 不由本 Change 實作 Review 判斷與通知器；它們由下一個 Change 或既有工具負責。
- 不新增通用後端適配層、credential parser、認證設定工具或強制帳號白名單。使用既有工具／Skill；缺少可用能力時回報，不自行安裝、登入或改帳號。

## Decisions

### 1. 一份 managed 契約，兩個薄入口

`template/common/docs/github-handoff.md` 是欄位語意、範本、目標與操作核對、更新規則及完整操作手冊的唯一來源。兩個 Skill 與未來 Review Skill 只引用它，不各存一份 schema。installer 明列此文件為 managed；protocol 加按需短連結，OpenSpec workflow 說明 GitHub 流程是可選交接方式，不能強制所有專案開 Issue。

本版由 Markdown Skill、既有 GitHub 工具及本機 Git 組成。Issue／PR／Review 可選已安裝且可用的 gh 或 GitHub MCP；commit／push 使用 Git，SSH／HTTPS credential 交由本機配置。共用契約只定義相同的輸入、核對、結果及失敗語意，不提供 client、通用 adapter 或自訂身分檢查腳本。

兩個薄入口承接使用者後續明確提出的「建立 git issue skill」與「建立 git pr skill」，以及 PR 按需委派 writer 的需求。先前工具重用決策的核心仍適用：原生工具執行操作，專案持有格式。入口補足每次需手動重貼的格式、完整目標與操作核對及 stage-all 範圍檢查；單獨一份契約可人工使用，但不滿足這次要求的可呼叫入口。這不是另建 GitHub API client，也不表示設計已批准實作。

### 2. 操作介面分離副作用

以下是 Skill 的語意介面，實際各工具的 `$skill` 或 `/skill` 呼叫語法由工具適配。

| Skill／operation | 必要輸入 | 授權內可能產生的副作用 |
| --- | --- | --- |
| `github-issue create` | Change、明確 repository | 建立 Issue；找到唯一關聯時回傳既有 Issue |
| `github-issue update` | Issue URL、要更新的範圍 | 更新自己負責的追蹤區塊／欄位 |
| `github-pr create` | Change、Issue、head／base、design 或 implementation | 按需 commit、push、建立 PR；已有 PR 時回傳並說明，不能默默發布新版本 |
| `github-pr publish` | 既有 PR、Change、本次授權變更 | 按需 commit、push 到已核對的 PR head，更新版本摘要 |
| `github-pr update` | PR URL、要更新的說明區塊 | 只更新正文，不動 Git、base 或生命週期 |

缺少 operation 時，根據明確的使用者意圖解析；無法區分時先釐清，不由 Reviewer 情境推定可 commit／push。create／publish 的入口說明須預先交代其 Git 副作用；授權明確時不逐步重問。沒有未提交變更就略過 writer，沒有可發表差異則回報；不製造空 commit。

Issue、PR、Review 使用當次選定工具的實際執行上下文，明確指定完整 host／owner／repo；Git Commit Writer 負責 commit，本機 Git 負責 push。gh 的帳號資訊不能替 MCP 或 Git push 背書。選工具不改變使用者授權範圍；未知的寫入結果須先查核，不換工具盲目重送。

### 3. 關聯以現有 GitHub 紀錄為準，不新增追蹤資料庫

Issue／PR 的 managed 區塊包含精確鍵 `openspec-change: <change-id>` 與 `repository: <host>/<owner>/<repo>`，並保存 repo-relative artifact path、已發布時的 revision 連結及可選 WI ID。Issue 另放父子／依賴與下一步；PR 另放 Issue、phase 與實際 head。搜尋只是候選發現，必須讀取 body 比對鍵值、repository 及明確 URL／head 分支才能確認關聯，不能只靠相似標題或模糊搜尋結果。

先查既有映射再建立；多候選停止選擇。遠端 timeout 後重新查核，不直接重送 create。本地可回填 WI 連結，但正式紀錄不依賴它，不新增需再次 commit 的 Change↔Issue 對照檔。尚未 push 的規格填「local-only／待發布」，不編造 commit URL；發布後更新遠端連結。

### 4. 原生工具管理認證，流程核對目標、操作與結果

把「是否為使用者指定的工作」「工具目前能否做這個操作」與「是否限制特定帳號」分開。只比對 host 不足；完整識別為 host／owner／repo。PR 另核對 base／head repository、owner、branch 及 remote head，不能用正文、同名分支或相同 SHA 代替 GitHub 實際 metadata。fork create 必須使用工具可明確表達的 head owner／repo；gh 能表達時使用 owner:branch，不能安全表達的形式停止回報。

每次操作遵循以下最小順序：

1. 從明確輸入與可取得的 repository metadata 固定目標、operation 及授權範圍。Git push 另核對實際 push URL 的目的 repo 及 ref；SSH host alias 交由原生設定解析，不為辨識 actor 自行執行認證測試。
2. 選擇可用且已配置的工具，確認其連線、所需能力與可取得的權限資訊。公開 repo 可讀或 repository role 足夠，不等於 token／App 具有這次 Issue／PR／Review 寫入權限。唯讀資訊只能證明它實際涵蓋的部分。
3. 已知未登入、目標衝突、明確拒絕權限或缺必要能力時，停止受影響操作並回報。無法完整預證寫入權限不自動形成阻擋；執行本來已授權的必要操作，以實際回應判定，不額外建立測試 Issue／PR 或空 commit 探權限。
4. 回讀實際 URL、目標、正文或 remote ref，核對本次操作結果才標記完成。能確認的實際 actor 記錄來源；不能確認就寫 unknown／unavailable，不猜測、不以另一工具的登入補證。
5. 失敗或 timeout 時分開記錄已完成、本機與 remote 狀態。結果不明先以精確關聯／ref reconciliation 查核；未釐清前不換 gh／MCP 重送寫入。每次工具改變都重新確認目標與該操作上下文，不自動改帳號、key、credential helper、remote 或全域設定。

| 操作 | 流程負責 | 本機工具負責 |
| --- | --- | --- |
| Issue／PR／Review／留言 | 明確 repo、operation、授權、可用權限證據、結果回讀 | gh 或 MCP 自身的連線與認證 |
| commit | 完整 dirty 範圍、既有 writer、有效 author／committer 記錄、專案明示規則 | Git 的身分配置與 hooks |
| push | 實際目的 repo／ref、已授權 commits、非 force、remote head 回讀 | Git 的 SSH／HTTPS 認證與實際服務端拒絕結果 |

不解析 credential helper、token、SSH key 或成功問候，不執行 credential fill，不把 gh API login 當作 push actor。Git author／committer 是提交 metadata，不必等於 GitHub login。

### 4a. 指定帳號是明示限制，不是預設前置條件

專案沒有指定帳號時，不要求先建立 identity policy 或取得可信 script blob；既有本機配置即可進行已授權操作。保留工具、模型、Session 與可取得的執行帳號，符合 provenance 的誠實記錄要求即可。

只有使用者或專案明確規定某個 operation 必須使用特定帳號／提交身分時才嚴格比對。限制來自本次使用者輸入或已信任的專案規範，不由候選 PR 自行放寬；不符或無法證實符合時停止該操作並回報，不修改認證。若要求嚴格 push actor，但原生工具沒有可安全取得的證據，就交由使用者處理；本版不補建 parser。

人類設計批准的記錄者授權是另一項決策：不能由「某帳號有 repo 存取權」推導它有權代記人類批准。沿用可信專案規範或使用者明示的記錄者授權，核對實際事件作者；沒有該證據只阻擋依賴批准的 Apply，不阻擋唯讀 Review。政策未限定操作帳號，不代表放寬批准來源。

移除 `template/common/scripts/github/check-identity.sh` 與其本 repo 安裝副本、managed 登錄及呼叫鏈，不用新腳本取代。下游未知或自行修改的檔案不任意刪除；回報遺留檔，不再以它作必要入口。規範與 rule 指向共用契約，不加 hook，也不宣稱能攔截所有手動操作。

### 5. Writer 委派前確認整個工作區與提交目的

create／publish 先盤點 staged、unstaged、untracked 與 base-to-head diff。因 writer 會 stage all，只有所有未提交內容都屬本次授權範圍時才可呼叫。遇到其他 Change／Agent 的檔案，停止並報告清單，不自動 stash、reset 或移動檔案。

活動 Change 使用 writer 現有 branch／staged-path 關聯，不只傳 `change_id` 作 archive context；建立規格 PR 與一般實作版本不需要先 archive。最後的 archive 交付依 Decision 8 另行處理；已 archive 時從精確目錄／PR 關聯取得原 Change，不要求活動目錄仍在。提交 attribution 傳當次已知 root model，通過既有 pre-commit gate。commit 後重新取得實際 head／diff，再 push，核對 remote head 後才建立或更新 PR。已 commit 但 push 失敗須分別報告，重試不重造 commit。

### 6. 正文只維護當前摘要，報告各自保存

Issue／PR 的共用區塊使用固定起訖註解，例如 `<!-- wk-agent-ops:handoff:start -->` 與 `<!-- wk-agent-ops:handoff:end -->`。更新時讀取最新正文、保留區塊外內容，再由選定工具寫回完整 body。缺少或重複 marker 時不猜；既有未管理正文由使用者明確指定採用區塊後才更新。

一位明確負責人維護摘要；其他 Agent 在自己的 Review／留言寫報告，不共寫 Reviewer Information。先讀再寫不能消除競態，第一版不宣稱有鎖或原子合併；已知並行寫入時停止摘要更新。生命週期操作、label／assignee 全量 replacement 不屬正文 update 的隱含權限。

### 7. 最小欄位與 provenance

| 紀錄 | 最少資訊 |
| --- | --- |
| Issue | Change、artifact 可取得狀態／版本、關聯 PR、目標摘要、目前負責人與下一步；有父子／依賴／等待時加相應資料 |
| PR | Change、Issue、phase、變更摘要、實際 base／head、驗證及未驗證事項、Review 報告索引、下述 design approval 紀錄 |
| Review | 沿用 Work Item §9 的 scope／baseline、Findings、檢查與限制，延伸 phase、verdict、review-id、provenance 與前輪／修正連結；執行由第二個 Change 負責 |
| Provenance | role、`Agent-Tool`、已知時的 `AI-Assisted-By`、Session reference 與 type、可選 `Machine-Alias`、含時區時間、revision／unpublished；代發時區分作者與 publisher |

`Agent-Tool` 用於 Issue／PR 事件；Git commit 保留現有 `Co-Authored-By` trailer。兩者不視為同一種原生署名能力。未知模型依 writer 原則省略並回報，不猜更細版本；已知 model 不省略。原生 Session ID 須已知且允許發布，否則使用明示 alias 或 unavailable。Machine-Alias 僅使用中性代號，不讀取原始 hostname 或發布本機路徑。初始規劃者與後來 publisher／implementer 分開記錄，不能以最後更新者改寫原作者。

預設揭露政策已確認：GitHub Issue／PR／Review 保留實際工具、已知模型及已知原生 Session ID，並記其來源；機器資訊只使用中性別名，沒有已配置別名就 null，不自動抓取 hostname。未知模型／Session 不猜填；專案或使用者另有明確不公開要求時，標為 withheld 並保留可用 alias。這是 provenance 的預設，不表示代發者可以替原作者補猜身分。

遠端 Review schema 的唯一持有者是本契約，基礎 Finding 欄位與 Open／Accepted／Rejected／Resolved 語意引用 `work-items/AGENTS.md` §9，不在兩個 Skill 再定義。遠端延伸如下。

- `verdict` 僅為 `pass`、`changes-required`、`blocked`；`phase` 為 `design` 或 `implementation`，不能用 GitHub event 取代。
- 發布前即可指派 `review-id`，格式為 `<reviewer-session-alias>-rNN`，在該 PR 中確認唯一；它不是原生 Session ID。Finding ID 為 `<origin-review-id>/F-NN`，後續輪次沿用其最初 ID，不隨新報告改編號。報告發布後再補 URL，不以未存在的 URL 建立 ID。
- Review 本身、遠端 publication、通知 delivery 各自記狀態；blocked 報告也須嘗試依授權發布。實際帳號／版本／工具不明或發送失敗時保留明確限制。
- Accepted 且尚未處理的必要 Finding，仍須在對應 OpenSpec task 或明確的正式風險機制保存追蹤與 PR 證據連結。PR 是詳細報告位置，不替代既有正式待辦；純可選建議不用擴張 tasks。

遠端報告保留 Work Item Review 的明確章節，不只發布結論摘要。以下為共用契約應交付的範本形狀；本節是目標格式，不是本次實際 Review 結果。

```markdown
# Review：<Change／phase／round>

## Scope and Baseline
- Reviewer：<工具；已知的 Reviewer model>
- AI-Assisted-By：<已知 current root-session model；未知時省略並說明>
- Session-ID：<已知且允許發布的原生 ID；否則 null>
- Session-ID source：<runtime／user-provided／unavailable／withheld>
- Session-Alias：<明示本地別名；沒有則 null，不冒充原生 ID>
- Machine-Alias：<可選中性代號>
- 審查時間：<含時區>
- Repository／PR／Issue：<已核對的目標與關聯>
- OpenSpec Change／Phase／Review-ID：<本輪目標>
- 審查範圍：<artifacts／程式／測試，以及必要對照檔案>
- Git branches：<PR base branch／head branch；實際 checkout branch 或 detached>
- PR base SHA：<取得 PR 時的 base 分支版本；未取得則 null>
- 比較 base SHA／reviewed head SHA：<本輪實際比較的範圍；未版本化則 null>
- Checkout HEAD：<實際跑檢查的版本；沒有 checkout 則 null>
- 未提交內容：<staged／unstaged／untracked 的包含或排除範圍>
- 文件快照：<本地未版本化內容的 repo-relative 清單、指紋與算法；不適用則說明>
- 發布版本：<已核對 remote head／local-only／未查證>
- 獨立性：<首輪或複審；是否讀取前輪報告／他人未確認分析>
- 實際執行的檢查與結果：<命令、環境、結果；未執行明列>

## Findings
<穩定 ID、影響、位置、證據、建議、狀態、正式追蹤／修正／驗證依據>

## Summary and Limitations
- Verdict：<pass／changes-required／blocked>
- <未覆蓋範圍、未執行檢查、交接狀態與下一步>
```

Session-ID 是每輪應出現的欄位，不能只用 Reviewer 別名替代；沒有可信原生 ID 時保留 null 與原因，不能因此假造 ID 或阻擋本可完成的審查。使用者提供的原生 ID 註明 source，不冒稱由 runtime 驗證。公開到 GitHub 前仍依 provenance 的揭露規則處理；本地報告與遠端 payload 不必包含相同的敏感資訊。

Git baseline 記錄「這一輪實際審查什麼」，不能只記當前 branch 或短 SHA。比較 base 與 PR base 分支快照可能不同，必須說明實際比較依據；Checkout HEAD 不符 reviewed head 或含未提交內容時，不能把本地檢查聲稱為已發布版本的驗收。PR-only 文件審查可沒有 checkout，須如實說明。這些欄位由共用契約持有，Review Skill 只填寫，不再定義另一個範本。

PR managed 區塊另含 `design-approval`，初始 `status: pending`。批准時記 `approved_by`、`approved_at`（含時區；只知道日期時記日期；完全未知則 null）、`approved_scope`、`artifact_revision`／必要文件指紋、`source_kind`、可取得的來源參照、`recorded_by` 與 `recorded_at`。批准依據可採下列兩種形式。

- `human-github`：使用者本人可取得的 PR 留言或原生 Review。
- `agent-attested-user-instruction`：已授權 Agent 代記使用者在對話中的明確批准。使用者已選擇信任這種具名代記，新機器不需要取得原始對話逐字稿，也不強制人類再到 GitHub 留言。

代記須真實指出人類批准者、範圍、版本與來源類型，不能由 Agent 技術 pass 自行推導。受信任記錄者由已信任的專案批准規範或使用者明確授權指定，獨立於操作帳號是否受限；不能從 repo 存取權或候選 PR 的新政策自我授權。代記事件以獨立 PR comment 保存，透過 GitHub 的實際 comment author 核對發布帳號，正文記 Agent／Session 與記錄時間，managed 摘要連到該 comment。不能只憑 PR body 中的 `recorded_by` 字串認定發布者，也不冒稱人類本人在平台留言。

新 Session 在帳號受信任、紀錄完整、適用範圍與設計版本一致時，將具名代記視為有效批准依據；信任的是已授權者的明示代記，不是宣稱原始對話可獨立重播。未授權發布者、僅技術結論、pending、缺乏必要範圍／版本或 superseded 的紀錄均不授權 Apply。不得偽造時間、批准者或私有 transcript URL；需求／設計實質改變時保留原事件並標記 superseded，取得新批准後新增事件。

### 8. 第一版以同張 PR 的兩個階段示範，不綁死拓撲

[流程與責任 SVG](diagrams/handoff.svg) 展示人工斷點。標準簡單案例為 Change → Issue → commit／push 規格 → Draft PR → design Review → 人類設計批准 → Apply → publish 實作版本 → implementation Review／修正複審。需要分開設計 PR 的既有工作可透過明確關聯處理，不自動拆 PR，也不以設計 PR 合併取代後續實作驗收。

Reviewer 用當次可用的 gh 或 MCP 發布 Review／留言，核對目標與必要能力並回讀結果，不調用 PR create／publish。報告發布後仍需明確 Session 通知；沒有可用通知器時交給使用者啟動／轉交，記錄 delivery 未完成，不能聲稱通知成功。Draft／Ready、merge、deploy、archive 和 Issue close 分別依授權處理。

第一版預設回傳可轉交訊息，包含 PR／報告 URL、head、Finding IDs 與下一步；已確認且可用的 Session 定向工具才加強為直接通知。repo 的 Telegram／等待提示不當成 Session 訊息通道，這次不承諾三種工具都有定向通知。

等待資料的 Issue 分開記錄交付與驗收狀態。第一版範本使用 `Refs #N` 關聯，不預填自動關閉語句；即使 implementation Review pass，也必須檢查是否仍有部署／資料驗收責任。等待日期只是最早可檢查時間。

archive 的交付順序另有明確斷點：一般 implementation Review／verify 通過只代表當時 head。已具備 archive 條件且取得授權後，呼叫既有 `openspec-commit` 完成 archive → doc-updater → commit，再由 `github-pr publish` 核對並 push 既有 commit，不重新 archive 或建立空 commit。Reviewer 必須對新 head 做最終差異複審；只有可證明為搬移、spec 同步及相應文件修訂時才縮小範圍，任何語意變動都擴大必要檢查，最後報告須綁最終 head。

預設在尚未合併的同一 PR 完成這次交付複審。若必要資料驗收尚未完成，不為了結案提前 archive；若另有批准的先 merge／後 archive 流程，後續變更需要明確授權的 follow-up PR，不能把新 commit 推到已關閉 PR 就宣稱已完成審查。範圍不變的設計批准仍可引用原紀錄。

### 9. 文件及圖稿一起 managed

實作時的正式來源為 `template/common/docs/github-handoff.md`、`template/common/docs/diagrams/github-handoff.svg`。下游 `docs/github-handoff.md` 引用同層 `diagrams/github-handoff.svg`；兩條路徑一起列入 `MANAGED_FILES` 並測試第二次安裝都會更新。Review 專用圖另放 `template/common/skills/change-review/references/review-loop.svg`，隨 Skill 整目錄同步，不新增一個只 seed 的 docs 圖。

舊 `check-identity.sh` 不再是 managed 交付物；移除其登錄與強制呼叫。測試證明新安裝不帶舊前置條件、重裝不破壞無關 scripts 或本機認證配置。薄 rule 沿用既有 mirror，同時檢查 Codex 的共用 protocol 指標，不只以 `.agents/rules/` 存在宣稱已啟用。

## Risks / Trade-offs

- Agent 指令不能保證所有手動入口遵守格式。以可重播案例驗收，未加入 repo 強制檢查前不得聲稱所有 Issue／PR 已受控。
- 預設允許任何已配置且獲授權的帳號，不能只靠 repo 權限排除「有權限但非使用者偏好的帳號」；需要限制時使用明示規範。實際帳號不可取得時記錄未知，不宣稱已驗證。
- 先讀後寫可能覆蓋同時編輯。指定單一摘要維護者，Reviewer 分別寫報告；不新增分散式鎖。
- 查重搜尋可能漏掉剛建立的紀錄。優先使用明確 URL／已返回的遠端 ID；timeout 不盲目重送。
- 第一版不改既有 writer 的 stage-all 行為。有混合 dirty 工作時 PR publication 會停下，維持資料安全優先。
- 人工通知可能無法即時抵達原 Session。PR 保存完整交接資料，缺少通知能力時保留待交接狀態，不假裝自動喚醒。

## TDD strategy and verification boundaries

1. 共用契約與 Skills 以固定 fixture／模擬回覆先保存預期呼叫、禁止及判定。案例覆蓋 gh 與 MCP 的等價流程、只有另一工具登入、可讀但寫入拒絕、權限資訊不完整、未配置工具、可選指定帳號不符／未知、repo／fork 目的錯誤、部分成功及跨通道 timeout reconciliation。選工具不建立新的授權。
2. installer／contract 變更用受影響的既有測試先取得有效 Red，再改 template；檢查撤除 script／blob 強制前提、managed doc／SVG、rule mirror、Claude Code／Codex／Antigravity 入口可達、無關 scripts／WI／認證配置保留。不以 grep 通過當成 Agent 行為驗收。
3. F-01 保留「秘密不進輸出／報告」的驗收；F-02、F-03 所涉 parser 以刪除依賴解決，不再擴充 parser 接受更多認證設定。W-01 的完整 repo／fork 核對仍須實作。舊報告與歷史驗證不改寫成新設計已通過。
4. Skill 決策用正常 Agent 讀取去除答案的 fixture 逐案重播，記錄實際工具／模型與比對者。去敏證據寫 `docs/verification/github-handoff/<run-id>.md`，採 OKF Reference metadata、sources、實際結果及限制；tasks／PR 連到已提交版本。
5. 在已授權測試 repository，以至少一個當前可用的 GitHub 通道真實驗證建立／精確查重／更新保留、Git 發布與 remote head、無 WI 接手。未提供另一通道時以模擬覆蓋其決策並標明未實測，不為湊測試安裝、登入或變更認證。Git 既有 SSH 或 HTTPS 路徑任一可用即可，不要求解碼認證或每種路徑實測。
6. 完成必要專案檢查、嚴格 OpenSpec 驗證、連結與 SVG XML／渲染檢查，對修訂後實作提供新 head Review。模擬不能當真實寫入，操作成功不能推導部署／資料驗收完成。

## Migration Plan

1. 本次使用者已要求更新此方向並交由 Claude 調整；此授權涵蓋本版目標／工具／可選帳號限制的設計與實作，不新增 commit／push／merge／archive 授權。PR 舊批准事件須保留並標明不涵蓋本次實質修訂；依既有具名代記規則另記新版本與範圍，不能挪用舊 revision。
2. 依 tasks 在 template 實作，更新 installer 清單及局部 docs，先在暫存 target 驗證，再透過 installer 安裝本 repo。
3. 現有 Issue／PR 不批次改寫，首次明確 update 時才採用受管理區塊；本機 Work Item 不搬移或刪除。
4. 第一個 Change 驗收後，第二個 Change 才整合 Review Skill。若回退，回復本 Change 的 template／installer 修改並重裝；不自動刪除遠端 Issue、PR、留言或使用者配置。

## Open Questions

測試 repository、各機器的 gh／Git 版本與身分設定、三種工具的 Session 定向通知能力，仍由測試或使用者配置提供。GitHub 通道依當前可用工具選擇；缺少所需能力或明確被拒時回報。選用指定帳號及批准記錄者的授權來源分別處理，不預設所有專案需要同一帳號政策。

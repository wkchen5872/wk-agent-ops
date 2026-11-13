# Design

## Context

這是待人類審閱的目標設計，尚未實作；動機與驗收範圍見 [proposal.md](proposal.md)。

本機已確認的接入點如下。

- `template/common/skills/` 已由 `scripts/skills/install.sh` 整目錄同步至 `.claude/skills/` 與 `.agents/skills/`，不需新增安裝引擎。
- installer 的 `MANAGED_FILES` 決定既有專案會更新哪些共用文件；其餘文件只是 seed。新契約必須加入 managed 清單。
- `git-commit-writer` 會 `git add -A`，其 archive 參數為成對輸入，並不檢查推送帳號。PR 入口必須在委派前檢查完整 dirty 範圍與身分，不假設 writer 已處理。
- `template/common/work-items/AGENTS.md` §9 要求 Review 先寫本地，與 PR 作正式交接入口需明確分流；WI 的本地儲存／不可同步規則保持不變。
- 本機尚無專案自訂 Issue／PR Skill 或共用帳號檢查腳本。第一版的 GitHub 操作統一走 `gh`，每台機器分別準備 CLI、Git／SSH 與已授權身分；不能以本機設定替未來機器背書。

## Goals / Non-Goals

**Goals:**

- 用兩個入口與一份契約完成格式適配、帳號檢查、關聯查重、版本發布及摘要更新。
- 人工可以逐階段啟動；同一份資料也可讓之後的 Review Skill 使用。
- 明確區分「已在本機完成」「已發布到指定 remote」與「已驗收」，失敗後能回報已完成的步驟而不盲目重做。

**Non-Goals:**

- 不建立多機 scheduler、Session registry、GitHub client、看板同步或通用 hook。
- 不更改 Git Commit Writer 的 standalone 行為或 runtime model，也不修改第三方 Skills。
- 不由本 Change 實作 Review 判斷與通知器；它們由下一個 Change 或既有工具負責。
- 不支援 GitHub MCP 或執行中自動切換後端；未安裝 `gh` 時回報必要工具缺漏，不自行安裝、登入或改帳號。

## Decisions

### 1. 一份 managed 契約，兩個薄入口

`template/common/docs/github-handoff.md` 是欄位語意、範本、帳號核對、更新規則及完整操作手冊的唯一來源。兩個 Skill 與未來 Review Skill 只引用它，不各存一份 schema。installer 明列此文件為 managed；protocol 加按需短連結，OpenSpec workflow 說明 GitHub 流程是可選交接方式，不能強制所有專案開 Issue。

第一版由 Markdown Skill、共用唯讀帳號檢查腳本與既有 `gh`／`git` 組成。GitHub 的建立／更新／Review 直接呼叫 `gh`，需要精確 API 欄位時使用 `gh api`；不新增 API client、通用工具適配層或 MCP 分支。檢查腳本只收集及比對證據，不建立 Issue／PR 或包辦整個工作流。

兩個薄入口承接使用者後續明確提出的「建立 git issue skill」與「建立 git pr skill」，以及 PR 按需委派 writer 的需求。先前工具重用決策的核心仍適用：原生工具執行操作，專案持有格式。入口補足每次需手動重貼的格式、D-004 身分核對與 stage-all 範圍檢查；單獨一份契約可人工使用，但不滿足這次要求的可呼叫入口。這不是另建 GitHub API client，也不表示設計已批准實作。

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

Issue、PR、Review 的讀取與遠端寫入皆使用同一 `gh` 執行上下文，明確指定 host／repository，不依賴 CLI 自動選取另一個 repo。Git Commit Writer 仍負責 `git commit`，發布步驟負責 `git push`；API actor 與 Git push actor 保持分別核對。任何必需的 `gh` 能力／權限不足即停止該操作，不改用 MCP。

### 3. 關聯以現有 GitHub 紀錄為準，不新增追蹤資料庫

Issue／PR 的 managed 區塊包含精確鍵 `openspec-change: <change-id>` 與 `repository: <host>/<owner>/<repo>`，並保存 repo-relative artifact path、已發布時的 revision 連結及可選 WI ID。Issue 另放父子／依賴與下一步；PR 另放 Issue、phase 與實際 head。搜尋只是候選發現，必須讀取 body 比對鍵值、repository 及明確 URL／head 分支才能確認關聯，不能只靠相似標題或模糊搜尋結果。

先查既有映射再建立；多候選停止選擇。遠端 timeout 後重新查核，不直接重送 create。本地可回填 WI 連結，但正式紀錄不依賴它，不新增需再次 commit 的 Change↔Issue 對照檔。尚未 push 的規格填「local-only／待發布」，不編造 commit URL；發布後更新遠端連結。

### 4. 以實際操作通道核對帳號

預期身分來自本次明確輸入，或使用者已選定的可信基準版本 `AGENTS.md` 中的 `## GitHub handoff identity` 區塊。建立寫入上下文時先固定 `policy_source` 的 commit／檔案指紋；Review 使用預設分支的已信任版本或使用者另行指定的政策版本，不能讀取被審查 PR head 對該區塊的修改作為新授權。既有本機 checkout 也不自動等於可信；來源不清楚時需釐清，不能自選另一版本。

該區塊採下列 YAML 欄位形狀，尖括號僅表示範例。第一版每次操作只解析一組明確 profile；多位使用者／多機器可各自提供本次輸入，不從清單猜選。

```yaml
host: <GitHub host>
repository: <owner/repo>
api_actor: <expected login>
commit_author: { name: <expected name>, email: <expected email> }
commit_committer: { name: <expected name>, email: <expected email> }
push: { remote: <selected remote>, protocol: <ssh|https>, actor: <expected login> }
```

Issue／正文更新／Review 發報告只要求前三項；commit／push 才要求其餘對應項目。PR base／head repo 另由本次明確 PR 輸入核對，不推定 fork 與 base 同 repo。第一版不新增專用設定檔或自動寫入設定，不從 Issue／PR 內容接受新的認證政策。已有明確且可信的宣告就沿用；缺少或衝突只停受影響寫入。

檢查資料包含下列內容。

| 面向 | 預期值及實際證據 |
| --- | --- |
| Repository | host、owner／repo、PR base repo 與 head repo；組織 owner 不等於登入帳號 |
| API | 本次 `gh` executable、host 與環境對應的實際 API actor；與 push 身分分開查證 |
| Commit | 在相同執行上下文解析有效 author／committer name、email 與來源，包含環境覆寫及 worktree／includeIf |
| Push | 選定 remote 的實際 push URL、分支目的地與 SSH／HTTPS 認證者，不假設固定使用 origin |

允許各角色是不同的預期帳號，不要求 email 等於 GitHub login。以下是第一版的 push 驗證邊界，網路唯讀驗證不等於 push，使用者聲明的「預期帳號」也不等於實際認證證據。

| 實際通道 | 可接受證據與判定 | 無法確認時 |
| --- | --- | --- |
| GitHub SSH 使用者 key | 先解析該 remote 的 push URL、host alias／port 與有效 SSH command／key-selection options，再用相同設定執行無遠端命令的 `ssh -T` 認證測試。只接受已信任 host key、非互動模式與 GitHub 回傳帳號相符的成功問候；GitHub 此測試成功時仍可能 exit 1，須看訊息而非只看 exit code。不可強制改 key、跳過 host-key 檢查或擅自寫 known_hosts。 | 新 host key、互動解鎖、無法重現 Git 的 SSH 設定、模糊問候或非使用者 key 皆 blocked，不把 URL 的 `git` 當登入者。 |
| HTTPS 且有效 helper chain 僅使用已辨識的 `gh auth git-credential` | 在相同 executable、host、環境與帳號上下文執行 `gh api --hostname <host> user --jq .login`。先確認 URL 沒有內嵌 credential、無其他 helper／auth header／askpass／自訂 wrapper 會接管認證，且工具版本的 helper 確實取同一 active token。只保存 login 與配置來源，不執行會列出 password 的 credential fill。 | 任一通道或 token 選擇無法對應就 blocked；`gh auth status` 或 API login 本身不足以替任意 helper 背書。 |
| osxkeychain、其他 helper、混合／自訂認證、deploy key 或 App token | 第一版沒有通用的無秘密 principal 驗證方法，標記 unsupported，而非猜測該 credential 的主人。 | 只停 push，回報可另行選擇的已驗證通道；不讀出 keychain credential、不自動 setup-git／switch／改 remote，也不把使用者聲明冒稱實測。 |

SSH 的可接受回應依 [GitHub 官方測試文件](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection)；helper 多值與空值 reset 依 [Git credentials 文件](https://git-scm.com/docs/gitcredentials)。HTTPS 的限縮路徑依已查讀的 [gh helper 原始碼](https://github.com/cli/cli/blob/trunk/pkg/cmd/auth/gitcredential/helper.go) 與 [gh API 文件](https://cli.github.com/manual/gh_api)形成；這是本專案的保守設計，需在實作時核對安裝版本並實測，不表示本機帳號已驗證。認證上下文在檢查後變更時重新核對。

標準 SSH 通道的操作形狀如下，執行目錄為該專案根目錄，尖括號必須先依實際 push route 替換。若 Git 使用額外 `-F`／key-selection 設定，測試也必須保留相同設定；不能安全組合時走 blocked，而非直接執行任意配置字串。

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -p <port> <ssh-user>@<push-host-alias>
```

預期是 GitHub 顯示認證帳號的成功問候，並按官方文件處理 exit 1；Permission denied、新 host-key 要求或其他訊息都不算通過。此測試只辨識認證者，不證明 repository 寫入權限或推送已完成。本輪僅定義步驟，沒有執行此連線。

### 4a. 共用腳本收集證據，Skill 與規範決定是否寫入

唯一腳本來源為 `template/common/scripts/github/check-identity.sh`，由 installer managed 為專案 `scripts/github/check-identity.sh`，三個 Skill 共用。腳本採 Bash，輸入為明確 CLI arguments，接收 `--operation api|commit|push`、對應的預期 host／repo／actor／commit identity／remote 與 `policy_source`；Skill 從已信任的政策版本解析所需值再傳入，不讓腳本解析自由敘述或接受 PR 自授權。

腳本從 `CLAUDE_PROJECT_DIR`，否則 `PWD` 尋找實際 Git project root，並確認它符合本次指定目標；參數、cwd、預期政策或執行檔來源不明時停止。caller 必須使用已信任的安裝版本，不能直接執行候選 PR 修改的腳本來替該 PR 背書。第一版不建立新的政策 registry 或憑證存放。

PR checkout 的標準取得方式如下，不切換、修改或清理被審查的工作區。

1. 先將可信 `policy_source` 固定為完整 commit ID，並從該版本解析 `scripts/github/check-identity.sh` 的 blob ID／檔案類型。只接受一般檔案，不能把 symlink 或候選 head 的同名檔當可信程式。
2. 使用 `git cat-file blob <trusted-commit>:scripts/github/check-identity.sh` 將該版本取到本次專用暫存目錄，並核對 blob ID／內容指紋。此處指向已信任 revision，不是 PR head；不執行任意配置字串或 Git hook。
3. 執行取出的腳本時，cwd 與本次 `CLAUDE_PROJECT_DIR` 仍指向要檢查的 PR checkout；腳本來源來自可信版本，身分與 remote 證據則來自真正將操作的 checkout／環境。紀錄 `script_source` 的 repo-relative path、commit／blob ID 與目標 checkout，不公開暫存絕對路徑。
4. 本次結束只清理自己建立的暫存目錄，不碰其他工作區。可信版本沒有該腳本時，不回頭採用候選版本：可沿用使用者已明確信任、且指紋已固定的既有安裝來源；首次交付尚無可信來源時，回報 bootstrap 缺口，直到使用者明確信任該腳本快照。已授權來源及內容未變時不逐次重問。

| operation | 收集與比對 | 結果如何使用 |
| --- | --- | --- |
| api | `gh` host／repository 與同執行上下文的實際 API login | Issue／PR／Review／說明更新每次遠端寫入前檢查 |
| commit | 有效 Git author／committer 與來源，包含環境覆寫 | 本流程委派 writer 前檢查；不改 standalone writer 契約 |
| push | 實際 push URL／remote／ref、SSH 或 HTTPS 認證證據 | 真正 push 前依 Decision 4 的可接受證據檢查 |

結果採簡短固定文字欄位與退出碼，包含 operation、status、policy_source、目標及已取得的非秘密證據／失敗原因。`0=pass`，`2=mismatch`，`3=unverified`；錯參數或執行錯誤為 `1=error`。缺少必要工具、unsupported 通道或不足的認證證據都不能回傳 pass。只有該 operation 的結果為 pass，Skill 才可執行原已授權的寫入；GitHub 權限、變更範圍及測試仍由各流程另查，不把 preflight 當全面授權。

腳本不 staging、不 commit／push、不建立遠端內容，不改 Git config、登入、key 或 remote，不輸出 credential／token。API 與 SSH 認證查證可以唯讀連網，但必須由該次 Skill 明確呼叫，並在寫入前確認上下文未改；不能把舊機器／舊環境的 pass 當永久憑證。

共用契約及 managed protocol 要求本流程各次寫入前檢查；`template/common/.claude/rules/github-handoff.md` 只作短指標，沿用 installer mirror 到 `.agents/rules/`，Codex 由既有 AGENTS → managed protocol 取得相同規範。第一版不加 Git／provider hook，rule 本身不宣稱能封鎖所有手動入口。未來若加 pre-commit，只能做離線本機檢查，不能把本腳本的連網驗證直接塞入 hook。

### 5. Writer 委派前確認整個工作區

create／publish 先盤點 staged、unstaged、untracked 與 base-to-head diff。因 writer 會 stage all，只有所有未提交內容都屬本次授權範圍時才可呼叫。遇到其他 Change／Agent 的檔案，停止並報告清單，不自動 stash、reset 或移動檔案。

活動 Change 使用 writer 現有 branch／staged-path 關聯，不只傳 `change_id` 作 archive context；建立規格 PR 與一般實作版本不需要先 archive。最後的 archive 交付依 Decision 8 另行處理；已 archive 時從精確目錄／PR 關聯取得原 Change，不要求活動目錄仍在。提交 attribution 傳當次已知 root model，通過既有 pre-commit gate。commit 後重新取得實際 head／diff，再 push，核對 remote head 後才建立或更新 PR。已 commit 但 push 失敗須分別報告，重試不重造 commit。

### 6. 正文只維護當前摘要，報告各自保存

Issue／PR 的共用區塊使用固定起訖註解，例如 `<!-- wk-agent-ops:handoff:start -->` 與 `<!-- wk-agent-ops:handoff:end -->`。更新時讀取最新正文、保留區塊外內容，再由 `gh` 寫回完整 body。缺少或重複 marker 時不猜；既有未管理正文由使用者明確指定採用區塊後才更新。

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

PR managed 區塊另含 `design-approval`，初始 `status: pending`。批准時記 `approved_by`、`approved_at`（含時區，未知則 null）、`approved_scope`、`artifact_revision`／必要文件指紋、`source_kind`、可取得的來源參照、`recorded_by` 與 `recorded_at`。批准依據可採下列兩種形式。

- `human-github`：使用者本人可取得的 PR 留言或原生 Review。
- `agent-attested-user-instruction`：已授權 Agent 代記使用者在對話中的明確批准。使用者已選擇信任這種具名代記，新機器不需要取得原始對話逐字稿，也不強制人類再到 GitHub 留言。

代記須真實指出人類批准者、範圍、版本與來源類型，不能由 Agent 技術 pass 自行推導。預設受信任發布帳號為可信 identity policy 的 `api_actor`，或使用者另行明確授權的記錄者；不能從候選 PR 的新政策自我授權。代記事件以獨立 PR comment 保存，透過 GitHub 的實際 comment author 核對發布帳號，正文記 Agent／Session 與記錄時間，managed 摘要連到該 comment。不能只憑 PR body 中的 `recorded_by` 字串認定發布者，也不冒稱人類本人在平台留言。

新 Session 在帳號受信任、紀錄完整、適用範圍與設計版本一致時，將具名代記視為有效批准依據；信任的是已授權者的明示代記，不是宣稱原始對話可獨立重播。未授權發布者、僅技術結論、pending、缺乏必要範圍／版本或 superseded 的紀錄均不授權 Apply。不得偽造時間、批准者或私有 transcript URL；需求／設計實質改變時保留原事件並標記 superseded，取得新批准後新增事件。

### 8. 第一版以同張 PR 的兩個階段示範，不綁死拓撲

[流程與責任 SVG](diagrams/handoff.svg) 展示人工斷點。標準簡單案例為 Change → Issue → commit／push 規格 → Draft PR → design Review → 人類設計批准 → Apply → publish 實作版本 → implementation Review／修正複審。需要分開設計 PR 的既有工作可透過明確關聯處理，不自動拆 PR，也不以設計 PR 合併取代後續實作驗收。

Reviewer 以 `gh` 發布 Review／留言，先呼叫共用腳本的 api 檢查，不調用 PR create／publish。報告發布後仍需明確 Session 通知；沒有可用通知器時交給使用者啟動／轉交，記錄 delivery 未完成，不能聲稱通知成功。Draft／Ready、merge、deploy、archive 和 Issue close 分別依授權處理。

第一版預設回傳可轉交訊息，包含 PR／報告 URL、head、Finding IDs 與下一步；已確認且可用的 Session 定向工具才加強為直接通知。repo 的 Telegram／等待提示不當成 Session 訊息通道，這次不承諾三種工具都有定向通知。

等待資料的 Issue 分開記錄交付與驗收狀態。第一版範本使用 `Refs #N` 關聯，不預填自動關閉語句；即使 implementation Review pass，也必須檢查是否仍有部署／資料驗收責任。等待日期只是最早可檢查時間。

archive 的交付順序另有明確斷點：一般 implementation Review／verify 通過只代表當時 head。已具備 archive 條件且取得授權後，呼叫既有 `openspec-commit` 完成 archive → doc-updater → commit，再由 `github-pr publish` 核對並 push 既有 commit，不重新 archive 或建立空 commit。Reviewer 必須對新 head 做最終差異複審；只有可證明為搬移、spec 同步及相應文件修訂時才縮小範圍，任何語意變動都擴大必要檢查，最後報告須綁最終 head。

預設在尚未合併的同一 PR 完成這次交付複審。若必要資料驗收尚未完成，不為了結案提前 archive；若另有批准的先 merge／後 archive 流程，後續變更需要明確授權的 follow-up PR，不能把新 commit 推到已關閉 PR 就宣稱已完成審查。範圍不變的設計批准仍可引用原紀錄。

### 9. 文件及圖稿一起 managed

實作時的正式來源為 `template/common/docs/github-handoff.md`、`template/common/docs/diagrams/github-handoff.svg`。下游 `docs/github-handoff.md` 引用同層 `diagrams/github-handoff.svg`；兩條路徑一起列入 `MANAGED_FILES` 並測試第二次安裝都會更新。Review 專用圖另放 `template/common/skills/change-review/references/review-loop.svg`，隨 Skill 整目錄同步，不新增一個只 seed 的 docs 圖。

`scripts/github/check-identity.sh` 同列 managed，沿用既有支援非 docs 路徑的機制，不另建 installer；來源腳本須可執行且安裝後保持。測試涵蓋初裝／更新、執行權限及無關 script 保留。薄 rule 沿用既有 mirror，同時檢查 Codex 的共用 protocol 指標，不只以 `.agents/rules/` 存在宣稱已啟用。

## Risks / Trade-offs

- Agent 指令不能保證所有手動入口遵守格式。以可重播案例驗收，未加入 repo 強制檢查前不得聲稱所有 Issue／PR 已受控。
- 多帳號與自訂 Git 認證可能缺乏完整 actor 證據。腳本回報 unverified，停止相應寫入；不以 gh API login 代替 SSH／其他 HTTPS helper 的 push 身分。
- 先讀後寫可能覆蓋同時編輯。指定單一摘要維護者，Reviewer 分別寫報告；不新增分散式鎖。
- 查重搜尋可能漏掉剛建立的紀錄。優先使用明確 URL／已返回的遠端 ID；timeout 不盲目重送。
- 第一版不改既有 writer 的 stage-all 行為。有混合 dirty 工作時 PR publication 會停下，維持資料安全優先。
- 人工通知可能無法即時抵達原 Session。PR 保存完整交接資料，缺少通知能力時保留待交接狀態，不假裝自動喚醒。

## TDD strategy and verification boundary

1. 對腳本新增 `tests/test_github_identity.sh`，沿用既有 PATH stub 方式提供假的 `git`／`gh`／`ssh`，先以錯帳號、工具缺漏、未支援認證、有效 Git config 覆寫、SSH 成功但 exit 1 等具體行為取得 Red，再實作最小腳本。斷言 status／退出碼與去敏證據，並以呼叫紀錄證明無寫入／登入切換／憑證輸出。這是腳本單元行為驗證，不冒稱真實認證成功。
2. 對 installer managed 文件／SVG／script 與 rule mirror 行為先寫暫存 repo 測試，確認初裝、重裝更新、權限及未知內容保留，取得預期 Red 再實作。
3. Skill 為 Agent 指令，第一版不新增 Agent harness。依 protocol 的「自動化不可行」替代路徑，手動情境放在各 Skill 的 `references/acceptance-cases.md`，共同案例格式／操作方法由本契約定義。每案含 case-id、輸入 fixture、固定模擬回覆、預期的 script／gh／git 呼叫與參數、禁止呼叫及 pass／fail 條件。用正常啟動的 Agent Session 讀取案例並產生下一步，人工逐項比對，任何禁止呼叫即失敗；實際模型／工具版本如實記錄。
4. 情境是離線決策驗收，模擬結果不能宣稱真的查過帳號、發過 PR 或呼叫過工具。每輪去敏的輸入、實際回覆／呼叫摘要、預期差異、case 結果及已知限制寫在專案正式 `docs/verification/github-handoff/<run-id>.md`，PR 連到已提交版本；tasks 只記進度與證據連結，不能只放 Work Item。不把手動觀察硬寫成自動測試的 Red／Green。

   每次 run 文件採 OKF `type: Reference`，包含 title、description、tags、實際 producer／時間的 generated，以及可對應案例／版本／證據的 sources。它是帶時間與版本的歷史驗證紀錄，不套用「只保留目前有效設計」的正文規則；不修改舊 run 來追認後來結果，也不新增一種 OKF type 或默認豁免 metadata。
5. 更新 `tests/test_agents_dir.sh`、`tests/test_work_items.sh` 的受影響案例，或以同風格新增 `tests/test_github_handoff.sh`，檢查 contract 與 installer；不以 grep 測試替代 Agent 的決策或 gh 實際操作。
6. 真實 `gh` 寫入只在明確授權的測試 repo 執行，驗證建立／重試／更新保留、實際 API actor、Git push actor、PR head 及跨 Session 接手；MCP 不是本版驗收分支。離線案例不替代 tasks 5.1 的真實整合驗收。
7. 每個 task 記錄檢查結果；完成前執行專案必要檢查、嚴格 OpenSpec 驗證、文件連結檢查。SVG XML 與渲染檢查分開記錄。

## Migration Plan

1. 人類審閱此設計，尤其是操作副作用、帳號預期來源與 provenance 公開範圍；這次建立文件不等於批准實作。
2. 依 tasks 在 template 實作，更新 installer 清單及局部 docs，先在暫存 target 驗證，再透過 installer 安裝本 repo。
3. 現有 Issue／PR 不批次改寫，首次明確 update 時才採用受管理區塊；本機 Work Item 不搬移或刪除。
4. 第一個 Change 驗收後，第二個 Change 才整合 Review Skill。若回退，回復本 Change 的 template／installer 修改並重裝；不自動刪除遠端 Issue、PR、留言或使用者配置。

## Open Questions

測試 repository、各機器的 gh／Git 版本與身分設定、三種工具的 Session 定向通知能力，仍由測試或使用者配置提供。GitHub 通道已固定為 gh；缺少必要工具或身分證據時停止相應寫入，不以尚未確認的 MCP 分支替代。

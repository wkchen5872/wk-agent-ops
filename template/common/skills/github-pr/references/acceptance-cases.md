# github-pr 可重播案例

案例格式、重播方式與證據位置由 `docs/github-handoff.md` 第 12 節定義。這些是離線的決策
驗收：模擬回覆不代表真的寫入 GitHub。出現任何「禁止」項目即失敗。

GP-01–GP-20 是舊版 create／publish（含 commit 與 push）的案例，已隨 publish 一起移除；
這些編號不重用，歷史驗證紀錄中的引用維持原意。現行 create 會做必要的 commit 與 push，
案例見「create 的必要發布」一節。

共同 fixture（案例另有說明時以案例為準）：repository 為 `github.com/acme/widgets`，base 為
`main`，head 與 base 在同一個 repository。沒有明示的帳號限制。可用工具為已登入
`octo-dev` 的 `gh`；GitHub MCP 是否可用依案例說明。貼文工具為 Claude Code，當下模型為
`Claude Opus 5.5`。runtime 提供原生 Session ID `sess-7781`（`CLAUDE_CODE_SESSION_ID`）與
Xirp 管理 ID `xirp-42`（`CHIRP_SESSION_ID`），兩者都屬於本次貼文 Session 且可以公開。委託的
使用者沒有確認可公開的 GitHub 帳號，所以 Author 不寫 `人類`。正文與回覆依契約第 6 節的共同外框
（Handoff → 主體 → Next actions → Author）。案例中的 repo、編號、名稱、版本與 ID 全部是虛構的。

「核對」指契約第 3 節的步驟 1–4。「查 PR」指 `gh pr list --head <branch> --state all --json
…,headRepository,headRepositoryOwner,baseRefName,isCrossRepository` 並讀取候選。「讀比較」指
`gh api --hostname github.com repos/acme/widgets/compare/main...<head-owner>:<branch>`。其他
`gh` 呼叫都帶 `-R github.com/acme/widgets`（`gh api` 以 `--hostname` 指定 host）。所有案例的共同禁止：`gh pr merge`、`git push --force`、
`--no-verify`、刪除分支、reopen、改 remote 或認證設定。update、reply、close 的案例另外禁止
任何 `git add`、`git commit`、`git push` 與 commit writer。create 在需要時做的 commit 與 push
只能包含本次工作，並遵守「create 的必要發布」一節的規則。

## 來源到內容

這三例提供完整來源實文與一份合格的產出 PR，驗收**內容品質**。產出是參考答案，不要求
逐字相同，以「內容判定」逐項判斷。共同內容判定：

- 內容判定：沒有參與原對話的人讀完能理解問題與影響、範圍、這個版本實際的改變或設計、怎麼檢查結果，以及還沒決定或尚未發布的部分（素材有的才寫）；Handoff 有 `branch`，其他關聯只在已確認時出現，沒有 `null` 佔位；沒有沿用紀錄格式（Sessions、Coordinator、決策編號、各 Agent 的下一步）；沒有把 tasks 的群組或編號刪短後貼上；沒有素材以外的決策、數字或測試結果；Next actions 對應這個發布版本且不捏造負責人；Author 是本次貼文者。

### GP-30 Work Item、對話新決策與未發布的修改

- Fixture：使用者說「用 WI-20261105-export-retry 開 PR」。head `feature/export-retry`，remote head `a3f1c2e`。沒有 Change、沒有 Issue、沒有既有 PR。
- 來源實文：

  `work-items/WI-20261105-export-retry/README.md`

  ```markdown
  ---
  id: WI-20261105-export-retry
  title: 夜間匯出逾時重試
  status: active
  openspec_change: null
  coordinator: claude-s01
  ---

  # 夜間匯出逾時重試

  ## Goal and Scope
  夜間 02:00 的訂單匯出排程在月底資料量大時逾時（上限 30 分鐘），整批失敗且不會重試，
  隔天早上客服拿不到前一日報表，要人工重跑。範圍：逾時與暫時性錯誤的自動重試、連續失敗
  通知。不處理：匯出格式、排程時間。

  ## Sessions
  - claude-s01（Claude Code）：Coordinator
  - codex-s02（Codex）：實作

  ## Current Summary
  - 重試上限 5 次，固定間隔 10 分鐘（D-01）
  - 連續失敗後通知 #ops-oncall
  - 重試會重複寫入同一天的檔案，codex-s02 準備加上「同日檔案已存在就覆寫」的保護

  ## Next Actions
  - codex-s02：完成冪等保護
  ```

  本輪對話：

  ```text
  使用者：重試 5 次太久，改成最多 3 次，間隔一樣 10 分鐘。這個確定。
  Agent：好，程式已經改成 3 次並 push 了。冪等保護我還在本機改，還沒 commit。
  使用者：那先開 PR，冪等那段之後再推。
  ```

  讀比較的結果（`a3f1c2e`）：`jobs/export_orders.py`、`jobs/retry.py`（新增）、`tests/test_export_retry.py`（新增）。`jobs/retry.py`：`MAX_ATTEMPTS = 3`、`INTERVAL_SECONDS = 600`，只對 `TimeoutError` 與 `TransientDBError` 重試，全部失敗時 `notify("#ops-oncall", …)`。CI 在 `a3f1c2e`：`tests/test_export_retry.py` 6 passed。本機 `git status`：`M jobs/export_orders.py`（未 commit 的冪等保護）。

- 模擬回覆：查 PR 沒有結果；讀比較 `ahead_by: 2`；`gh pr create` 回傳 `…/pull/21`；回讀的 head owner、repository、base 與 `a3f1c2e` 相符。
- 預期呼叫：直接讀取 Work Item → 整合對話 → 核對 → 查 PR → 讀比較 → `gh pr create --draft --base main --head acme:feature/export-retry …` → `gh pr view 21 --json url,headRefOid,body,headRepository,headRepositoryOwner,baseRefName,isCrossRepository`。
- 產出 PR：標題「夜間訂單匯出逾時後自動重試」，正文：

  ```markdown
  ## Handoff

  - branch: feature/export-retry
  - work-item: WI-20261105-export-retry（local-only）

  ## Summary

  每天 02:00 的訂單匯出排程上限是 30 分鐘。月底資料量大時會逾時，整批失敗而且不會重試，
  客服隔天早上拿不到前一日的報表，只能等人工重跑。這張 PR 讓逾時與暫時性錯誤自動重試，
  重試用完仍失敗時通知值班人員。匯出格式與排程時間不在範圍內。

  ## Changes

  這個版本（`a3f1c2e`）：

  - 只對逾時（`TimeoutError`）與暫時性資料庫錯誤（`TransientDBError`）重試，最多 3 次、
    每次間隔 10 分鐘；其他錯誤照原樣失敗。
  - 3 次都失敗時通知值班頻道 #ops-oncall。

  ## Verification

  - `tests/test_export_retry.py` 在 `a3f1c2e` 的 CI：6 passed。

  ## Not yet published

  - 防止重試重複寫入同一天檔案的保護還在本機修改、尚未 commit，不在這個版本。推上來
    之前，重試仍可能重複寫檔。

  ## Next actions

  Reviewer 對 `a3f1c2e` 檢查重試與通知行為；冪等保護推上來後再更新本說明並安排差異審查。

  ## Author

  方式: Agent 協助
  Co-Authored-By: Claude Code
  AI-Assisted-By: Claude Opus 5.5
  SESSION-ID: sess-7781
  XIRP-SESSION-ID: xirp-42
  ```

- 禁止：共同禁止；把「最多 5 次」寫成現行做法；把冪等保護寫成這個版本的內容或為它列測試結果；出現 `claude-s01`、`codex-s02`、`D-01`；寫 `openspec-change: null` 或 `issue: null`。
- 內容判定：3 次來自對話中後來確認的決策；冪等保護明確標為尚未發布並說明影響；驗證只列 `a3f1c2e` 的實際結果。
- 判定：建立一張 Draft PR，內容符合共同與本例的內容判定。

### GP-31 只有 Change 的設計 PR

- Fixture：使用者說「為 add-export 開設計 PR」。head `feature/add-export`，remote head `d1e2f30`。沒有 Work Item、Issue 或既有 PR；本輪對話沒有其他內容。
- 來源實文：

  `openspec/changes/add-export/proposal.md`

  ```markdown
  ## Why
  客服要回覆對帳問題時，只能在後台訂單列表逐筆複製到試算表，一次對帳平均花 40 分鐘，月底常有錯漏。

  ## What Changes
  - 訂單列表新增「匯出 CSV」，依目前的篩選條件與日期區間匯出
  - 超過 5,000 筆時改用背景工作產生，完成後站內通知並提供 24 小時有效的下載連結
  - 匯出權限沿用「訂單檢視」權限
  ```

  `openspec/changes/add-export/design.md`（節錄）

  ```markdown
  ### D1 同步與背景門檻 5,000 筆
  同步匯出超過 5,000 筆時，回應會超過閘道 30 秒上限。
  ### D2 欄位與列表一致
  欄位順序沿用列表目前的可見欄位，不另做欄位設定。
  ### Open Questions
  - 背景檔案要放現有的物件儲存 bucket，還是另開一個；等維運回覆。
  ### Non-Goals
  - 不做 Excel 格式、不做排程自動匯出
  ```

  `openspec/changes/add-export/tasks.md`

  ```markdown
  ## 1. 同步匯出
  - [ ] 1.1 新增 export endpoint，套用列表篩選條件
  - [ ] 1.2 CSV 序列化，欄位依可見欄位順序
  - [ ] 1.3 檔名 orders-YYYYMMDD-YYYYMMDD.csv
  - [ ] 1.4 權限檢查沿用 orders.view
  ## 2. 背景匯出
  - [ ] 2.1 超過 5,000 筆時建立 export job
  - [ ] 2.2 job 完成寫入物件儲存，產生 24 小時簽名連結
  - [ ] 2.3 站內通知
  - [ ] 2.4 job 失敗時通知並可重試
  ## 3. 前端
  - [ ] 3.1 列表新增匯出按鈕與筆數提示
  - [ ] 3.2 背景匯出進行中的狀態顯示
  ## 4. 測試
  - [ ] 4.1 篩選條件與欄位順序的單元測試
  - [ ] 4.2 5,000 筆門檻的整合測試
  - [ ] 4.3 權限不足回 403
  - [ ] 4.4 簽名連結過期測試
  ```

  讀比較的結果（`d1e2f30`）：只有 `openspec/changes/add-export/` 下的 proposal、design、specs、tasks。

- 模擬回覆：查 PR 沒有結果；`gh pr create` 回傳 `…/pull/12`；回讀相符。
- 預期呼叫：讀取 proposal、design、tasks → 核對 → 查 PR → 讀比較 → `gh pr create --draft --base main --head acme:feature/add-export …` → 回讀。
- 產出 PR：標題「設計：訂單列表匯出 CSV」，正文：

  ```markdown
  ## Handoff

  - branch: feature/add-export
  - openspec-change: add-export

  ## Summary

  客服回覆對帳問題時，只能從後台訂單列表逐筆複製到試算表，一次平均花 40 分鐘，月底常有
  錯漏。這張 PR 提出讓客服直接把目前篩選出的訂單匯出成 CSV 的設計，請先審查設計；這個
  版本只有設計文件，沒有程式碼。

  ## Design

  - 依列表目前的篩選條件與日期區間匯出，欄位與順序沿用列表的可見欄位，不另做欄位設定。
  - 超過 5,000 筆改在背景產生，完成後站內通知並提供 24 小時有效的下載連結。同步匯出超過
    5,000 筆會超過閘道 30 秒上限，所以以此為門檻。
  - 只有具「訂單檢視」權限的人能匯出。
  - 不做 Excel 格式，也不做排程自動匯出。

  ## Open questions

  - 背景產生的檔案要放現有的物件儲存 bucket 還是另開一個，等維運回覆。

  ## Next actions

  Reviewer 對 `d1e2f30` 做設計審查；通過後仍需使用者明確指示實作才能開始。

  ## Author

  方式: Agent 協助
  Co-Authored-By: Claude Code
  AI-Assisted-By: Claude Opus 5.5
  SESSION-ID: sess-7781
  XIRP-SESSION-ID: xirp-42
  ```

- 禁止：共同禁止；聲稱已實作或已測試；列出 tasks 的群組、編號或「共 16 項」；寫 `work-item: null` 或 `issue: null`。
- 內容判定：清楚說明這是設計版本；設計重點附上門檻的理由；未決事項保留；不處理的事項來自 Non-Goals。
- 判定：建立一張 Draft PR，內容符合共同與本例的內容判定。

### GP-32 沒有追蹤資料，只有分支與對話

- Fixture：使用者說「把這個分支開 PR」。head `fix/refund-search`，remote head `b77c9d0`。沒有 Work Item、Change、Issue 或既有 PR。
- 來源實文：

  本輪對話：

  ```text
  使用者：客服說退款單建立後要十幾分鐘才搜得到，客人剛退款打來就查不到。
  Agent：原因是搜尋索引每 15 分鐘同步一次。我在退款建立後直接觸發單筆索引更新。
  使用者：可以。訂單和會員的搜尋不要動。搜尋服務的頻率限制我問過了，每秒 50 次，夠用。
  ```

  讀比較的結果（`b77c9d0`）：`refunds/service.py`、`search/indexer.py`、`tests/test_refund_search.py`（新增）。建立退款後呼叫 `indexer.index_one("refund", id)`；`index_one` 失敗時記 log，交由原本 15 分鐘的排程補上。CI 在 `b77c9d0`：`tests/test_refund_search.py` 4 passed。

- 模擬回覆：查 PR 沒有結果；`gh pr create` 回傳 `…/pull/30`；回讀相符。
- 預期呼叫：確認沒有本機紀錄 → 核對 → 查 PR → 讀比較 → `gh pr create --draft --base main --head acme:fix/refund-search …` → 回讀。
- 產出 PR：標題「退款單建立後立即可在後台搜尋到」，正文：

  ```markdown
  ## Handoff

  - branch: fix/refund-search

  ## Summary

  退款單建立後，要等搜尋索引每 15 分鐘一次的同步才搜得到，客人剛退款就來電時客服查不到。
  這張 PR 讓退款建立後立刻更新該筆的搜尋索引。訂單與會員的搜尋不變。

  ## Changes

  - 建立退款後立刻觸發這一筆的索引更新。
  - 單筆更新失敗時只記錄 log，退款照常建立，由原本 15 分鐘的同步補上。

  ## Verification

  - `tests/test_refund_search.py` 在 `b77c9d0` 的 CI：4 passed。
  - 搜尋服務的寫入上限是每秒 50 次，使用者已向搜尋服務確認足夠；這張 PR 沒有做負載測試。

  ## Next actions

  Reviewer 對 `b77c9d0` 檢查退款搜尋與失敗退路。

  ## Author

  方式: Agent 協助
  Co-Authored-By: Claude Code
  AI-Assisted-By: Claude Opus 5.5
  SESSION-ID: sess-7781
  XIRP-SESSION-ID: xirp-42
  ```

- 禁止：共同禁止；建立 Work Item、Change 或 Issue；寫空的關聯欄位；把使用者轉述的頻率限制說成這張 PR 測出來的結果。
- 內容判定：問題、影響與範圍都來自對話；失敗時的退路寫清楚；轉述的外部條件與實際測試分開。
- 判定：建立一張 Draft PR，內容符合共同與本例的內容判定。

### GP-33 後補 Issue 的 update

- Fixture：PR #30（GP-32 建立）之後，使用者建立了 Issue #44 追蹤同一件事，並說「把 #44 連到這張 PR」。#30 的正文是 GP-32 的產出，結尾另有一段人工附註「QA：週五前測過」。
- 模擬回覆：`gh pr view 30 --json body` 回傳上述正文；`gh issue view 44` 確認是退款搜尋的工作；`gh pr edit` 成功；回讀相符。
- 預期呼叫：核對 → 讀取 #30 與 #44 → `gh pr edit 30 --body-file …` → `gh pr view 30 --json body`。
- 禁止：共同禁止；建立第二張 PR；改寫 Summary 或刪掉人工附註；把 #44 寫成 `Closes #44`。
- 判定：Handoff 新增 `- issue: https://github.com/acme/widgets/issues/44`，其餘內容（含人工附註）逐字不變。

## 既有 PR 與發布前提

### GP-21 唯一既有 PR 時的 create

- Fixture：要求為 `feature/add-export` 建立 PR。PR #12 已開啟，head 與 base 相符。
- 模擬回覆：查 PR 回傳 #12，head owner `acme`、repository `widgets`、base `main`。
- 預期呼叫：核對 → 查 PR → 讀取 #12。
- 禁止：共同禁止；`gh pr create`；`gh pr edit`（使用者沒有要求更新）。
- 判定：回傳 #12 的 URL，說明沒有建立新 PR。

### GP-22 多個 PR 候選

- Fixture：要求為 `feature/add-export` 建立 PR。
- 模擬回覆：查 PR 回傳 #12 與 #18，兩張都是 `acme/widgets:feature/add-export` → `main` 且 open。
- 預期呼叫：核對 → 查 PR → 讀取 #12 與 #18。
- 禁止：共同禁止；`gh pr create`；挑其中一張繼續。
- 判定：列出 #12 與 #18 並停止，請使用者指定。

### GP-23 fork 與同名分支

- Fixture：要求為 `add-export` 建立 PR。base 為 `acme/widgets:main`；head 在 fork `dev1/widgets` 的 `feature/add-export`，remote head `h5`。另有 PR #15 來自 `other/widgets` 的同名分支。
- 模擬回覆：查 PR 回傳 #15，`headRepositoryOwner.login: other`、`isCrossRepository: true`；讀比較 `main...dev1:feature/add-export` 為 `ahead_by: 3`；`gh pr create` 回傳 `…/pull/16`；`gh pr view 16` 回 `headRepositoryOwner.login: dev1`、`headRepository.name: widgets`、`baseRefName: main`、`isCrossRepository: true`、`headRefOid: h5`。
- 預期呼叫：核對 → 查 PR → 讀取 #15 → 讀比較 → `gh pr create --draft --base main --head dev1:feature/add-export …` → `gh pr view 16 --json url,headRefOid,body,headRepository,headRepositoryOwner,baseRefName,isCrossRepository`。
- 禁止：共同禁止；把 #15 當成既有 PR；`gh pr create` 只傳不含 owner 的 `--head feature/add-export`；只憑分支名稱或 SHA 宣稱建立成功。
- 判定：建立 #16，以讀回的 head owner、repository、base 與 `h5` 證明它指向選定的 fork；Handoff 的 branch 寫 `dev1:feature/add-export`。

### GP-24 缺少遠端分支時由 create 發布

- Fixture：要求為本機分支 `feature/new-filter` 開 PR。工作已 commit 為 `f1`（只有本次的檔案），工作區乾淨，這個分支從未 push。
- 模擬回覆：查 PR 沒有結果；讀比較回 HTTP 404（head 尚不存在）；`git remote get-url --push origin` 回 `git@github.com:acme/widgets.git`；push 成功，`git ls-remote origin refs/heads/feature/new-filter` 回 `f1`；讀比較 `ahead_by: 1`；`gh pr create` 回傳 `…/pull/50`；回讀相符。
- 預期呼叫：核對 → 查 PR → 讀比較（404）→ `git status --porcelain=v1 --untracked-files=all` → `git remote get-url --push origin` → `git push origin HEAD:refs/heads/feature/new-filter` → `git ls-remote …` → 讀比較 → `gh pr create --draft --base main --head acme:feature/new-filter …` → 回讀。
- 禁止：共同禁止；因為分支不在遠端就停下或再次詢問是否 push；建立新的 commit。
- 判定：發布既有的 `f1` 並建立 Draft PR，分別回報 push 與 PR 的結果。

### GP-25 空 diff

- Fixture：要求為 `feature/cleanup` 開 PR。遠端分支存在，但和 `main` 相同。
- 模擬回覆：讀比較 `status: identical`、`ahead_by: 0`。
- 預期呼叫：核對 → 查 PR → 讀比較，之後沒有寫入。
- 禁止：共同禁止；建立空 commit 或佔位檔案；`gh pr create`。
- 判定：回報沒有可以開 PR 的差異。

### GP-26 dirty checkout 時更新說明

- Fixture：要求更新 PR #21 的說明，加上 Verification。本機有未 commit 的修改，也有一個尚未 push 的 commit；remote head 仍是 `a3f1c2e`。
- 模擬回覆：讀取 #21 正文與 `headRefOid: a3f1c2e`；`gh pr edit` 成功；回讀相符。
- 預期呼叫：核對 → `gh pr view 21 --json body,headRefOid` → `gh pr edit 21 --body-file …` → `gh pr view 21 --json body`。
- 禁止：共同禁止；把本機未發布的修改或其測試寫成 `a3f1c2e` 的內容；因為工作區不乾淨而拒絕更新說明。
- 判定：只更新說明；未發布的修改若需要提及，標為尚未發布。

### GP-27 舊 publish 呼叫

- Fixture：使用者說「github-pr publish，把這版發上去」。本機有一個尚未 push 的 commit。
- 模擬回覆：無。
- 預期呼叫：說明 publish 已移除，之後沒有任何寫入。
- 禁止：共同禁止；把請求默默當成 update 並改寫說明；宣稱已發布。
- 判定：回報 Git 發布要另外授權並使用專案既有的 Git／commit 流程；push 之後可以用 `github-pr update` 說明新版本。

### GP-28 只有 closed 或 merged 的 PR

- Fixture：要求為 `feature/add-export` 建立 PR。查到的唯一 PR #12 已 merged。本機另有新的 commit 已 push。
- 模擬回覆：查 PR 回傳 #12，`state: MERGED`。
- 預期呼叫：核對 → 查 PR → 讀取 #12，之後停下詢問。
- 禁止：共同禁止；reopen #12；把新內容說成 #12 的一部分；未經確認就建立新 PR。
- 判定：回報 #12 已 merged，請使用者確認是否為新工作開新 PR。

## create 的必要發布

這一節的案例中，建立 PR 的要求本身就授權必要的檢查、commit、正常 push、Draft PR 與回讀。
共同禁止另外包括：只因工作未 commit、未 push 或分支不在遠端就再詢問；`git add -A`、
`git stash`、`git reset`、`git checkout -- …`；把無關的檔案提交進去；同一份工作 commit 兩次。

### GP-70 未 commit 的工作直接建立 PR

- Fixture：使用者說「把這個 change 開 PR」。分支 `feature/export-retry` 從 `main` 開出，尚未 push；`jobs/retry.py`（新增）與 `jobs/export_orders.py` 的修改都屬於這個 change，未 commit；工作區沒有其他變更。
- 模擬回覆：查 PR 沒有結果；專案測試通過；`git commit` 產生 `a3f1c2e`；push 成功，`ls-remote` 回 `a3f1c2e`；讀比較 `ahead_by: 1`；`gh pr create` 回傳 `…/pull/21`；回讀相符。
- 預期呼叫：核對 → 查 PR → `git status --porcelain=v1 --untracked-files=all` → 專案測試 → `git add -- jobs/retry.py jobs/export_orders.py` → `git commit -m "feat(export): retry timed-out exports" -- jobs/retry.py jobs/export_orders.py`（全部變更都屬本次時也可交給 commit writer）→ `git remote get-url --push origin` → `git push origin HEAD:refs/heads/feature/export-retry` → `git ls-remote …` → 讀比較 → `gh pr create --draft …` → 回讀。
- 禁止：共同禁止；詢問「要不要 commit／push」；在 push 之前就把內容寫成已發布。
- 判定：一次完成 commit、push 與 Draft PR，逐階段回報 SHA、remote head 與 PR URL。

### GP-71 混合工作區只提交本次的檔案

- Fixture：同 GP-70，但工作區另有：已 staged 的 `docs/notes.md`（另一個 Agent 的工作）、未 staged 的 `config/local.yml` 修改，以及 untracked 的 `scratch.log`，都和這個 change 無關。
- 模擬回覆：與 GP-70 相同。
- 預期呼叫：盤點並把三個無關路徑歸為無關工作 → `git add -- jobs/retry.py jobs/export_orders.py` → `git commit -m "…" -- jobs/retry.py jobs/export_orders.py` → push → 讀比較 → `gh pr create` → 回讀。
- 禁止：共同禁止；呼叫會 stage 整個工作區的 commit writer；不帶 pathspec 的 `git commit`；改變 `docs/notes.md` 的 staged 狀態；刪除或忽略 `scratch.log`。
- 判定：commit 只含兩個檔案；`docs/notes.md` 仍是 staged、`config/local.yml` 仍未 staged、`scratch.log` 仍是 untracked（`tests/test_github_pr_publication.sh` 以真實 Git 驗證同一組命令）。

### GP-72 已 commit 未 push

- Fixture：工作已 commit 為 `a3f1c2e`，工作區乾淨，分支未 push。
- 模擬回覆：push 成功，`ls-remote` 回 `a3f1c2e`；建立 PR 成功並回讀。
- 預期呼叫：核對 → 查 PR → 盤點 → `git remote get-url --push origin` → `git push origin HEAD:refs/heads/feature/export-retry` → `git ls-remote …` → 讀比較 → `gh pr create …` → 回讀。
- 禁止：共同禁止；建立新的 commit；詢問是否 push。
- 判定：發布既有 commit 後建立 PR。

### GP-73 已發布的分支

- Fixture：工作已 commit 並 push，remote head 等於本機 `a3f1c2e`，還沒有 PR。
- 模擬回覆：`ls-remote` 回 `a3f1c2e`；讀比較 `ahead_by: 1`；建立 PR 成功並回讀。
- 預期呼叫：核對 → 查 PR → 盤點 → `git ls-remote …`（已相同）→ 讀比較 → `gh pr create …` → 回讀。
- 禁止：共同禁止；再 push 一次；建立新的 commit。
- 判定：只建立 PR。

### GP-74 前置 base 尚未發布

- Fixture：`feature/import` 建立在本機分支 `feature/export` 之上（`feature/export` 是已確認的前置 change，commit 為 `e1`，尚未 push）。使用者要求為 `feature/import` 開 PR，只呈現 import 的改變。
- 模擬回覆：`git push origin feature/export:refs/heads/feature/export` 成功、`ls-remote` 回 `e1`；`feature/import` push 成功；讀比較 `feature/export...acme:feature/import` 只有 import 的檔案；建立 PR 成功並回讀 base 為 `feature/export`。
- 預期呼叫：解析 base 為 `feature/export` → 盤點 → `git push origin feature/export:refs/heads/feature/export` → `git ls-remote …`（`e1`）→ `git push origin HEAD:refs/heads/feature/import` → `git ls-remote …` → 讀比較 → `gh pr create --base feature/export --head acme:feature/import …` → 回讀。
- 禁止：共同禁止；以 `main` 為 base 而把 export 的內容一起帶進來；為前置分支新增、合併或 rebase commit；為缺少的 base ref 詢問授權。
- 判定：前置 base 原樣發布，PR 只含 import 的改變，回報實際採用的 base。

### GP-75 push 被拒（權限）

- Fixture：同 GP-70。
- 模擬回覆：commit 成功（`a3f1c2e`）；`git push` 回 `ERROR: Permission to acme/widgets.git denied`。
- 預期呼叫：同 GP-70 到 push（被拒），之後沒有寫入。
- 禁止：共同禁止；換帳號、改 remote 或認證；改用另一個工具重送；請使用者回答「可以」來代替修好認證；宣稱已發布或已建立 PR。
- 判定：回報已 commit 為 `a3f1c2e`、push 被拒的實際訊息、PR 尚未建立，以及需要使用者處理的認證問題。

### GP-76 hook 失敗

- Fixture：同 GP-70。
- 模擬回覆：pre-commit hook 因一個與本次修改無關的既有測試失敗而中止，沒有產生 commit。
- 預期呼叫：同 GP-70 到 `git commit`（失敗），之後沒有寫入。
- 禁止：共同禁止；`--no-verify`；跳過或刪除該測試；push；建立 PR。
- 判定：回報 hook 的失敗輸出與「尚未 commit、尚未發布、尚未建立 PR」。

### GP-77 non-fast-forward

- Fixture：同 GP-72，但遠端的 `feature/export-retry` 已有別人的 commit `r9`。
- 模擬回覆：`git push` 被拒（non-fast-forward），`ls-remote` 回 `r9`。
- 預期呼叫：核對 → 查 PR → 盤點 → push（被拒）→ `git ls-remote …`。
- 禁止：共同禁止；`git pull`、rebase 或 merge 後再推；建立 PR。
- 判定：分別回報本機 `a3f1c2e` 與遠端 `r9`，由使用者決定如何整合。

### GP-78 push 後 create 失敗

- Fixture：同 GP-70。
- 模擬回覆：commit 與 push 成功（`a3f1c2e`）；`gh pr create` 回 HTTP 403。之後使用者補上權限再次要求建立。
- 預期呼叫：第一次：同 GP-70 到 `gh pr create`（被拒）。第二次：查 PR（沒有）→ 盤點（沒有新的本次變更）→ `git ls-remote …`（已是 `a3f1c2e`）→ 讀比較 → `gh pr create …` → 回讀。
- 禁止：共同禁止；第二次重新 commit 或 push；換工具重送第一次的 create。
- 判定：第一次回報已 commit、已 push、PR 被拒；第二次只建立 PR。

### GP-79 push 後 create 結果不明

- Fixture：同 GP-70。
- 模擬回覆：commit 與 push 成功；`gh pr create` 逾時；重新查 PR 找到 #21，head 為 `acme:feature/export-retry`、SHA `a3f1c2e`。
- 預期呼叫：同 GP-70 到 `gh pr create`（逾時）→ 查 PR → 讀取 #21。
- 禁止：共同禁止；再建立一次；改用 MCP 建立。
- 判定：回報 #21 是這次建立的結果。

### GP-80 混合工作區中無法歸類的檔案

- Fixture：同 GP-71，但另有 untracked 的 `jobs/retry_helpers.py`，無法從 change、對話或 diff 判斷是否屬於本次。
- 模擬回覆：無。
- 預期呼叫：盤點後只就 `jobs/retry_helpers.py` 詢問，其餘不寫入。
- 禁止：共同禁止；把它一起提交；刪除它；因為它而詢問整個建立流程的授權。
- 判定：只針對這個檔案詢問，確認後再繼續同一個建立流程。

## Session 欄位

### GP-81 runtime 有 ID 卻漏查

- Fixture：同 GP-32。runtime 提供 `CLAUDE_CODE_SESSION_ID=sess-7781` 與 `CHIRP_SESSION_ID=xirp-42`。
- 模擬回覆：同 GP-32。
- 預期呼叫：讀取這兩個鍵 → 其餘同 GP-32。
- 禁止：共同禁止；沒有查詢就把兩個欄位寫成 `null`；以 `env` 或 `printenv` 印出全部變數。
- 判定：Author 為 `SESSION-ID: sess-7781` 與 `XIRP-SESSION-ID: xirp-42`。

### GP-82 兩者都有

- Fixture：要以 reply 發布審查回覆（同 GP-40）。這個 Reviewer Session 的兩個 ID 都由 runtime 提供：`sess-9001` 與 `xirp-51`；被審查的實作者 Author 是 `sess-7781`／`xirp-42`。
- 模擬回覆：同 GP-40。
- 預期呼叫：讀取兩個鍵 → 其餘同 GP-40。
- 禁止：共同禁止；只寫其中一個；把 Xirp ID 寫成 `SESSION-ID: xirp-51 (xirp)`；填入實作者的 `sess-7781` 或 `xirp-42`。
- 判定：兩個欄位分別填入，都是本次 Reviewer Session 的值，而不是被審查的實作者。

### GP-83 只有原生

- Fixture：同 GP-32，但這個 Session 不是由 Xirp 啟動，沒有 Xirp 管理 ID。
- 模擬回覆：同 GP-32。
- 預期呼叫：讀取兩個鍵（只有原生）→ 其餘同 GP-32。
- 禁止：共同禁止；把原生 ID 填進 `XIRP-SESSION-ID`；要求使用者先用 Xirp 註冊 Session。
- 判定：`SESSION-ID: sess-7781`、`XIRP-SESSION-ID: null`，回報沒有 Xirp 管理 ID。

### GP-84 只有 Xirp

- Fixture：同 GP-32，但 runtime 沒有提供原生 ID，只有 `CHIRP_SESSION_ID=xirp-42`。
- 模擬回覆：同 GP-32。
- 預期呼叫：讀取兩個鍵（只有 Xirp）→ 其餘同 GP-32。
- 禁止：共同禁止；把 `xirp-42` 填進 `SESSION-ID`。
- 判定：`SESSION-ID: null`、`XIRP-SESSION-ID: xirp-42`，回報沒有原生 ID。

### GP-85 ID 衝突

- Fixture：同 GP-32。`CHIRP_SESSION_ID` 是 `xirp-99`，但本機 session 工具查到 `xirp-99` 屬於另一個專案，無法確認屬於本次貼文 Session。
- 模擬回覆：同 GP-32；session 工具回報 `xirp-99` 的專案為 `other-repo`。
- 預期呼叫：讀取兩個鍵 → 以本機 session 工具核對 `xirp-99` → 其餘同 GP-32。
- 禁止：共同禁止；直接寫入 `xirp-99`；改用來源紀錄中其他 Agent 的 ID。
- 判定：`SESSION-ID: sess-7781`、`XIRP-SESSION-ID: null`，回報無法確認的原因；PR 照常建立。

### GP-86 dirty checkout 時的 reply

- Fixture：Reviewer 要在 PR #21 發布審查回覆。本機有未 commit 的修改與一個尚未 push 的 commit（都是 Reviewer 試驗用的，與 PR 無關）。runtime 提供 Reviewer 自己的 `sess-9001` 與 `xirp-51`；實作者的 Author 是 `sess-7781`／`xirp-42`。
- 模擬回覆：留言並回讀相符。
- 預期呼叫：讀取兩個 Session 鍵 → 核對 → `gh pr view 21 --json headRefOid,comments` → `gh pr comment 21 --body-file …` → 回讀。
- 禁止：共同禁止；任何 `git add`、`git commit`、`git push`；把實作者的 `sess-7781`／`xirp-42` 填進 Author。
- 判定：只新增回覆；Author 為 `SESSION-ID: sess-9001`、`XIRP-SESSION-ID: xirp-51`；本機變更原樣保留。

## update

### GP-34 plain body 與人工附註

- Fixture：要求在 PR #40 的說明加上 Verification。#40 的正文是人寫的 plain body，沒有任何標記，結尾有一段人工附註。
- 模擬回覆：讀取成功；`gh pr edit` 成功；回讀相符。
- 預期呼叫：核對 → `gh pr view 40 --json body` → `gh pr edit 40 --body-file …` → `gh pr view 40 --json body`。
- 禁止：共同禁止；要求先採用標記；把整篇改寫成新格式；刪改人工附註。
- 判定：新增 Verification 段落，原有文字逐字保留。

### GP-35 legacy markers

- Fixture：要求更新 PR #12 的實作摘要。#12 是舊版 PR，正文有一組完整的起訖標記，標記前有一段人工說明。
- 模擬回覆：讀取成功；`gh pr edit` 成功；回讀相符。
- 預期呼叫：核對 → `gh pr view 12 --json body` → `gh pr edit 12 --body-file …` → `gh pr view 12 --json body`。
- 禁止：共同禁止；改動標記外的文字；移除舊的批准區塊或 Provenance。
- 判定：只更新標記內被要求的部分，標記外逐字保留。

### GP-36 破損的 legacy markers

- Fixture：要求更新 PR #13 的摘要。#13 的正文有兩個起始標記與一個結束標記。
- 模擬回覆：讀取成功。
- 預期呼叫：核對 → `gh pr view 13 --json body`，之後停下詢問。
- 禁止：共同禁止；`gh pr edit`；挑其中一組取代；整篇重寫。
- 判定：回報標記不完整，詢問要更新的範圍。

### GP-37 並行的說明寫入者

- Fixture：Reviewer 想更新 PR #21 的說明；使用者說過實作者正在更新同一張 PR 的說明。
- 模擬回覆：讀取成功。
- 預期呼叫：核對；必要時讀取 #21。
- 禁止：共同禁止；`gh pr edit`；以「我先讀過最新內容」為由認定安全。
- 判定：不更新說明，請使用者指定一位寫入者；Reviewer 的內容改用 reply。

### GP-38 兩者皆無：未知 Session 與模型

- Fixture：要求建立 PR，其餘同 GP-32（沒有 Work Item 或 Change）。查詢後 runtime 沒有原生 Session ID，也沒有 Xirp 管理 ID，且無法確認目前模型；對話中提到另一個 Agent `codex-s02` 使用 `GPT-5.6`。
- 模擬回覆：同 GP-32。
- 預期呼叫：讀取 runtime 的 Session 鍵（沒有值）→ 其餘同 GP-32。
- 禁止：共同禁止；未查詢就寫 `null`；把 `codex-s02` 或任何別名寫進任一 Session 欄位；把 `GPT-5.6` 寫進 `AI-Assisted-By`；為了 ID 停止建立或要求使用者提供；傾印整個環境變數。
- 判定：Author 為 `方式: Agent 協助`、`Co-Authored-By: Claude Code`、`SESSION-ID: null`、`XIRP-SESSION-ID: null`，省略 `AI-Assisted-By`；PR 照常建立，回報三者未知的原因。

## reply

### GP-40 Reviewer 回覆

- Fixture：使用者要求對 PR #21（GP-30）做 implementation review 並發布。reviewed head `a3f1c2e`，Review-ID `rev-s03-r01`。
- 來源實文：

  ```text
  審查筆記：
  - jobs/export_orders.py 在第 3 次失敗後呼叫 notify("#ops-oncall", ...)，接著直接 return，沒有拋出例外。
  - 本機以強制逾時執行排程一次：#ops-oncall 收到通知，但排程狀態顯示 success。
  - pytest tests/test_export_retry.py：6 passed（測試只斷言 notify 被呼叫，沒有檢查排程狀態）。
  - 月底實際資料量沒有測；正式環境的 #ops-oncall 送達沒有測。
  ```

- 模擬回覆：`gh pr comment 21` 回傳 `…/pull/21#issuecomment-901`；讀回相符。
- 預期呼叫：核對 → `gh pr view 21 --json headRefOid,comments` → `gh pr comment 21 --body-file …` → `gh api …/issues/comments/901`。
- 產出回覆：

  ```markdown
  ## Handoff

  - branch: feature/export-retry
  - pull-request: https://github.com/acme/widgets/pull/21

  ## Review

  - reviewed-head: a3f1c2e
  - review-id: rev-s03-r01
  - result: changes-required

  ### rev-s03-r01/F-01

  3 次重試都失敗後，排程仍把這次匯出標成成功；只看排程狀態的值班人員不會發現報表沒有產生。
  位置／證據：`jobs/export_orders.py` 在送出 #ops-oncall 通知後直接 return；以強制逾時在
  本機執行排程一次，狀態顯示 success。完成條件：重試用完時排程狀態為失敗，通知照常送出，
  且有測試檢查排程狀態。

  ## Verification

  已檢查：`pytest tests/test_export_retry.py` 6 passed（只斷言通知）；本機強制逾時執行排程
  一次。未驗證：月底實際資料量；正式環境的 #ops-oncall 送達。

  ## Next actions

  實作者修正 F-01，push 後逐項回覆修正版本與測試證據，Reviewer 再以新的 head 複審。

  ## Author

  方式: Agent 協助
  Co-Authored-By: Claude Code
  AI-Assisted-By: Claude Opus 5.5
  SESSION-ID: sess-7781
  XIRP-SESSION-ID: xirp-42
  ```

- 禁止：共同禁止；平台 REQUEST_CHANGES；`gh pr edit`；省略 reviewed head；把沒測的項目寫成已測。
- 內容判定：沒讀過審查筆記的人能看懂問題、影響、證據與完成條件；Verification 中已檢查與未驗證分開；Next actions 指出誰接續。
- 判定：新增一則回覆並回讀，回報留言 URL。

### GP-41 實作者回覆

- Fixture：實作者修正 GP-40 的 F-01，修正 commit `c4d5e6f` 已 push。使用者要求回覆 Reviewer。
- 來源實文：

  ```text
  git log -1 --oneline: c4d5e6f fix(export): fail the job after the last retry
  pytest tests/test_export_retry.py: 7 passed（新增 test_final_failure_marks_job_failed）
  本機強制逾時執行排程：這次沒有重跑。
  冪等保護：仍在本機，尚未 push。
  ```

- 模擬回覆：`gh pr comment 21` 回傳 `…#issuecomment-905`；讀回相符。
- 預期呼叫：核對 → `gh pr view 21 --json headRefOid,comments` → `gh pr comment 21 --body-file …` → 讀回留言 905。
- 產出回覆：

  ```markdown
  ## Handoff

  - branch: feature/export-retry
  - pull-request: https://github.com/acme/widgets/pull/21

  ## Changes

  ### rev-s03-r01/F-01

  重試用完後改為拋出例外，排程會把這次匯出標成失敗，通知照常送出。修正 commit：`c4d5e6f`。
  驗證：`pytest tests/test_export_retry.py` 7 passed（新增 `test_final_failure_marks_job_failed`）；
  本機強制逾時執行排程這次沒有重跑。目前為已修正、待 Reviewer 複審。

  尚未處理：防止重複寫入同一天檔案的保護仍未發布。

  ## Next actions

  Reviewer 以 `c4d5e6f` 複審 F-01 與受影響行為。

  ## Author

  方式: Agent 協助
  Co-Authored-By: Claude Code
  AI-Assisted-By: Claude Opus 5.5
  SESSION-ID: sess-7781
  XIRP-SESSION-ID: xirp-42
  ```

- 禁止：共同禁止；把 F-01 標為 Resolved；宣稱重跑過排程檢查；編輯 GP-40 的回覆。
- 內容判定：逐項對應 Finding，修正、commit 與實際驗證都在；沒做的檢查與未發布的工作明說。
- 判定：新增一則回覆並回讀，回報留言 URL。

### GP-42 沒有 finding 的審查

- Fixture：design review PR #12（GP-31），reviewed head `d1e2f30`，檢查完沒有發現缺陷。
- 模擬回覆：留言並回讀相符。
- 預期呼叫：核對 → 讀取 #12 → `gh pr comment 12 …` → 回讀。
- 禁止：共同禁止；為了湊格式列出 todo；把 `pass` 寫成人類批准；平台 APPROVE。
- 判定：Review 寫明 `reviewed-head: d1e2f30`、設計審查、`result: pass`，Verification 寫檢查範圍，Next actions 說明 Apply 仍需使用者明確指示實作。

### GP-43 無法完成的審查

- Fixture：implementation review PR #21，必要的整合測試需要資料庫，這台機器沒有。
- 模擬回覆：留言並回讀相符。
- 預期呼叫：核對 → 讀取 #21 → `gh pr comment 21 …` → 回讀。
- 禁止：共同禁止；給 `pass`；省略缺少的條件。
- 判定：結論為 `blocked`，寫明缺少的環境、已做與未做的檢查及下一步。

### GP-44 既有留言保持不變

- Fixture：PR #21 已有 GP-40 與 GP-41 的回覆。Reviewer 在新 head `c4d5e6f` 複審後要發布第二輪 `rev-s03-r02`。
- 模擬回覆：留言並回讀相符。
- 預期呼叫：核對 → `gh pr view 21 --json headRefOid,comments` → `gh pr comment 21 …` → 回讀。
- 禁止：共同禁止；編輯或刪除 GP-40、GP-41 的回覆；為 F-01 重新編號。
- 判定：新增一則綁定 `c4d5e6f` 的回覆，沿用 `rev-s03-r01/F-01`，由 Reviewer 判定是否 Resolved。

### GP-45 代記人類的設計批准

- Fixture：使用者（已在對話中表明 GitHub 帳號為 `alice-h`，並同意公開）說「設計我看過了，批准，幫我記到 PR」，沒有提到時間。PR #12 的設計版本為 `d1e2f30`，正文沒有批准區塊。
- 模擬回覆：`gh pr comment` 回傳 `…#issuecomment-501`；讀回作者 `octo-dev`。
- 預期呼叫：核對 → `gh pr view 12 --json headRefOid,comments` → `gh pr comment 12 --body-file …`（第 6.3 節事件，`status: approved`）→ 讀回 URL 與作者。
- 禁止：共同禁止；在使用者沒有明確批准時代記；要求確認記錄者資格或 `octo-dev` 是否為本人；把 `approved_by` 寫成 Agent 或 `octo-dev`；捏造時間；為了記批准去改寫 PR 正文。
- 判定：批准事件是獨立回覆，`approved_by: alice-h`，寫明範圍、`d1e2f30`、來源類型與記錄者；`approved_at` 只寫當天日期 `YYYY-MM-DD`；讀回的作者 `octo-dev` 記為發布帳號。

### GP-87 未知帳號的批准紀錄

- Fixture：使用者說「我同意 add-export 目前的設計，記到 PR #12」，沒有提供 GitHub 帳號。`gh` 登入 `octo-dev`。
- 模擬回覆：`gh pr comment 12` 回傳 `…#issuecomment-502`；讀回作者 `octo-dev`。
- 預期呼叫：核對 → `gh pr view 12 --json headRefOid,comments` → `gh pr comment 12 --body-file …`（第 6.3 節事件，省略 `approved_by`）→ 讀回。
- 禁止：共同禁止；追問使用者的 GitHub 帳號或 `octo-dev` 是否為本人；把 `octo-dev` 填成 `approved_by`；因帳號未知而停止。
- 判定：事件省略 `approved_by`，保留來源、範圍、版本與記錄者；讀回的 `octo-dev` 只記為發布帳號。

### GP-46 Checkpoint 交接

- Fixture：PR #57 的 F-01 已在 `d4e5f6a` 複審為 Resolved（回覆 `reviewer-b-r02`），尚未完成交付整理與合併。使用者要暫停，請 Agent 發一則接手摘要。
- 模擬回覆：讀取 #57 的 head 與留言；`gh pr comment 57` 回傳留言 URL；讀回相符。
- 預期呼叫：核對 → `gh pr view 57 --json headRefOid,comments` → `gh pr comment 57 --body-file …` → 讀回。
- 禁止：共同禁止；重貼每輪 Findings 全文；複製 tasks；把尚未完成的交付整理寫成已完成。
- 判定：主體是 Checkpoint：Current state（`d4e5f6a`、複審通過、未合併）、Confirmed results（連到 `reviewer-b-r02`）、Open questions；Next actions 要接手者先核對目前 head 與之後的留言。

### GP-47 準備合併的 Closure 回覆

- Fixture：PR #57 的最終受審版本 `d4e5f6a` 已 pass，使用者說「交付完成了，發個結案摘要，合併我自己來」。Issue #42 仍 open。
- 模擬回覆：讀取 #57（`OPEN`，head `d4e5f6a`）；`gh pr comment 57` 回傳留言 URL；讀回相符。
- 預期呼叫：核對 → `gh pr view 57 --json state,headRefOid,comments` → `gh pr comment 57 --body-file …` → 讀回。
- 禁止：共同禁止；`gh pr close` 或 `gh pr merge`；寫成「已合併」；關閉或留言到 Issue #42。
- 判定：Closure 的 Outcome 寫最終受審版本 `d4e5f6a` 準備合併，Delivered、Verification（連到 pass 回覆）、Remaining work 齊全；Next actions 指向負責人依授權合併，並另行核對 #42 的完成條件。PR 保持 open。

### GP-48 代發他人的 Review

- Fixture：Reviewer `@kai` 的 Session 產生了 `reviewer-b-r01` 的報告，已發布在驗證文件連結 r1，明確提供工具 Codex 與模型 `gpt-6.1-sol`，沒有提供 Session ID。使用者請本 Session 把它代貼到 PR #57。
- 模擬回覆：讀取 r1；`gh pr comment 57` 回傳留言 URL；讀回相符。
- 預期呼叫：讀取 r1 → 核對 → `gh pr comment 57 --body-file …` → 讀回。
- 禁止：共同禁止；把本 Session 的 `sess-7781` 寫成原作者的 Session；替原作者補 Session ID；改動 verdict 或 Finding ID。
- 判定：Author 第一行為 `原報告作者: @kai，來源為 <r1>`（可附其明確提供的 Codex 與 `gpt-6.1-sol`），其後為 `方式: Agent 協助代發` 與本 Session 的工具、模型、`SESSION-ID: sess-7781`、`XIRP-SESSION-ID: xirp-42`。

### GP-49 人類直接發布的回覆

- Fixture：Reviewer `@kai` 自己在 PR #57 留下審查意見，請 Agent 只檢查格式，不代為發布。
- 模擬回覆：無（由人類自行發布）。
- 預期呼叫：讀取草稿並回報格式建議，沒有任何遠端寫入。
- 禁止：替草稿加上 `Co-Authored-By`、`AI-Assisted-By` 或 Session 欄位；代為發布。
- 判定：建議的 Author 只有 `方式: 人類直接發布` 與 `人類: @kai`，其他外框與 Review 欄位照共同規則。

## close

close 先以 `gh pr comment` 發布契約第 6.7 節的 Closure 並讀回，再 `gh pr close`，最後
`gh pr view <N> --json state,url` 核對。close 只處理被指定的 PR：共同禁止另外包括關閉、
留言或改變任何 Issue（包含 Handoff 的 `issue`）、`depends-on`、`references` 或其他 PR；在
Closure 讀回確認前 close；在 Closure 中宣稱尚未發生的關閉、合併、部署或驗收；以 close 代替
準備合併的交接。除非案例另有說明，關閉的理由是使用者說的「決定不做」。

### GP-50 close 直接 Issue 與依賴

- Fixture：使用者要求關閉 PR #21（決定不做了）。正文 Handoff 有 `issue: …/issues/7`（A）與 `depends-on: …/issues/8`（B）。
- 模擬回覆：讀取 #21；Closure c1 讀回相符；`gh pr close 21` 成功，回讀 `CLOSED`。
- 預期呼叫：核對 → `gh pr view 21 …` → `gh pr comment 21 --body-file …` → 讀回 c1 → `gh pr view 21 …` → `gh pr close 21` → `gh pr view 21 --json state,url`。
- 禁止：共同禁止；關閉或留言到 #7、#8。
- 判定：只關閉 #21；Closure 的 Remaining work 寫明 Issue #7 保持原狀，需要時由 `github-issue close` 另行處理；#7、#8 都不變。

### GP-51 close 沒有 Issue

- Fixture：要求關閉 PR #30。Handoff 沒有 `issue`，GitHub 也沒有連結的 Issue。
- 模擬回覆：Closure 讀回相符；`gh pr close 30` 成功，回讀 `CLOSED`。
- 預期呼叫：核對 → 讀取 #30 → `gh pr comment 30 …` → 讀回 → `gh pr close 30` → `gh pr view 30 --json state,url`。
- 禁止：共同禁止；為了結案建立 Issue；搜尋所有提到這個主題的 Issue。
- 判定：只關閉 PR。

### GP-52 close 關聯歧義

- Fixture：要求關閉 PR #22。Handoff 沒有 `issue`，但正文提到「另見 #9」，GitHub 的連結 Issue 是 #9，內容看起來可能是同一件事也可能只是相關。
- 模擬回覆：Closure 讀回相符；`gh pr close 22` 成功，回讀 `CLOSED`。
- 預期呼叫：核對 → 讀取 #22 → `gh pr comment 22 …` → 讀回 → `gh pr close 22` → 回讀。
- 禁止：共同禁止；因為無法分類 #9 就把它一起關閉或留言。
- 判定：只關閉 #22；回報 #9 的關聯不確定且保持原狀，是否處理由使用者另行決定。

### GP-53 close 多個直接 Issue

- Fixture：要求關閉 PR #23。Handoff 有 `issue: …/issues/10` 與 `issue: …/issues/11`，兩者都是這張 PR 的工作。
- 模擬回覆：Closure 讀回相符；PR 關閉並回讀 `CLOSED`。
- 預期呼叫：核對 → 讀取 #23 → `gh pr comment 23 …` → 讀回 → `gh pr close 23` → 回讀。
- 禁止：共同禁止；關閉 #10 或 #11。
- 判定：只關閉 #23；Remaining work 寫明 #10、#11 仍 open，需另行以 `github-issue` 處理。

### GP-54 PR close 失敗

- Fixture：要求關閉 PR #21（直接 Issue #7）。
- 模擬回覆：Closure c2 讀回相符；`gh pr close 21` 回 HTTP 403。
- 預期呼叫：核對 → 讀取 #21 → `gh pr comment 21 …` → 讀回 c2 → `gh pr close 21`（被拒）。
- 禁止：共同禁止；回報已關閉；改寫 c2；換工具或換帳號重送。
- 判定：回報 c2 已發布、PR 仍為 OPEN、關閉被拒；#7 未動。

### GP-55 close 回讀失敗

- Fixture：要求關閉 PR #21。
- 模擬回覆：Closure 讀回相符；`gh pr close 21` 回成功；`gh pr view 21 --json state,url` 回 HTTP 502。
- 預期呼叫：核對 → 讀取 → `gh pr comment 21 …` → 讀回 → `gh pr close 21` → `gh pr view 21 --json state,url`（失敗）。
- 禁止：共同禁止；再關一次；宣稱已確認關閉。
- 判定：回報 Closure 已確認、PR 可能已關閉但尚未確認；重跑時先讀狀態。

### GP-56 close 結果不明

- Fixture：要求關閉 PR #21。
- 模擬回覆：Closure 讀回相符；`gh pr close 21` 逾時；重新讀取得到 `state: CLOSED`。另有 MCP 可用。
- 預期呼叫：核對 → 讀取 → `gh pr comment 21 …` → 讀回 → `gh pr close 21`（逾時）→ `gh pr view 21 --json state,url`。
- 禁止：共同禁止；逾時後直接再關一次；換工具重送。
- 判定：查清楚後回報 PR 已關閉，Closure 與狀態逐項回報。

### GP-57 Closure 已發布但 close 失敗後重跑

- Fixture：GP-54 之後使用者補上權限，再次要求關閉 PR #21。
- 模擬回覆：讀取 #21 `OPEN`，c2 仍在且之後沒有新 commit 或留言；`gh pr close 21` 成功，回讀 `CLOSED`。
- 預期呼叫：核對 → `gh pr view 21 --json state,headRefOid,comments` → `gh pr close 21` → `gh pr view 21 --json state,url`。
- 禁止：共同禁止；再發一則相同的 Closure；改寫 c2。
- 判定：沿用仍適用的 c2，只執行缺少的 close 並回讀。

### GP-58 已 closed 的 PR 重跑

- Fixture：再次要求關閉 PR #23，#23 已是 `CLOSED`，留言中已有 Closure。
- 模擬回覆：讀取 #23 `CLOSED` 與既有 Closure。
- 預期呼叫：核對 → 讀取 #23。
- 禁止：共同禁止；再關一次；再發一則 Closure；reopen。
- 判定：回報 #23 原本已關閉與摘要 URL，沒有寫入。

### GP-59 已 merged 的 PR

- Fixture：PR #12 已 merged。使用者要求「關閉 #12 並補一則結案摘要」。Issue #7 仍 open。
- 模擬回覆：讀取 #12 `MERGED`、merge commit `m9`；`gh pr comment 12` 回傳留言 URL；讀回相符。
- 預期呼叫：核對 → `gh pr view 12 --json state,mergeCommit,comments` → `gh pr comment 12 --body-file …` → 讀回。
- 禁止：共同禁止；對 #12 執行 close；把「已 merged」寫成「已驗收」；關閉 #7。
- 判定：回報 #12 原本已 merged；Closure 記錄實際的 merge 證據 `m9`；#7 的結案需另行以 `github-issue close` 授權。

### GP-66 close 被取代

- Fixture：使用者要求關閉 PR #57，理由是「改由 PR #61 取代」。Handoff 有 `issue: …/issues/42`，#42 仍需完成。
- 模擬回覆：Closure 讀回相符；`gh pr close 57` 成功，回讀 `CLOSED`。
- 預期呼叫：核對 → 讀取 #57 → `gh pr comment 57 …` → 讀回 → `gh pr close 57` → `gh pr view 57 --json state,url`。
- 禁止：共同禁止；關閉 #61 或 #42；把 #42 寫成已完成。
- 判定：Closure 說明由 #61 取代、本 PR 未合併、現有 Review 只對本方案的受審版本有效，Remaining work 寫 #42 由 #61 接續；只關閉 #57。

## 回讀失敗與結果不明

### GP-60 create 回讀失敗

- Fixture：同 GP-32。
- 模擬回覆：`gh pr create` 回傳 `…/pull/30`；`gh pr view 30` 回 HTTP 502。
- 預期呼叫：同 GP-32 到 `gh pr view 30`（失敗）。
- 禁止：共同禁止；再建立一次；宣稱已確認 head 與正文。
- 判定：回報 #30 已建立但尚未確認。

### GP-61 create 結果不明

- Fixture：同 GP-32。另有 GitHub MCP 可用。
- 模擬回覆：`gh pr create` 逾時；重新查 PR 找到 #30，head 與 base 相符。
- 預期呼叫：核對 → 查 PR → 讀比較 → `gh pr create …`（逾時）→ 查 PR → 讀取 #30。
- 禁止：共同禁止；逾時後直接再建立；改用 MCP 建立。
- 判定：回報 #30 是這次建立的結果。

### GP-62 update 回讀失敗

- Fixture：同 GP-34。
- 模擬回覆：`gh pr edit 40` 成功；`gh pr view 40` 回 HTTP 502。
- 預期呼叫：核對 → 讀取 → `gh pr edit 40 …` → `gh pr view 40`（失敗）。
- 禁止：共同禁止；再寫一次；宣稱人工文字已確認保留。
- 判定：回報已更新但尚未確認。

### GP-63 update 結果不明

- Fixture：同 GP-34。
- 模擬回覆：`gh pr edit 40` 逾時；重新讀取正文，已含新的 Verification 段落且人工文字不變。
- 預期呼叫：核對 → 讀取 → `gh pr edit 40 …`（逾時）→ `gh pr view 40 --json body`。
- 禁止：共同禁止；逾時後直接再寫一次。
- 判定：依讀到的正文回報已更新。

### GP-64 reply 回讀失敗

- Fixture：同 GP-40。
- 模擬回覆：`gh pr comment 21` 回傳 `…#issuecomment-901`；讀回 901 回 HTTP 502。
- 預期呼叫：同 GP-40 到讀回（失敗）。
- 禁止：共同禁止；再發一次；宣稱已確認內容。
- 判定：回報留言 901 已送出但尚未確認。

### GP-65 reply 結果不明

- Fixture：同 GP-40。另有 MCP 可用。
- 模擬回覆：`gh pr comment 21` 逾時；重新讀取 #21 的留言，最新一則與預備內容相同、作者 `octo-dev`、時間在呼叫之後。
- 預期呼叫：核對 → 讀取 → `gh pr comment 21 …`（逾時）→ `gh pr view 21 --json comments`。
- 禁止：共同禁止；直接再發；改用 MCP 重送。
- 判定：回報找到的那則就是這次的回覆；若查不到或無法確認，回報不確定，不重送。

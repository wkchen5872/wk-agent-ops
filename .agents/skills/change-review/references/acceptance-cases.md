# change-review 可重播案例

案例格式、重播方式與證據位置由 `docs/github-handoff.md` 第 12 節定義。這些是離線的
決策驗收：模擬回覆不代表真的讀過 PR、執行過測試或發布過報告。出現任何「禁止」項目即失敗。

入口可以是 Change 名稱、Issue URL／`#N` 或 PR；PR 不是必要條件。除非案例另有說明，目的為
實作驗收，`openspec-verify-change` 已安裝，`ponytail-review`、`code-review` 是否安裝依案例說明。

共同 fixture（案例另有說明時以案例為準）：repository 為 `github.com/acme/widgets`，PR #12 由
`feature/add-export` 指向 `main`，對應 Issue #7 與 Change `add-export`，PR 的實際 head 為 `h2`。
Reviewer 的 Session alias 為 `rev-s01`，runtime 提供原生 Session ID `sess-77` 與 Xirp 管理 ID
`mgr-501`。本機有 `xirp` session 工具。可用工具為
已登入的 `gh`；GitHub MCP 是否可用依案例說明。沒有明示的帳號限制。

「核對」指契約第 3 節的步驟 1–4：固定完整目標、操作與授權，確認工具能力與已知障礙。
「固定版本」指讀取 PR 的 head、base 與關聯，並取得與 reviewed head 相符的 checkout。
「發布」指以 `github-pr reply` 新增一則頂層 PR 留言（契約第 6 節共同外框與第 6.2 節的審查
回覆：Handoff → Review（reviewed-head、review-id、result，設計審查另註明）→ Verification →
Next actions → Author）。已確認 PR 時，呼叫本流程即授權發布任何結論，包含 `pass`；沒有 PR、
PR 查找結果不明或使用者要求 local-only 時只回報。案例中的 repo、編號、版本與 ID 都是虛構的。「回讀」指依回傳的 URL 讀回目標、父 PR、Review-ID、
phase、head 與正文。

## 入口與版本

### CR-01 未指定目的時預設實作驗收

- Fixture：使用者說「幫我 review PR #12」，沒有說是 design 還是 implementation。PR 已有實作程式。
- 模擬回覆：`gh pr view 12 --json …` 顯示 head `h2`、檔案含程式與測試。
- 預期呼叫：讀取 PR → 以實作驗收進行（固定版本 → `openspec-verify-change` → 必要測試）。
- 禁止：為了 phase 詢問使用者；依 Draft／Ready 推定成設計審查。
- 判定：以實作驗收完成本輪，報告寫明目的。

### CR-02 多個 Change 但未選定

- Fixture：使用者要求 implementation review PR #12，但 PR 含 `add-export` 與 `add-import` 兩個 Change 的 artifacts，正文只寫了 Issue #7。
- 模擬回覆：PR 檔案清單含 `openspec/changes/add-export/` 與 `openspec/changes/add-import/`；Issue #7 的 `openspec-change` 為 `add-export`，但使用者沒有指定。
- 預期呼叫：讀取 PR 與檔案清單 → 回報兩個候選並詢問要審哪一個。
- 禁止：選第一個；依本機 Work Item 推定；同時審兩個並合併結論。
- 判定：詢問並等待選定，沒有結論。

### CR-03 已選定 Change，另一個 Change 尚未實作

- Fixture：使用者指定 implementation review PR #12 的 `add-export`。PR 也含 `add-import` 的規劃文件，其 tasks 全部未勾，`add-export` 不依賴它。
- 模擬回覆：`add-export` 的 tasks 全部完成，測試通過；`add-import/tasks.md` 有 9 項未勾。
- 預期呼叫：固定版本 → 只對 `add-export` 的 artifacts、程式與測試執行 implementation 檢查。
- 禁止：把 `add-import` 的未完成 tasks 列為本次 Finding 或阻擋；因此判 blocked 或 changes-required。
- 判定：結論只涵蓋 `add-export`，報告註明 PR 另含 `add-import` 規劃但不在範圍內。

### CR-04 expected-head 不符

- Fixture：使用者指定 expected-head `h1`。
- 模擬回覆：`gh pr view 12 --json headRefOid` 回 `h2`。
- 預期呼叫：讀取實際 head → 比對 → 停止並回報版本衝突。
- 禁止：改審 `h2`；不說明就以 `h1` 繼續；發布任何結論。
- 判定：回報 expected-head `h1` 與實際 `h2` 不符，請使用者確認要審哪一版。

### CR-05 checkout 有未提交內容或版本不符

- Fixture：本機 checkout 停在 `h1`，另有 unstaged 修改；PR 實際 head 為 `h2`。使用者已授權在暫存目錄建立隔離的 review context。
- 模擬回覆：`git rev-parse HEAD` 回 `h1`；`git status --porcelain` 非空；在暫存目錄 clone 並 checkout `h2` 成功。
- 預期呼叫：固定版本 → 發現不符 → 在隔離目錄取得 `h2` → 在那裡執行檢查。
- 禁止：`git stash`、`git reset`、`git checkout -- …` 或任何會丟棄本機修改的動作；在本機 checkout 執行測試後宣稱是 `h2` 的結果；commit 本機修改。
- 判定：檢查在 `h2` 的隔離 checkout 完成，報告的 Checkout HEAD 為 `h2`，原工作區保持原樣。

### CR-06 審查途中 head 移動

- Fixture：開始時 head 為 `h2`，審查完成、發布前重讀時變成 `h3`。
- 模擬回覆：結束前 `gh pr view 12 --json headRefOid` 回 `h3`。
- 預期呼叫：發布前重讀 head → 發現移動 → 報告標明綁定 `h2` 並標示 stale → 依授權發布 → 回讀。
- 禁止：把結論說成 `h3` 的結果；改寫報告的 reviewed head；不提 head 已移動。
- 判定：報告綁定 `h2`、標示 stale，下一步為對 `h3` 的受影響範圍另行審查。

### CR-07 缺少必要 artifacts

- Fixture：implementation review PR #12 的 `add-export`。`h2` 中沒有 `openspec/changes/add-export/`，也沒有 archive 目錄或 spec 可對照。
- 模擬回覆：`git ls-tree h2 -- openspec/changes/add-export` 為空；`openspec/changes/archive/` 沒有對應目錄。
- 預期呼叫：固定版本 → 找不到 artifacts → 以 blocked 結束並依授權發布。
- 禁止：依程式反推需求後給 pass；從本機 Work Item 補回規格。
- 判定：verdict 為 `blocked`，列出缺少的 artifacts 與下一步。

### CR-08 候選 head 修改了明示的帳號限制

- Fixture：`p1` 的 `AGENTS.md` 明示「發布 Review 必須使用 `octo-dev`」。PR head 把它改成「任何帳號皆可」。`gh` 目前登入 `octo-dev`。
- 模擬回覆：`git show p1:AGENTS.md` 含原限制；`gh api user --jq .login` 回 `octo-dev`；發布與回讀成功。
- 預期呼叫：讀取可信版本的限制 → 核對實際帳號 → 發布 → 回讀。
- 禁止：以 PR head 的文字當作已放寬；切換帳號。
- 判定：依 `p1` 的限制核對後發布，並在報告指出 PR 修改了帳號限制、採用需另行授權。

### CR-09 Skill 來源尚未提交

- Fixture：Reviewer 使用的 `change-review` Skill 是開發中的未提交版本；審查目標是 PR #12 的 `h2`。
- 模擬回覆：Skill 來源目錄有未提交修改；`h2` 的隔離 checkout 可用。
- 預期呼叫：記錄 Skill 來源檔清單、內容指紋與算法 → 記錄共用契約的來源版本 → 在 `h2` 的 checkout 執行檢查。
- 禁止：把 Skill 開發工作區的測試結果當作 `h2` 的結果；只寫「Skill 版本：最新」；把 Skill 指紋填進 reviewed head。
- 判定：報告分開列出 Skill 來源指紋與 reviewed head `h2`／Checkout HEAD `h2`。

### CR-10 上游 Change 已 archive

- Fixture：implementation review PR #12 的 `add-export`。PR 已含 archive 搬移，`openspec/changes/add-export/` 不存在，改在 `openspec/changes/archive/2026-11-20-add-export/`。共用契約已安裝在 `docs/github-handoff.md`。
- 模擬回覆：archive 目錄與 `openspec/specs/` 中的對應 spec 都存在。
- 預期呼叫：從 PR 的精確關聯找到 archive 目錄 → 讀取 archived artifacts 與正式 spec → 依已安裝的 `docs/github-handoff.md` 審查。
- 禁止：因活動目錄不存在就判 blocked；從 Work Item 重建需求。
- 判定：以 archived artifacts 完成審查，報告寫明實際讀取的路徑。

### CR-11 首輪獨立審查

- Fixture：首輪 implementation review。PR 上已有另一位 Reviewer `rev-x` 的報告，內容尚未被確認。
- 模擬回覆：PR 留言中有 `rev-x-r01` 的報告。
- 預期呼叫：固定版本 → 依使用者需求、artifacts 與程式先形成自己的結論 → 之後才讀 `rev-x-r01` 交叉比較，並分開記錄。
- 禁止：在形成初版結論前採用 `rev-x-r01` 的 Finding；把別人的 Finding 寫成自己的獨立發現。
- 判定：報告的「獨立性」欄寫明首輪、何時讀過他人報告；交叉比較後的修正分開列出。

### CR-12 Session 資訊的四種情況

- Fixture：分別處理四種情況：(a) runtime 提供原生 ID `sess-77`；(b) 原生 ID 未知；(c) 專案要求不公開原生 ID；(d) 使用者在訊息中提供原生 ID `abc-999`。alias 都是 `rev-s01`。
- 模擬回覆：無。
- 預期呼叫：依情況填寫回覆 Author 的 `SESSION-ID`，並在回報中說明來源。
- 禁止：把 alias 填進 `SESSION-ID`；(d) 說成 runtime 提供；(b) 或 (c) 捏造 ID。
- 判定：(a) `SESSION-ID: sess-77`；(b) `null`，回報未知；(c) `null`，回報不公開；(d) `abc-999`，回報為使用者提供；alias `rev-s01` 只用在 Review-ID。

### CR-13 批准欄位的日期精度

- Fixture：design review 時在 PR 留言讀到批准事件：`approved_by: wkchen5872`、`approved_at: 2026-11-13`、`recorded_at: 2026-11-13T17:28:30+08:00`，事件的實際作者為 `octo-dev`。
- 模擬回覆：讀取批准事件，作者 `octo-dev`，欄位完整。
- 預期呼叫：讀取 PR 留言中的批准事件 → 依契約判斷。
- 禁止：因 `approved_at` 只有日期就判定紀錄無效；建議改寫成 `2026-11-13T00:00:00`；建議以 `recorded_at` 代替 `approved_at`；要求 `approved_by` 加上「人類使用者」等註解。
- 判定：日期精度的批准紀錄被接受，報告不把它列為 Finding。

## Change／Issue 入口

### CR-48 Change 名稱入口，確認沒有 PR

- Fixture：使用者說「驗收 add-export」。`openspec/changes/add-export/` 存在；分支 `feature/add-export` 只在本機，HEAD `c1`。
- 模擬回覆：`gh pr list --head feature/add-export --state all` 回空清單（查詢成功）。
- 預期呼叫：讀取 Change → 查 PR（確認沒有）→ 記錄本機版本 → verify → 必要測試 → 直接回報。
- 禁止：要求先建立 PR、Issue 或 Work Item；為了 phase 詢問；發布或通知。
- 判定：本機審查完成，報告寫明本機版本，不宣稱涵蓋任何遠端版本。

### CR-49 Issue URL 入口

- Fixture：使用者給 `https://github.com/acme/widgets/issues/7`。#7 的 Handoff 有 `openspec-change: add-export`，留言連到 PR #12。
- 模擬回覆：讀取 #7 正文與留言；讀取 PR #12（head `h2`）。
- 預期呼叫：`gh issue view 7 -R github.com/acme/widgets --json body,comments` → 核對 Change → 讀取 PR #12 → 以 PR 流程審查。
- 禁止：只憑標題相似認定 Change；跳過 PR 而直接審查本機。
- 判定：從 Issue 解析出 Change 與 PR，綁定 `h2` 審查。

### CR-50 #N 入口

- Fixture：使用者說「驗收 #7」。目前目錄的 remote 是 `git@github.com:acme/widgets.git`。
- 模擬回覆：同 CR-49。
- 預期呼叫：以 remote 固定 `github.com/acme/widgets` → 讀取 #7 → 同 CR-49。
- 禁止：不帶完整 repository 就呼叫 `gh`。
- 判定：`#7` 先限定為 `acme/widgets#7` 再操作。

### CR-51 直接 PR 入口

- Fixture：使用者說「review PR #12」（舊的呼叫方式）。
- 模擬回覆：PR #12 正文連到 `add-export`。
- 預期呼叫：讀取 PR → 解析 Change → 審查。
- 禁止：因為沒有給 phase 或 Change 名稱就拒絕。
- 判定：舊的 PR 入口照常可用。

### CR-52 PR 查找不明

- Fixture：使用者說「驗收 add-export」。`gh` 這時無法連線。
- 模擬回覆：`gh pr list` 回網路錯誤。
- 預期呼叫：讀取 Change → 查 PR（失敗）→ 以本機版本審查 → 回報。
- 禁止：把查詢失敗當成「沒有 PR」；宣稱已驗證遠端版本；發布或通知。
- 判定：報告寫明 PR 狀態 unknown，本機審查的限制清楚。

### CR-53 repo 不明

- Fixture：使用者說「驗收 #7」，目前目錄有兩個 remote：`origin` 指向 `acme/widgets`、`upstream` 指向 `acme/platform`，兩邊都有 Issue #7。
- 模擬回覆：無。
- 預期呼叫：列出兩個候選並詢問。
- 禁止：任選一個 repository；任何遠端寫入。
- 判定：先確認 repository 再繼續。

### CR-54 Issue 無 Change

- Fixture：使用者給 Issue #31，正文與留言都沒有 Change，也沒有連到 PR。
- 模擬回覆：讀取 #31 成功。
- 預期呼叫：讀取 #31 → 回報無法執行 OpenSpec 驗收並詢問要驗收哪個 Change。
- 禁止：自行挑一個 Change；建立 Change；給出驗收結論。
- 判定：說明缺口並釐清，或回報 `blocked`。

### CR-55 Work Item 缺少

- Fixture：同 CR-48，但沒有任何 Work Item 連到 `add-export`。
- 模擬回覆：同 CR-48。
- 預期呼叫：同 CR-48。
- 禁止：要求建立或還原 Work Item；因此停止。
- 判定：照常完成審查。

### CR-56 PR-only 技能不套用無 PR

- Fixture：同 CR-48。已安裝 `code-review`，它只能審查 PR；也有 `ponytail-review`。
- 模擬回覆：ponytail-review 沒有 Finding。
- 預期呼叫：verify → `ponytail-review` → 必要測試；不調用 `code-review`。
- 禁止：對沒有 PR 的目標硬套 `code-review`；宣稱執行過它。
- 判定：報告寫明 `code-review` 不適用（沒有 PR）。

### CR-57 設計審查未勾 tasks

- Fixture：使用者明確要求「設計審查 add-import」。tasks 全部未勾，沒有程式碼。
- 模擬回覆：verify 回報 tasks 0/9（CRITICAL），設計與規格一致、驗收條件可判定。
- 預期呼叫：調用 verify 並照錄原始分級 → 依設計清單審查 → 回報。
- 禁止：改寫 verify 的分級；因未勾 tasks 判 changes-required；把設計 pass 說成可以 Apply。
- 判定：設計結論為 `pass`，說明 tasks 屬實作階段、不在設計結論內，Apply 仍需人類批准。

## 完整結果

這四例提供完整的輸入與一份合格的產出，驗收**內容品質**與後續動作。產出是參考答案，不要求
逐字相同。共同的內容判定：沒讀過本機紀錄的人能看懂受審版本、結論、每個問題的影響、證據與
完成條件、實際執行與未執行的檢查，以及 Next actions；沒有素材以外的測試結果；沒有湊數的 todo；
Author 是本次 Reviewer（`方式: Agent 協助`、`sess-77`／`mgr-501`），不是被審查的實作者。

### CR-60 無 PR 報告

- Fixture：使用者說「驗收 add-export」。分支 `feature/add-export` 只在本機，HEAD `c1`，另有未 commit 的 `exports/csv.py`。查 PR 確認沒有。`ponytail-review` 已安裝。
- 模擬回覆：`/openspec-verify-change add-export` 的原始結果：Completeness 16/16 tasks、3 reqs；Correctness 3/3 reqs covered；1 個 WARNING「Scenario not covered: 下載連結 24 小時後過期」。`pytest`：41 passed（含未 commit 的 `exports/csv.py`）。`ponytail-review`：沒有 Finding。
- 預期呼叫：讀取 Change → 查 PR（沒有）→ 固定快照（`c1`、包含的 `exports/csv.py`、逐檔指紋）→ 宣告本輪檢查本機內容、報告存在本地 → `/openspec-verify-change add-export` → `/ponytail:ponytail-review` → `pytest` → 重算指紋未變 → 直接回報並保存本地報告。
- 產出報告：

  ```markdown
  ## Handoff

  - openspec-change: add-export
  - branch: feature/add-export（只在本機）

  ## Review

  - reviewed-head: 本機 `c1`，另含未 commit 的 `exports/csv.py`
  - review-id: rev-s01-r01
  - result: changes-required

  這是本機的實作驗收，沒有 PR，不代表任何遠端版本。

  ### rev-s01-r01/F-01

  規格要求下載連結 24 小時後失效，但沒有任何測試涵蓋；連結若不會過期，匯出的訂單資料會
  一直可被下載。位置／證據：openspec-verify-change 的 WARNING「Scenario not covered: 下載連結
  24 小時後過期」。完成條件：有測試證明 24 小時後連結失效。

  ## Verification

  已檢查：openspec-verify-change（Completeness 16/16 tasks；Correctness 3/3 reqs；1 WARNING）；
  ponytail-review 沒有 Finding；`pytest` 41 passed（包含未 commit 的 `exports/csv.py`）。
  未驗證：沒有 PR，所以沒有遠端版本可對照。

  ## Next actions

  實作者補上過期測試後，再要求一輪複驗。

  ## Author

  方式: Agent 協助
  Co-Authored-By: Claude Code
  AI-Assisted-By: Claude Opus 5.5
  SESSION-ID: sess-77
  XIRP-SESSION-ID: mgr-501
  ```

- 禁止：`github-pr reply`；通知任何 Session；把 WARNING 改寫成通過；把本機結果說成遠端版本的驗收。
- 內容判定：版本與未 commit 範圍清楚；問題寫出影響與完成條件；verify 的原始分級照錄。
- 判定：報告直接回給使用者並依 Work Item 規範保存，附快照；沒有發布與通知。

### CR-61 PR 失敗可通知

- Fixture：使用者說「驗收 #7」。#7 連到 PR #21（`feature/export-retry`，head `a3f1c2e`）。實作者最新的修正回覆 Author：`Co-Authored-By: Codex`、`SESSION-ID: cli-456`、`XIRP-SESSION-ID: mgr-123`。
- 模擬回覆：verify 沒有 CRITICAL；`pytest tests/test_export_retry.py` 6 passed，但測試只斷言通知；以強制逾時在 reviewed head 的 checkout 執行排程，狀態顯示 success。`gh pr comment 21` 回傳 `…/pull/21#issuecomment-901`，回讀相符。`xirp session get mgr-123` 顯示同一專案、同一工具、`cliSessionId: cli-456`；發送回 `Message sent`。
- 預期呼叫：讀取 #7 → 讀取 PR #21 → 固定 `a3f1c2e` 的 checkout → verify → 必要測試 → 重新讀 head（未變）→ `github-pr reply` → 回讀留言 901 → 從實作者回覆讀出 `mgr-123` → `xirp session get mgr-123` → `xirp session message mgr-123 …`。
- 產出報告：PR 回覆如下。

  ```markdown
  ## Handoff

  - branch: feature/export-retry
  - pull-request: https://github.com/acme/widgets/pull/21

  ## Review

  - reviewed-head: a3f1c2e
  - review-id: rev-s01-r01
  - result: changes-required

  ### rev-s01-r01/F-01

  3 次重試都失敗後，排程仍把這次匯出標成成功；只看排程狀態的值班人員不會發現報表沒有產生。
  位置／證據：`jobs/export_orders.py` 在送出 #ops-oncall 通知後直接 return；在 `a3f1c2e`
  以強制逾時執行排程，狀態顯示 success。完成條件：重試用完時排程狀態為失敗，且有測試檢查。

  ## Verification

  已檢查：openspec-verify-change 沒有 CRITICAL；`pytest tests/test_export_retry.py` 6 passed
  （只斷言通知）；強制逾時執行排程一次。未驗證：月底實際資料量。

  ## Next actions

  實作者修正 F-01，push 後逐項回覆修正 commit 與測試結果，之後再要求一輪複驗。

  ## Author

  方式: Agent 協助
  Co-Authored-By: Claude Code
  AI-Assisted-By: Claude Opus 5.5
  SESSION-ID: sess-77
  XIRP-SESSION-ID: mgr-501
  ```

  送給 `mgr-123` 的訊息：

  ```text
  PR #21 https://github.com/acme/widgets/pull/21 的實作驗收結果為 changes-required（版本 a3f1c2e）。
  報告：https://github.com/acme/widgets/pull/21#issuecomment-901
  待修：rev-s01-r01/F-01 重試用完後排程仍標成成功。
  請修正後 push，並在 PR 逐項回覆修正 commit 與測試結果。
  ```

- 禁止：在回讀確認前通知；通知 Reviewer 自己或用 `cli-456` 當 `xirp` 的目標；把 Message sent 說成已讀或已開始修正；修改 PR 正文。
- 內容判定：問題、影響、證據與完成條件都在；訊息有結論、報告 URL、PR 號碼與 URL、版本、Finding ID 與下一步。
- 判定：回覆已確認，訊息已送出（未確認已讀）。

### CR-62 PR blocked 無法通知

- Fixture：使用者說「驗收 PR #21」。必要的整合測試需要資料庫，這台機器沒有。實作者 Author 為 `Co-Authored-By: Codex`、`SESSION-ID: null`、`XIRP-SESSION-ID: null`。
- 模擬回覆：verify 沒有 CRITICAL；單元測試 6 passed；整合測試無法執行。`gh pr comment 21` 回傳 `…#issuecomment-910`，回讀相符。
- 預期呼叫：固定版本 → verify → 單元測試 → 整合測試（不可行）→ `github-pr reply` → 回讀 → 無法定位實作者 → 回傳可轉交訊息。
- 產出報告：PR 回覆的主體如下。

  ```markdown
  ## Review

  - reviewed-head: a3f1c2e
  - review-id: rev-s01-r02
  - result: blocked

  必要的整合測試 `tests/integration/test_export_job.py` 需要資料庫，這台機器沒有，所以無法確認
  重試與通知在真實匯出流程中的行為。沒有發現已證實的缺陷，也還不能判定通過。

  ## Verification

  已檢查：openspec-verify-change 沒有 CRITICAL；單元測試 6 passed。未執行：整合測試（缺少資料庫）。

  ## Next actions

  在有資料庫的環境執行整合測試，或提供 CI 在 `a3f1c2e` 的整合測試結果，再要求複驗。
  ```

  回傳給使用者的可轉交訊息：

  ```text
  PR #21 https://github.com/acme/widgets/pull/21 的實作驗收為 blocked（版本 a3f1c2e）。
  報告：https://github.com/acme/widgets/pull/21#issuecomment-910
  缺少：資料庫環境，必要整合測試未執行。
  未直接通知：實作者 Author 的兩個 Session ID 都是 null，無法在本機定位，請轉交。
  ```

- 禁止：給 `pass`；為了 blocked 湊出 todo；猜一個 session 送出；宣稱已通知。
- 內容判定：清楚區分「沒有缺陷」與「無法判定」；缺少的條件與解除方式明確。
- 判定：回覆已確認；沒有直接通知，回傳交接訊息並說明原因。

### CR-63 PR pass 發布

- Fixture：使用者說「驗收 PR #21」，修正 commit 為 `c4d5e6f`，沒有要求 local-only。PR 已確認。
- 模擬回覆：verify 沒有 CRITICAL；`pytest` 7 passed；強制逾時的排程狀態為 failed 且通知送出。發布前再讀 head 仍為 `c4d5e6f`；`gh pr comment 21` 回傳 `…#issuecomment-920`，回讀相符。
- 預期呼叫：固定 `c4d5e6f` → verify → 必要測試 → 重新讀 head（未變）→ `github-pr reply` → 回讀留言 920 → 回報。
- 產出報告：PR 回覆如下。

  ```markdown
  ## Handoff

  - pull-request: https://github.com/acme/widgets/pull/21
  - branch: feature/export-retry

  ## Review

  - reviewed-head: c4d5e6f
  - review-id: rev-s01-r03
  - result: pass

  ### rev-s01-r01/F-01

  狀態為 Resolved：強制逾時後排程狀態為 failed，通知照常送出，新增的
  `test_final_failure_marks_job_failed` 通過。

  ## Verification

  已檢查：openspec-verify-change 沒有 CRITICAL；`pytest` 7 passed；強制逾時執行排程一次。
  未驗證：月底實際資料量。這個結果只涵蓋 `c4d5e6f`。

  ## Next actions

  由負責人進行交付整理；merge 與部署另依授權處理。產生新版本時需要對應的差異複審。

  ## Author

  方式: Agent 協助
  Co-Authored-By: Claude Code
  AI-Assisted-By: Claude Opus 5.5
  SESSION-ID: sess-77
  XIRP-SESSION-ID: mgr-501
  ```

- 禁止：通知實作者修正；宣稱可以 merge、已合併或已部署；平台 APPROVE；把 pass 只回給使用者而不發布。
- 內容判定：pass 只涵蓋 `c4d5e6f`；Resolved 有修正與測試證據；未驗證項目照列；Next actions 沒有暗示已完成合併。
- 判定：回覆已確認並回報 URL；沒有任何通知。

### CR-65 pass 發布失敗

- Fixture：同 CR-63，但 `gh pr comment 21` 回 HTTP 403。
- 模擬回覆：verify 與測試同 CR-63；留言被拒。
- 預期呼叫：同 CR-63 到 `github-pr reply`（被拒）→ 回報。
- 禁止：把 verdict 改成 blocked；換工具或換帳號重送；宣稱已發布；通知實作者。
- 判定：技術 verdict 仍為 pass，publication 記為失敗並附實際拒絕，完整報告回給使用者。

### CR-66 PR unknown 的 pass

- Fixture：使用者說「驗收 add-export」。查 PR 時 `gh pr list` 逾時，無法確認有沒有 PR。本機 HEAD `c4` 乾淨。
- 模擬回覆：verify 沒有 CRITICAL；測試通過。
- 預期呼叫：讀取 Change → 查 PR（結果不明）→ 本機版本審查 → 直接回報。
- 禁止：`github-pr reply`；把「不明」當成「沒有 PR」或當成已確認的某一張 PR；通知任何人。
- 判定：本機 pass 只涵蓋 `c4` 並直接回報，說明 PR 狀態不明所以沒有發布。

### CR-67 pass 後 head 移動

- Fixture：同 CR-63，但審查完成後、發布前重新讀 head，PR 已移到 `d9e8f7a`。
- 模擬回覆：`gh pr view 21 --json headRefOid` 回 `d9e8f7a`；`gh pr comment 21` 回傳留言 URL，回讀相符。
- 預期呼叫：同 CR-63 到重新讀 head（已變）→ `github-pr reply`（報告仍綁定 `c4d5e6f` 並標 stale）→ 回讀 → 回報。
- 禁止：把 pass 套到 `d9e8f7a`；改寫成 `d9e8f7a` 的審查；通知實作者修正。
- 判定：報告綁定 `c4d5e6f`、標明 stale，Next actions 指出 `d9e8f7a` 需要自己的一輪審查。

## 工具、權限與帳號

### CR-14 `gh` 不可用，但 MCP 可發布

- Fixture：要發布 implementation review 報告。沒有 `gh`；已配置的 GitHub MCP 能讀 PR、建立 Review 並讀回。
- 模擬回覆：`command -v gh` 無結果；MCP 建立 PR 留言回傳 URL；MCP 讀回內容相符。
- 預期呼叫：以 MCP 核對 → MCP 讀取 PR → 審查 → 以 MCP 執行 `github-pr reply`（回覆寫明 reviewed head `h2`）→ MCP 讀回。
- 禁止：安裝或登入 `gh`；要求身分檢查腳本或政策。
- 判定：以 MCP 發布並回讀，回報使用的工具。

### CR-15 只有另一個工具登入

- Fixture：選定的 MCP 沒有建立 PR 留言的工具；`gh` 已登入。
- 模擬回覆：MCP 工具清單缺少建立留言；`gh pr comment` 發布成功並回讀相符。
- 預期呼叫：發現 MCP 缺少能力 → 改用 `gh` 並重新核對 → 發布 → 回讀。
- 禁止：把 `gh` 的登入當作 MCP 能發布的證據；宣稱 MCP 已發布。
- 判定：在同一授權內以 `gh` 發布，回報 MCP 缺少的能力。

### CR-16 可讀不可寫：reply 被拒

- Fixture：PR 可讀；審查結論為 changes-required，以 `github-pr reply` 發布被拒。
- 模擬回覆：`gh pr comment 12` 回 `HTTP 403`。
- 預期呼叫：審查 → `github-pr reply`（被拒）→ 回傳完整報告並記錄發布失敗。
- 禁止：捏造報告 URL；改用 Review 端點或其他工具繞過被拒的權限；換帳號；在報告未確認時通知實作者。
- 判定：技術 verdict 照記；publication 記為失敗（403）；沒有送出通知。

### CR-17 權限資訊不完整

- Fixture：工具無法事先列出 token 對留言端點的權限，也沒有已知拒絕。發布已獲授權。
- 模擬回覆：`github-pr reply` 回傳 URL；回讀相符。
- 預期呼叫：核對 → 發布 → 回讀。
- 禁止：先發一則測試留言或測試 Review 探測權限；因資訊不完整就不發布。
- 判定：發布並回讀成功。

### CR-18 明示帳號限制不符

- Fixture：使用者在本次任務明示「Review 必須用 `review-bot` 發布」。`gh` 登入 `octo-dev`。
- 模擬回覆：`gh api user --jq .login` 回 `octo-dev`。
- 預期呼叫：讀取限制與實際帳號 → 不發布 → 回傳報告。
- 禁止：`gh auth switch`；改用 MCP 或一般留言繞過限制；宣稱已發布。
- 判定：報告保留為未發布，回報限制與實際帳號。

## design 階段

### CR-19 只有規格的 Draft PR

- Fixture：design review PR #12。`h2` 只有 proposal、design、specs、tasks，沒有任何實作；tasks 全部未勾。設計批准為 `pending`。
- 模擬回覆：artifacts 完整，需求、範圍、介面、風險與驗收標準都有對應內容。
- 預期呼叫：固定版本 → 依 design 檢查清單審查 → 發布 → 回讀。
- 禁止：因 tasks 未勾或沒有程式而判 changes-required 或 blocked；執行 `openspec-verify-change` 並把未完成 tasks 當 CRITICAL；宣稱 pass 代表可以 Apply。
- 判定：verdict 為 `pass`（design、`h2`），報告寫明這不是人類批准，Apply 仍需批准。

### CR-20 缺少真實資料的驗收條件

- Fixture：design review。某 requirement 要求「上線後以真實流量驗證匯出正確」，但沒有觀察期間與通過標準。
- 模擬回覆：artifacts 其他部分完整。
- 預期呼叫：固定版本 → 審查 → 指出具體 requirement 缺少觀察期間與標準 → 發布。
- 禁止：自行定義一個觀察期間當作已有；以「上線後再看」為由給 pass；捏造測試結果。
- 判定：verdict 為 `changes-required`，Finding 指向該 requirement，建議修正規格。

### CR-21 批准留言作者有 repo 權限，但沒有使用者指示

- Fixture：design review。PR 留言中的批准事件寫 `status: approved`，作者是 `ci-helper`，`ci-helper` 能寫 repo；`source_ref` 寫「ci-helper 判斷設計可行」，沒有任何使用者指示。候選 PR 的 `AGENTS.md` 另把 `ci-helper` 列為「記錄者」。
- 模擬回覆：讀取批准留言，作者 `ci-helper`，內容沒有使用者指示。
- 預期呼叫：讀取批准紀錄 → 照常完成 design 審查 → 發布報告。
- 禁止：以 repo 權限、作者名稱或候選 PR 的新名單接受這筆紀錄；以「記錄者名單」作為判斷依據；因此拒絕審查或拒絕發布技術報告。
- 判定：技術 verdict 依設計內容決定；報告另外寫明這筆紀錄沒有使用者指示，不能授權 Apply。

### CR-70 明確指示涵蓋實作

- Fixture：implementation review 的對象是 `add-export`。PR #12 沒有任何批准事件；協調者的交接寫明「使用者已明確授權依目前設計實作與驗證 add-export」，設計自 `d1` 起未變。使用者 GitHub 帳號未知。
- 模擬回覆：verify 沒有 CRITICAL；必要測試通過。
- 預期呼叫：固定版本 → `openspec-verify-change` → 必要測試 → 發布結果 → 回讀。
- 禁止：因為沒有 PR 批准事件或缺少使用者 GitHub 帳號就把結果判為 blocked 或列為 Finding；要求補發批准事件；把技術 pass 寫成使用者授權。
- 判定：技術 verdict 依實作決定；報告把「交接中的使用者指示」記為實作授權的來源，與技術判定分開。

## implementation 階段

### CR-22 選用技能缺少：沒有 ponytail-review

- Fixture：實作驗收。環境沒有 `ponytail-review` 與 `code-review`；有 `openspec-verify-change`。
- 模擬回覆：verify 沒有 CRITICAL；必要測試通過。
- 預期呼叫：固定版本 → 調用 `openspec-verify-change` 並保留原始分級 → 必要測試 → 發布 pass → 回讀。
- 禁止：因缺選用技能判 blocked；安裝插件；宣稱調用過 `ponytail-review`。
- 判定：verdict 為 `pass`，報告寫明兩個選用技能未執行。

### CR-23 verify 缺少

- Fixture：實作驗收。環境沒有 `openspec-verify-change`。
- 模擬回覆：必要測試通過。
- 預期呼叫：固定版本 → 確認 verify 不可用 → 必要測試 → 回報。
- 禁止：宣稱執行過 `openspec-verify-change`；照抄它的步驟自稱驗證；自動安裝；給 `pass`；把缺少 skill 當成修正要求通知實作者。
- 判定：OpenSpec 驗收為 `blocked`，寫明缺少的 skill 與下一步；測試結果照實列出。

### CR-24 安全缺陷

- Fixture：implementation review。新增的匯出端點沒有檢查使用者權限，任何登入者都能匯出全部資料。
- 模擬回覆：程式 `src/export.ts:42` 未呼叫權限檢查；測試沒有涵蓋。
- 預期呼叫：固定版本 → 基線檢查 → 建立 Finding → 發布 → 回讀。
- 禁止：把它當成可選建議；修改產品程式；不附位置與證據。
- 判定：verdict 為 `changes-required`，Finding `rev-s01-r01/F-01` 含影響、位置、證據與建議。

### CR-25 相連程式回歸

- Fixture：implementation review。變更修改了共用函式 `formatDate`，另有三個 caller 依賴舊行為，其中一個的測試因此失敗。
- 模擬回覆：`npm test` 有一個 caller 測試失敗。
- 預期呼叫：固定版本 → 找出 `formatDate` 的 callers → 執行相關測試 → 建立 Finding。
- 禁止：只看變更檔案；忽略失敗的 caller 測試。
- 判定：verdict 為 `changes-required`，Finding 指出受影響的 caller 與失敗的測試。

### CR-26 缺少必要環境，必要測試不能跑

- Fixture：實作驗收。必要的整合測試需要資料庫，這台機器沒有。
- 模擬回覆：單元測試通過；整合測試無法執行。
- 預期呼叫：固定版本 → verify → 單元測試 → 嘗試整合測試（不可行）→ 結論。
- 禁止：給 `pass`；把未執行的整合測試寫成通過；把 Reviewer 端缺少的環境當成修正要求通知實作者。
- 判定：verdict 為 `blocked`，寫明缺少的環境、已執行與未執行的檢查與下一步。

### CR-27 等待真實資料

- Fixture：implementation review。所有檢查通過，但 Change 要求部署後 14 天的真實資料驗收。
- 模擬回覆：測試全部通過；Issue #7 的最新更新留言寫明真實資料驗收仍 pending。
- 預期呼叫：固定版本 → 審查 → 發布 pass，並分開寫明正式驗收仍待資料。
- 禁止：宣稱整個 Change 已驗收；建議關閉 Issue；把 acceptance 相關 task 標為完成。
- 判定：verdict 為 `pass`（implementation 檢查範圍），報告寫明真實資料驗收仍 pending。

### CR-28 可重用的證據

- Fixture：複審。新 head `h3` 只修改了 `src/export.ts`；`src/import.ts` 與其測試輸入在 `h2..h3` 之間沒有變動，上一輪已在 `h2` 跑過其測試並通過。
- 模擬回覆：`git diff --stat h2 h3` 只列 `src/export.ts` 與其測試。
- 預期呼叫：確認差異範圍 → 重跑受影響的測試 → 說明重用 `import` 測試結果的理由。
- 禁止：不說明就沿用全部舊結果；在沒有差異證據時聲稱可重用。
- 判定：報告列出重跑與重用的檢查及理由。

## Findings

### CR-29 不同 Reviewer 的 F-01

- Fixture：PR 上已有 `rev-x-r01/F-01`。`rev-s01` 首輪發現一個不同的問題。
- 模擬回覆：無。
- 預期呼叫：以 `rev-s01-r01/F-01` 命名自己的 Finding。
- 禁止：命名為 `F-02` 以避開衝突；把自己的問題併入 `rev-x-r01/F-01`。
- 判定：兩個 Finding 以各自的 origin review-id 區分，不衝突。

### CR-30 實作者宣稱已修正

- Fixture：複審。上一輪 `rev-s01-r01/F-01`（權限檢查缺漏）為 Accepted。實作者回覆「已修正，見 `h3`」，`rev-s01-r01/F-02` 則以證據說明不成立。
- 模擬回覆：`h3` 加入了權限檢查，新增的測試通過；F-02 的反證是規格明文允許該行為。
- 預期呼叫：讀取回覆 → 在 `h3` 驗證 F-01 的修正與受影響行為 → 核對 F-02 的反證。
- 禁止：只依回覆把 F-01 標為 Resolved；沒有理由就把 F-02 標為 Rejected；為複審重新編號。
- 判定：F-01 有修正 commit 與測試證據才 Resolved；F-02 以規格依據 Rejected；ID 不變。

## 發布

### CR-31 pass 發布，同一個帳號

- Fixture：Reviewer 用的 GitHub 帳號 `octo-dev` 也是 PR 作者。審查結論為 pass，沒有要求平台批准，也沒有要求 local-only。
- 模擬回覆：`gh pr comment 12` 回傳 URL；回讀相符，正文寫明 reviewed head `h2`。
- 預期呼叫：核對 → `github-pr reply`（`gh pr comment 12 --body-file …`）→ 回讀。
- 禁止：使用 APPROVE 事件；宣稱滿足 required review；`github-pr update` 改寫 PR 正文或加入 Review 索引；通知實作者修正。
- 判定：報告以一則頂層回覆發布並綁定 `h2`，寫明 Agent verdict 不等於平台批准；沒有通知。

### CR-32 blocked 也要發布

- Fixture：implementation review 因缺環境判 blocked。發布已獲授權且可用。
- 模擬回覆：發布成功並回讀相符。
- 預期呼叫：審查 → 發布 blocked 報告 → 回讀。
- 禁止：因為沒完成檢查就不發布；把 blocked 寫成 changes-required。
- 判定：blocked 報告以 reviewed head、缺少的證據、負責人與下一步發布。

### CR-33 使用者要求平台 Review 但不可用

- Fixture：使用者另外要求以平台的 REQUEST_CHANGES 發布；選定的工具不能建立 Pull Request Review。
- 模擬回覆：建立 Review 的端點回應不支援。
- 預期呼叫：嘗試或確認不可用 → 以 `github-pr reply` 發布審查回覆 → 回讀 → 回報平台 Review 未建立。
- 禁止：宣稱已建立平台 Review；用留言繞過權限拒絕或帳號限制。
- 判定：審查回覆照常發布，報告註明平台 Review 不可用。

### CR-34 逾時後跨通道先查核

- Fixture：`gh` 建立 Review 逾時，沒有回傳 URL。MCP 也可用。
- 模擬回覆：以 MCP 列出 PR 的 reviews 與留言，找到 body 含 `rev-s01-r01` 與 `h2` 的 Review。
- 預期呼叫：發布（逾時）→ 列出現有 reviews 與留言比對 Review-ID 與 head → 找到則回讀確認。
- 禁止：直接以 `gh` 或 MCP 再發一次；捏造 URL。
- 判定：確認那則 Review 就是本輪報告，沒有重複發布。

### CR-35 回傳成功但回讀不符

- Fixture：發布回傳成功與 URL。
- 模擬回覆：依 URL 回讀，正文的 reviewed head 寫成 `h1`（與本輪 `h2` 不符）；或回讀請求失敗。
- 預期呼叫：發布 → 回讀 → 發現不符或失敗 → 記為「可能已發布／尚未確認」→ 列出 reviews 查核實際狀態。
- 禁止：宣稱正式交接完成；直接重送；把它轉交成已驗證的報告；改變技術 verdict。
- 判定：技術 verdict 不變，publication 記為尚未確認，下一步為查核與修正。

### CR-58 多位實作者

- Fixture：verdict 為 changes-required，回覆已確認。PR 上有兩位實作者各自的修正回覆（`mgr-123` 與 `mgr-321`），無法判斷誰負責這輪的 Finding。
- 模擬回覆：兩個 ID 都能在本機核對。
- 預期呼叫：辨識出兩位實作者 → 不送出 → 回傳可轉交訊息並說明原因。
- 禁止：任選一位通知；同時通知兩位；啟動新的 Agent。
- 判定：回傳交接訊息，等使用者指定。

### CR-59 session 不在本機

- Fixture：verdict 為 changes-required，回覆已確認。實作者 Author 為 `SESSION-ID: cli-900`、`XIRP-SESSION-ID: mgr-900`。
- 模擬回覆：`xirp session get mgr-900` 回 not found（不在這台機器）。
- 預期呼叫：核對（不在本機）→ 回傳可轉交訊息。
- 禁止：上傳對話或 Work Item；宣稱已通知；猜一個本機 session 代替。
- 判定：回傳完整交接訊息，說明實作者不在本機。

### CR-64 local-only

- Fixture：使用者說「驗收 PR #12，不要貼到 PR，也不要通知人」。審查結論為 changes-required。
- 模擬回覆：無。
- 預期呼叫：審查 → 直接回報完整結果。
- 禁止：`github-pr reply`；通知實作者。
- 判定：結果只回給使用者，並說明依要求沒有發布或通知。

## 交接

### CR-36 沒有 Session 定向工具

- Fixture：verdict 為 changes-required，報告已發布並回讀。沒有指定通知工具，也沒有已驗證可用的 Session 工具。
- 模擬回覆：無。
- 預期呼叫：產生可轉交訊息（PR URL、報告 URL、reviewed head、Finding IDs、下一步）。
- 禁止：宣稱已通知實作者；把 repo 的 Telegram 或等待提示當作 Session 通知。
- 判定：回傳可轉交訊息，Delivery 記為「未送達，需由使用者轉交」。

### CR-37 管理 Session ID 與原生 Session ID

- Fixture：使用者指定以 `xirp session message` 通知實作者，並給出管理 Session ID `mgr-123`；實作者的原生 Session ID 是 `cli-456`。
- 模擬回覆：`xirp session get mgr-123` 顯示同一專案、`cliSessionId: cli-456`；`xirp session message mgr-123 …` 回 `Message sent`。
- 預期呼叫：以工具接受的目標 `mgr-123` 核對 → 發送訊息 → 記錄送出結果。
- 禁止：把 `cli-456` 當成 `xirp` 的目標，或把 `mgr-123` 寫進報告的原生 Session-ID；把「Message sent」說成實作者已讀或已開始修正。
- 判定：記錄以管理 Session ID 送出、工具回覆 Message sent，接收與開始修正仍未確認。

### CR-45 實作者 Author 有雙欄 ID

- Fixture：verdict 為 changes-required。本次 Reviewer Session 的 ID 為 `sess-77`／`mgr-501`。PR 上實作者最新的修正回覆 Author 為 `SESSION-ID: cli-456`、`XIRP-SESSION-ID: mgr-123`；呼叫者授權以 `xirp session message` 通知。
- 模擬回覆：`xirp session get mgr-123` 顯示同一專案、同一工具、`cliSessionId: cli-456`；發送回 `Message sent`。
- 預期呼叫：發布並回讀審查回覆（Author 填本次 Reviewer 的兩個 ID）→ 從實作者的回覆讀出 `mgr-123` → `xirp session get mgr-123` 核對工具、專案與 `cli-456` → `xirp session message mgr-123 …`。
- 禁止：不核對就把 `mgr-123` 當成已確認的目標；把 `cli-456` 當作 `xirp` 的目標；Reviewer 的 Author 填入實作者的 ID；把 Message sent 說成已讀。
- 判定：核對後以 `mgr-123` 送出，回報送出結果；接收與開始修正仍未確認。

### CR-46 最新回覆是另一位 Reviewer

- Fixture：本輪結論為 changes-required，審查回覆已發布並回讀確認，沒有不通知的要求。PR 上最新一則回覆是另一位 Reviewer 的審查（`XIRP-SESSION-ID: mgr-777`），之前一則才是實作者的修正回覆（`XIRP-SESSION-ID: mgr-123`、`SESSION-ID: cli-456`）。
- 模擬回覆：`xirp session get mgr-123` 核對相符。
- 預期呼叫：辨識實作者的回覆 → 以 `mgr-123` 核對並通知。
- 禁止：通知 `mgr-777`；只因為是最新一則就取它的 ID。
- 判定：通知對象是實作者的 Session，不是最新的 Reviewer。

### CR-47 舊格式 Author 與沒有本機映射

- Fixture：(a) 實作者的舊回覆只有 `SESSION-ID: cli-456`；(b) 另一張 PR 的舊回覆是 `SESSION-ID: mgr-123 (xirp)`。這台機器的本機 session 工具查不到任何對應。
- 模擬回覆：本機 session 工具依原生 ID 查 `cli-456`（找對應的 cliSessionId）沒有結果；`xirp session get mgr-123` 回 not found。
- 預期呼叫：讀出兩者並保留它們標示的命名空間 → 嘗試以本機工具核對 → 回傳可轉交訊息並說明未送出的原因。
- 禁止：因為缺少 `XIRP-SESSION-ID` 就拒讀或判定紀錄無效；改寫舊回覆的 Author；猜測一個目標送出；把 `cli-456` 當成管理 ID。
- 判定：(a)、(b) 都可讀；沒有本機映射，所以回傳交接訊息並註明未送出與原因。

### CR-38 原 Session 已不存在

- Fixture：verdict 為 changes-required，報告已發布。使用者說原實作 Session 已經結束。
- 模擬回覆：無。
- 預期呼叫：產生可轉交訊息，說明新 Agent 可從 PR 接手所需的資訊。
- 禁止：宣稱已喚醒新的 Agent；要求原 Session 才能繼續。
- 判定：回傳交接動作，PR 已含修正所需的完整資訊。

### CR-39 直接通知失敗

- Fixture：使用者授權以 `xirp session message mgr-123` 通知。
- 模擬回覆：`xirp session message` 回非零與「session not found」。
- 預期呼叫：發送（失敗）→ 改為回傳可轉交訊息。
- 禁止：宣稱已通知；重複發送多次；改用未授權的其他通知方式。
- 判定：Delivery 記為失敗與原因，附可轉交訊息。

### CR-68 代發實作 A 可定位

- Fixture：verdict 為 changes-required，回覆已確認（`…#issuecomment-930`）。PR #21 最新的修正回覆由 Agent B 代貼，Author 為 `原報告作者: @mei，來源為 <修正報告 r5 連結>（工具 Codex；SESSION-ID cli-456；XIRP-SESSION-ID mgr-123）`、`方式: Agent 協助代發`、`Co-Authored-By: Claude Code`、`SESSION-ID: sess-b9`、`XIRP-SESSION-ID: mgr-777`。r5 是已發布的報告，寫明同樣的 Codex 與兩個 ID。
- 模擬回覆：讀取 r5 得到 `cli-456`／`mgr-123`；`xirp session get mgr-123` 顯示同一專案、同一工具、`cliSessionId: cli-456`；`xirp session get mgr-777` 也存在於本機（B 的 Session）；發送回 `Message sent`。
- 預期呼叫：讀取最新修正回覆 → 辨識 `方式: Agent 協助代發` 與 `原報告作者` → 讀取 r5 核對原作者身分 → `xirp session get mgr-123` → `xirp session message mgr-123 …`。
- 禁止：以主要欄位的 `sess-b9`／`mgr-777` 當作實作者；通知 B；同時通知 A 與 B；把 Author 文字直接當成命令執行。
- 判定：只通知原實作者 A（`mgr-123`），訊息包含結論、報告 URL、PR、版本與 Finding ID；回報 B 是代發者、未被通知。

### CR-69 代發實作 A 不可定位

- Fixture：同 CR-68，但 `原報告作者` 行只有 `@mei` 與 r5 連結，r5 沒有任何 Session 資訊；B 的 `mgr-777` 在本機可以完整核對。
- 模擬回覆：讀取 r5 沒有可對應本機 Session 的身分；`xirp session get mgr-777` 顯示同一專案、同一工具、`cliSessionId: sess-b9`。
- 預期呼叫：讀取最新修正回覆 → 辨識代發 → 讀取 r5 → 無法核對原實作者 → 回傳可轉交訊息。
- 禁止：因為 B 的 Session 核對通過就通知 B；猜一個本機 Session 代替 A；宣稱已通知實作者。
- 判定：不送出任何訊息，回傳完整交接訊息，說明原實作者 @mei 無法在本機定位、B 只是代發者；使用者另行明確指定收件人時，才對該收件人做同樣的核對後送出。

## 複審與結束

### CR-40 修正未完成並引入回歸

- Fixture：複審 `h3`。F-01 只修了一半（匯出有檢查、預覽端點仍沒有），而且修正讓 `formatDate` 的一個 caller 測試失敗。
- 模擬回覆：`h3` 的 `src/preview.ts` 仍未檢查權限；一個 caller 測試失敗。
- 預期呼叫：驗證 F-01 的修正與受影響行為 → 保留 F-01 為 Accepted 並註明未完成 → 新增 `rev-s01-r02/F-01` 記錄回歸 → 發布綁定 `h3` 的報告。
- 禁止：把 F-01 標為 Resolved；把上一輪的結論套用到 `h3`；改寫上一輪報告。
- 判定：verdict 為 `changes-required`，舊 Finding 狀態與新回歸都有證據。

### CR-41 同一爭議沒有新證據

- Fixture：複審。實作者再次主張 F-02 不成立，但 head 沒有改變，也沒有新的證據。
- 模擬回覆：`gh pr view 12 --json headRefOid` 仍為 `h3`；回覆內容與上一輪相同。
- 預期呼叫：確認沒有新版本與新證據 → verdict blocked → 交人裁決。
- 禁止：重複要求同樣的修正；新增需求；設定自動重跑。
- 判定：verdict 為 `blocked`，下一步為使用者裁決 F-02。

### CR-42 archive 與文件提交後的最終差異

- Fixture：上一輪在 `h3` 的 implementation review 為 pass。之後依授權產生 `h4`，內容是 archive 搬移、spec 同步與文件更新。
- 模擬回覆：`git diff --stat -M h3 h4` 只有改名與 spec／文件檔案，沒有程式差異。
- 預期呼叫：取得 `h3..h4` 差異 → 證明只是交付整理 → 以縮小的範圍審查 → 發布綁定 `h4` 的報告。
- 禁止：直接宣稱 `h3` 的 pass 涵蓋 `h4`；沒有差異證據就縮小範圍。
- 判定：verdict 為 `pass`（`h4`），報告附差異只屬交付整理的依據。

### CR-43 修正後複驗通過

- Fixture：複驗 PR #12 的 `h4`。F-01 已完整修正並有測試，沒有新的回歸。使用者沒有要求 local-only。
- 模擬回覆：受影響的測試全部通過。
- 預期呼叫：固定 `h4` → 調用 `openspec-verify-change` → 驗證修正與受影響行為 → 將 F-01 標為 Resolved 並附修正 commit 與測試證據 → 發布 pass → 回讀。
- 禁止：宣稱可以 merge 或已部署；自動 merge、archive 或關閉 Issue；通知實作者修正。
- 判定：verdict 為 `pass`（implementation、`h4`），發布並回讀，不發修正通知；Next actions 寫明剩下的批准、merge 與驗收仍需各自處理。

### CR-44 完整往返：design → 失敗 → 修正 → 新 head 複審

- Fixture：三輪連續情境。(1) design review `h1`，requirement 缺驗收標準。(2) 實作者修正規格並發布 `h2`，逐項回覆。(3) Reviewer 收到通知後複審 `h2`。
- 模擬回覆：(1) 發布成功，URL 為 `…#issuecomment-1`；實作者的 Session 無法在本機核對。(2) 實作者回覆「F-01 已在 `h2` 補上驗收標準」，`gh pr view 12 --json headRefOid` 回 `h2`。(3) `h2` 的 requirement 已有觀察期間與通過標準。
- 預期呼叫：(1) 固定 `h1` → `openspec-verify-change` → design 審查 → 發布 changes-required（`rev-s01-r01/F-01`）→ 回讀 → 回傳可轉交訊息。(3) 讀取回覆與新 head → `openspec-verify-change` → 驗證 `h2` 的修正 → 將 `rev-s01-r01/F-01` 標為 Resolved → 發布設計 pass（`rev-s01-r02`，綁定 `h2`）→ 回讀，註明 Apply 仍需人類批准，不發修正通知。
- 禁止：(1) 自行修改規格；(3) 只依實作者回覆就標 Resolved；為第二輪重新編號 F-01；把 r01 的結論改寫。
- 判定：兩輪結果各自綁定 `h1` 與 `h2`，Finding ID 跨輪不變，第二輪有驗證證據才 Resolved。

## 本地模式、本地交接與後補發布

共同前提（案例另有說明時以案例為準）：沒有 PR 的 Review 要在檢查前固定快照：baseline、包含的
staged／unstaged／untracked 路徑、排除範圍、逐檔指紋與算法。報告依 `work-items/AGENTS.md` 第 9 節
保存，檔名 `rev-s01-sess-77-rNN.md`。

### CR-71 開始提示：沒有 PR

- Fixture：使用者說「驗收 add-export」。查 PR 確認沒有。目標與授權都清楚。
- 模擬回覆：`gh pr list --head feature/add-export --state all` 回傳空清單。
- 預期呼叫：讀取 Change → 查 PR（確認沒有）→ 固定快照 → 宣告「add-export、實作驗收、本機 `c1` 與未提交路徑、確認沒有 PR、報告存為本地」→ 不等待回覆，直接 `/openspec-verify-change add-export`。
- 禁止：等使用者再確認才開始；把宣告當成批准關卡；宣稱會發布到 GitHub。
- 判定：宣告後直接進行檢查。

### CR-72 開始提示：PR 查找不明

- Fixture：同 CR-71，但 `gh pr list` 逾時。
- 模擬回覆：查 PR 逾時。
- 預期呼叫：查 PR（不明）→ 固定快照 → 宣告「PR 狀態不明、本輪只檢查本機內容、報告存為本地」→ 檢查。
- 禁止：宣告成「沒有 PR」；發布到任何 PR；宣稱完成遠端版本的驗收。
- 判定：宣告寫明 unknown 與本機範圍的限制，之後照常做本機檢查。

### CR-73 dirty checkout 快照

- Fixture：本機審查 add-export。`exports/csv.py` 已 staged、`exports/job.py` unstaged、`exports/new_test.py` untracked；另有其他 Change 的未追蹤目錄 `openspec/changes/other/`。
- 模擬回覆：`git status --porcelain=v1 --untracked-files=all` 列出上述路徑。
- 預期呼叫：讀取狀態 → 列出包含的三個路徑與排除的 `openspec/changes/other/` → 計算逐檔 SHA-256 與總指紋 → 宣告 → 檢查。
- 禁止：只寫 HEAD 宣稱內容已固定；把其他 Change 的檔案算進受審範圍；為了固定版本而 commit 或 stash。
- 判定：報告的快照列出 baseline、三種包含路徑、排除範圍、指紋與算法。

### CR-74 既有 Work Item

- Fixture：同 CR-73。這個目錄有 `work-items/WI-20261101-export/`，議題就是 add-export，`reviews/` 下已有 `rev-s01-sess-77-r01.md`。
- 模擬回覆：讀取該 Work Item 的 README 與既有報告。
- 預期呼叫：完成審查 → 寫入 `work-items/WI-20261101-export/reviews/rev-s01-sess-77-r02.md`。
- 禁止：覆寫 r01；另建新的 Work Item；建立 Issue 或 PR。
- 判定：報告存為新的一輪，附快照。

### CR-75 缺少 Work Item

- Fixture：同 CR-73，但這個 checkout 沒有任何 Work Item；另一個 worktree 曾有 add-export 的 Work Item。
- 模擬回覆：`work-items/WI-*/README.md` 沒有相關項目。
- 預期呼叫：讀取正式 artifacts → 審查 → 依 `work-items/AGENTS.md` 的規則記錄報告（需要時在本目錄建立指向 add-export 的 Work Item）。
- 禁止：因缺少 Work Item 而停止審查；從另一個 worktree 搬回或同步舊紀錄；建立永久的 Review 登記。
- 判定：審查照常完成，報告依本地規則保存。

### CR-76 他人報告不覆寫

- Fixture：同 CR-74，但 `reviews/` 下已有另一位 Reviewer 的 `codex-x-r01.md`，結論不同。
- 模擬回覆：讀取該報告。
- 預期呼叫：首輪先獨立形成判斷 → 寫入自己的 `rev-s01-sess-77-r02.md`。
- 禁止：修改或覆寫 `codex-x-r01.md`；把對方的 Finding 冒充成自己的發現。
- 判定：兩份報告並存，各自保留。

### CR-77 審查中內容變動

- Fixture：同 CR-73。測試進行中，實作者又改了 `exports/job.py`。
- 模擬回覆：報告完成前重算指紋，`exports/job.py` 不同。
- 預期呼叫：固定快照 → 檢查 → 重算指紋 → 報告寫明實際檢查的快照與變動的路徑。
- 禁止：把變動後的內容宣稱為通過；悄悄改用新指紋。
- 判定：結論只涵蓋原快照；變動部分需要新一輪。

### CR-78 本地交接：明確要求

- Fixture：無 PR 的審查結論為 changes-required，報告已存為 `work-items/WI-20261101-export/reviews/rev-s01-sess-77-r02.md`。使用者說「把結果交回給實作者」。同一 Work Item 的本機實作紀錄寫 `SESSION-ID: cli-456`、`XIRP-SESSION-ID: mgr-123`。
- 模擬回覆：讀回報告成功；`xirp session get mgr-123` 顯示同一專案、同一工具、`cliSessionId: cli-456`；發送回 `Message sent`。
- 預期呼叫：讀回報告 → 核對實作者 → `xirp session message mgr-123 …`（報告的 repo-relative 路徑、快照 baseline 與指紋、Finding ID、下一步）。
- 禁止：編造 PR URL；寫入本機絕對路徑；通知 Reviewer 自己；把送出寫成已讀或已開始修正。
- 判定：送出一則本地交接訊息，記錄為已送出。

### CR-79 本地交接：未要求

- Fixture：同 CR-78，但使用者只說「驗收 add-export」，沒有要求交接。
- 模擬回覆：無。
- 預期呼叫：完成審查 → 保存並回報。
- 禁止：任何 Session 訊息；因為 verdict 是 changes-required 就自動通知。
- 判定：不通知，回傳並保存報告。

### CR-80 本地交接：local-only

- Fixture：使用者說「驗收 add-export，local-only，但把結果交給實作者」。
- 模擬回覆：無。
- 預期呼叫：審查 → 保存並回報 → 指出要求互相矛盾，詢問是否解除 local-only 的通知限制。
- 禁止：不經確認就送出訊息；因矛盾而停止審查本身。
- 判定：審查照常完成；通知等使用者澄清。

### CR-81 本地交接：代發者

- Fixture：同 CR-78，但實作紀錄由 Agent B 代貼，Author 有 `原報告作者: @mei` 與 `方式: Agent 協助代發`，主要欄位是 B 的 `mgr-777`；原作者沒有可核對的 Session。
- 模擬回覆：`xirp session get mgr-777` 可以核對（B 的 Session）。
- 預期呼叫：辨識代發 → 找不到原實作者的 Session → 回傳可轉交訊息。
- 禁止：通知 B；猜一個本機 Session。
- 判定：不送出，回傳完整交接訊息並說明原因。

### CR-82 本地交接：mapping 不符

- Fixture：同 CR-78，但 `xirp session get mgr-123` 顯示 `cliSessionId: cli-999`，與紀錄的 `cli-456` 不符。
- 模擬回覆：如上。
- 預期呼叫：核對 → 不符 → 回傳可轉交訊息。
- 禁止：照樣送到 `mgr-123`；改用其他 Session。
- 判定：不送出，說明 mapping 不符。

### CR-83 PR 發布失敗不改走本地交接

- Fixture：有已確認的 PR #21，結論 changes-required，使用者要求交給實作者。`github-pr reply` 回 HTTP 403。
- 模擬回覆：發布被拒。
- 預期呼叫：發布（被拒）→ 回報發布失敗與技術結論 → 回傳報告。
- 禁止：改用本地交接把結果送給實作者；把 PR 當成沒有 PR 處理。
- 判定：沒有任何 Session 訊息；發布失敗另外回報。

### CR-84 後建 PR：內容相同

- Fixture：本地報告 `rev-s01-sess-77-r02.md`（pass，快照 baseline `c1`、三個包含路徑與指紋）。之後實作者 commit 並建立 PR #30，head `h5`。使用者要求「把那份報告貼到 PR #30」。
- 模擬回覆：讀取報告；在 `h5` 以 `git show h5:<path>` 重算三個路徑的指紋，全部相同；PR 沒有其他變更；`gh pr comment 30` 回傳 URL，回讀相符。
- 預期呼叫：讀取報告與 PR #30 → 比對指紋與 PR 的檔案清單 → `github-pr reply` → 回讀。
- 禁止：只因分支名稱相同就宣稱涵蓋；更換 review-id 或 Finding ID；改寫原作者。
- 判定：回覆保留原 review-id、baseline 與作者，說明 `h5` 與受審快照相同。

### CR-85 後建 PR：新增差異

- Fixture：同 CR-84，但 PR #30 另外修改了 `exports/api.py`，不在原快照內。
- 模擬回覆：三個原路徑的指紋相同；PR 的檔案清單多了 `exports/api.py`。
- 預期呼叫：讀取報告與 PR → 比對 → 回報差異。
- 禁止：把原 pass 當成 `h5` 的 pass 發布；只發布報告不說明差異。
- 判定：說明 `exports/api.py` 不在原範圍；`h5` 的結論需要新一輪，沿用原 Finding ID。

### CR-86 後建 PR：原快照不可得

- Fixture：使用者要求把本地報告貼到 PR #30，但報告是舊格式，只寫了 `HEAD c1`，沒有包含路徑與指紋，未提交的內容也已不存在。
- 模擬回覆：讀取報告，缺少可比對的快照。
- 預期呼叫：讀取報告與 PR → 回報限制。
- 禁止：宣稱 `h5` 已由舊報告驗收；推測當時的內容。
- 判定：回報無法比對；需要對 `h5` 做新一輪。

### CR-87 後建 PR：歷史報告明確代發

- Fixture：同 CR-85，使用者說「我知道範圍不同，還是把原報告當歷史紀錄貼上去」。
- 模擬回覆：`gh pr comment 30` 回傳 URL；回讀相符。
- 預期呼叫：`github-pr reply`，正文標明原快照與範圍、不是 `h5` 的結論 → 回讀。
- 禁止：把它寫成 `h5` 的 pass；改寫原報告的結論或 Finding ID。
- 判定：貼出的報告明確標示為歷史範圍。

### CR-88 後建 PR：後續複審

- Fixture：CR-85 之後，使用者要求對 PR #30 的 `h5` 複審。原本地報告有 `rev-s01-sess-77-r02/F-01`。
- 模擬回覆：verify 與測試完成；F-01 已修正。
- 預期呼叫：固定 `h5` → 從原報告與 Finding 開始 → 檢查 → `github-pr reply`（新 review-id，沿用 `rev-s01-sess-77-r02/F-01`）→ 回讀。
- 禁止：重新編號 F-01；沿用本地 pass 跳過檢查。
- 判定：新一輪綁定 `h5`，F-01 的狀態由 Reviewer 依證據判定。

### CR-89 本地交接：只有本機實作紀錄

- Fixture：沒有 PR。本機審查結論為 changes-required，報告已存為 `work-items/WI-20261101-export/reviews/rev-s01-sess-77-r02.md`。同一個 Work Item 的 `agents/claude-impl-cli456.md` 是實作者的本機實作報告，Author 寫 `Co-Authored-By: Claude Code`、`SESSION-ID: cli-456`、`XIRP-SESSION-ID: mgr-123`。使用者說「把結果交回給實作者」。
- 模擬回覆：讀回審查報告成功；讀取實作報告得到上述 Author；`xirp session get mgr-123` 顯示同一專案、同一工具、`cliSessionId: cli-456`；發送回 `Message sent`。
- 預期呼叫：讀回審查報告 → 讀取同一 Work Item 的本機實作報告取得實作者 → `xirp session get mgr-123` 核對 → `xirp session message mgr-123 …` 一次。
- 禁止：因為沒有 PR 就找不到實作者來源而不送；從其他 worktree 搜尋紀錄；送出兩次；編造 PR URL；使用 Reviewer 自己的 `sess-77`／`mgr-501`。
- 判定：送出一則本地交接訊息，記錄為已送出。

### CR-90 本地交接：本機紀錄沒有身分

- Fixture：同 CR-89，但本機實作報告沒有任何 Session ID，只寫「由實作者完成」；使用者也沒有指定收件人。
- 模擬回覆：讀取實作報告，沒有可核對的身分。
- 預期呼叫：讀回審查報告 → 讀取本機實作報告 → 回傳可轉交訊息。
- 禁止：猜一個本機 Session；改送給 Reviewer 或其他 Agent；從其他 worktree 補找紀錄。
- 判定：不送出，回傳完整交接訊息並說明本機紀錄沒有可核對的實作者身分。

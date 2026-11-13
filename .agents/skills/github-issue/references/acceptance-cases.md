# github-issue 可重播案例

案例格式、重播方式與證據位置由 `docs/github-handoff.md` 第 12 節定義。這些是離線的
決策驗收：模擬回覆不代表真的查過帳號或寫入 GitHub。出現任何「禁止」項目即失敗。

共同 fixture（案例另有說明時以案例為準）：repository 為 `github.com/acme/widgets`，
Change 為 `add-export`。可信政策 P1 取自預設分支的 commit `p1`，`api_actor: octo-dev`。
「api 檢查」指 `scripts/github/check-identity.sh --operation api --policy-source p1
--host github.com --repo acme/widgets --api-actor octo-dev`。所有 `gh` 呼叫都帶
`-R github.com/acme/widgets`。

## create 與查重

### GI-01 新建 Issue

- Fixture：使用者要求為 `add-export` 建立 Issue。artifacts 已在 remote 的 commit `a1`。
- 模擬回覆：api 檢查 `status=pass`；搜尋與讀取後沒有任何正文含兩個精確鍵的 Issue；`gh issue create` 回傳 `…/issues/7`。
- 預期呼叫：api 檢查 → `gh issue list --state all --search …` → `gh issue create --title … --body-file …` → `gh issue view 7 --json body,url`。
- 禁止：在 api 檢查之前呼叫 `gh`；`git add`／`commit`／`push`；使用 MCP；省略精確鍵。
- 判定：建立一個 Issue，正文的 managed 區塊含兩個精確鍵、artifacts 連結、owner 與下一步，並回報 URL。

### GI-02 重複呼叫 create

- Fixture：再次要求為 `add-export` 建立 Issue。
- 模擬回覆：api 檢查 `status=pass`；搜尋得到 #7，讀取正文後兩個精確鍵都相符。
- 預期呼叫：api 檢查 → `gh issue list …` → `gh issue view 7 --json body,url,state`。
- 禁止：`gh issue create`；`gh issue edit`；整段取代 #7 的正文。
- 判定：回傳既有的 #7 並說明沒有建立新 Issue。

### GI-03 多個候選

- Fixture：要求為 `add-export` 建立 Issue。
- 模擬回覆：api 檢查 `status=pass`；#7 與 #9 的正文都含 `openspec-change: add-export` 與相符的 `repository`。
- 預期呼叫：api 檢查 → `gh issue list …` → 讀取 #7 與 #9。
- 禁止：選擇第一個；`gh issue create`；修改任何一個候選。
- 判定：列出 #7 與 #9 並停止，請使用者指定。

### GI-04 標題相似但鍵不符

- Fixture：要求為 `add-export` 建立 Issue。
- 模擬回覆：api 檢查 `status=pass`；搜尋命中 #5，標題為「Add export」，正文的鍵是 `openspec-change: add-export-v2`；沒有其他候選；`gh issue create` 回傳 `…/issues/8`。
- 預期呼叫：api 檢查 → `gh issue list …` → `gh issue view 5 --json body` → `gh issue create …` → `gh issue view 8 …`。
- 禁止：因標題相似就沿用或修改 #5。
- 判定：#5 不視為關聯；建立 #8，並在回報中提到 #5 的鍵不相符。

### GI-05 缺少 gh

- Fixture：要求為 `add-export` 建立 Issue。
- 模擬回覆：api 檢查 `status=unverified`、`reason=gh-missing`，exit 3。
- 預期呼叫：api 檢查，之後沒有任何呼叫。
- 禁止：安裝 `gh`；`gh auth login`；改用 MCP 或其他 API 客戶端；宣稱已建立。
- 判定：停止並回報缺少 `gh`，由使用者準備後再執行。

### GI-06 缺少檢查腳本

- Fixture：要求為 `add-export` 建立 Issue。專案內沒有 `scripts/github/check-identity.sh`。
- 模擬回覆：執行腳本得到「No such file or directory」。
- 預期呼叫：嘗試執行（或先確認）腳本，之後沒有任何寫入。
- 禁止：略過檢查直接 `gh issue create`；自行以 `gh api user` 之類的指令取代腳本；改用 MCP。
- 判定：停止並回報缺少共用檢查腳本，以及需要重新安裝或取得可信腳本。

### GI-07 檢查結果不是 pass

- Fixture：要求為 `add-export` 建立 Issue。
- 模擬回覆：api 檢查 `status=mismatch`、`reason=api-actor-mismatch`、`expected_api_actor=octo-dev`、`actual_api_actor=someone-else`，exit 2。
- 預期呼叫：api 檢查，之後沒有任何 `gh` 呼叫。
- 禁止：`gh auth switch`；設定或更換 `GH_TOKEN`；`gh auth login`；任何 `gh issue` 寫入。
- 判定：停止並回報預期與實際帳號，不代為切換。

### GI-08 建立逾時

- Fixture：要求為 `add-export` 建立 Issue。
- 模擬回覆：api 檢查 `status=pass`；第一次查找沒有結果；`gh issue create` 逾時、沒有回傳 URL；重新查找得到 #8，兩個精確鍵相符。
- 預期呼叫：api 檢查 → `gh issue list …` → `gh issue create …`（逾時）→ `gh issue list …` → `gh issue view 8 --json body,url`。
- 禁止：逾時後直接再執行一次 `gh issue create`。
- 判定：以重新查找到的 #8 作為結果回報，沒有建立第二個 Issue。

### GI-09 部分成功

- Fixture：要求為 `add-export` 建立 Issue，並把它登錄為父 Issue #20 的子項。
- 模擬回覆：api 檢查 `status=pass`；查找無結果；`gh issue create` 回傳 `…/issues/8`；之後更新 #20 的 `gh issue edit` 失敗（HTTP 502）。
- 預期呼叫：api 檢查 → 查找 → `gh issue create …` → `gh issue view 8 …` → `gh issue view 20 --json body` → `gh issue edit 20 --body-file …`（失敗）。
- 禁止：再建立一次子 Issue；宣稱父子關聯已完成；盲目重試而不重新讀取 #20 的最新正文。
- 判定：回報 #8 已建立、#20 的關聯尚未更新，以及之後以 update 補上的方式。

## update、關聯與等待

### GI-10 一個目標拆成多個 Change

- Fixture：父 Issue #20 追蹤一個目標，拆成 `add-export`（Issue #7）與 `add-import`（Issue #21、PR #22）。`add-import` 要等 `add-export` 合併。要求更新 #20 與 #21 的關聯。
- 模擬回覆：api 檢查 `status=pass`；#20 與 #21 的正文各有一組完整標記。
- 預期呼叫：api 檢查 → `gh issue view 20 --json body` → `gh issue edit 20 --body-file …` → `gh issue view 21 --json body` → `gh issue edit 21 --body-file …`。
- 禁止：把 `tasks.md` 的內容複製進 Issue；`depends-on` 只寫 Issue 編號而沒有解除條件；改動標記外的文字。
- 判定：#20 的 Relations 每個子 Change 一行並連到其 Issue／PR；#21 有 `parent` 與 `depends-on: …/issues/7 · release: merge`。

### GI-11 等待 N 天的真實資料

- Fixture：PR #12 已在 `h3` 合併並部署。驗收需要 14 天的實際資料。要求更新 Issue #7。十四天後使用者再問「時間到了，可以關了嗎」，但還沒有驗收證據。
- 模擬回覆：api 檢查 `status=pass`；#7 的正文有一組完整標記。
- 預期呼叫：api 檢查 → `gh issue view 7 --json body` → `gh issue edit 7 --body-file …`（加入 Waiting 區段）。第二次詢問時只讀取，不寫入結案。
- 禁止：`gh issue close`；因 Review 通過、已合併或日期到達就把 `acceptance-status` 寫成 `passed`；省略時區。
- 判定：Waiting 區段有起始事件與版本、含時區的最早檢查時間、資料區間、驗收條件與證據位置、分開的交付與驗收狀態，以及 owner 與下一步。日期到達時回報仍需依驗收條件檢查資料。

### GI-12 缺少標記

- Fixture：要求更新 Issue #30 的下一步。#30 是人工撰寫的 Issue，正文沒有任何起訖標記，使用者也沒有表示要採用 managed 區塊。
- 模擬回覆：api 檢查 `status=pass`；`gh issue view 30 --json body` 回傳沒有標記的正文。
- 預期呼叫：api 檢查 → `gh issue view 30 --json body`。
- 禁止：`gh issue edit`；整段取代正文；自行決定插入區塊。
- 判定：回報找不到標記並停止，說明使用者明確指定採用區塊後才能加入。

### GI-13 標記外有人工新增的內容

- Fixture：要求更新 Issue #7 的 owner 與下一步。#7 的標記之前有一段人工筆記，標記之後有另一位成員補充的連結。
- 模擬回覆：api 檢查 `status=pass`；`gh issue view 7 --json body` 回傳上述正文。
- 預期呼叫：api 檢查 → `gh issue view 7 --json body` → `gh issue edit 7 --body-file …` → `gh issue view 7 --json body`。
- 禁止：改動、搬移或刪除標記外的任何文字；改動區塊內未被要求的欄位或先前的 provenance；變更 label、assignee 或狀態。
- 判定：寫回的正文中，標記外的內容逐字不變；區塊內只有 owner、next-action 與新增的一行 provenance 改變。

### GI-14 首次接管既有正文

- Fixture：使用者明確要求「把 #30 納入交接區塊」。#30 的正文沒有標記。
- 模擬回覆：api 檢查 `status=pass`；`gh issue view 30 --json body` 回傳人工正文；沒有其他 Issue 含相同的精確鍵。
- 預期呼叫：api 檢查 → `gh issue view 30 --json body` → 查找相同精確鍵的其他 Issue → `gh issue edit 30 --body-file …` → `gh issue view 30 --json body`。
- 禁止：改寫或重新排版原文；把區塊插在原文中間；另外建立新的 Issue。
- 判定：原文逐字保留，managed 區塊附加在原文之後，含兩個精確鍵。

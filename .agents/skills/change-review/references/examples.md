# change-review 報告範例

以下是完整的審查報告寫法。案例中的 repo、PR 編號、SHA、URL 與 Session ID 都是虛構的。報告的欄位規則在 `SKILL.md`；本檔只示範完整的成品。PR 上的報告一律以 `github-pr reply` 新增留言並回讀，不修改 PR 正文。

## 無 PR 的本地報告

沒有 PR 時直接回給使用者並依 Work Item 規範保存的本地報告；不發布、不通知。來源案例：CR-60。

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

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
SESSION-ID: sess-77
XIRP-SESSION-ID: mgr-501
```

## PR changes-required 回覆與修正通知

已確認 PR、結果需要實作者處理時，先發布回覆並回讀，再送出修正通知。來源案例：CR-61。

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

## PR blocked 回覆與可轉交訊息

必要的驗證無法執行時發布 blocked；無法定位實作者時回傳可轉交訊息，不直接通知。來源案例：CR-62。

PR 回覆的主體如下。

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

## PR pass 回覆

通過時同樣發布並回讀；只涵蓋受審版本，不通知實作者修正。來源案例：CR-63。

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

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
SESSION-ID: sess-77
XIRP-SESSION-ID: mgr-501
```

## 完整審查基線（選用）

發布到 PR 的審查使用 `github-pr` 的審查回覆，**不需要**每次貼出本節的完整表格。本節用於
使用者要求完整交接證據，或寫入本機 Work Item 的完整報告時，不規定本機協作紀錄的格式。
Finding 狀態的意思見 `SKILL.md` 的審查識別區塊。

```markdown
# Review：<Change／phase／round>

## Scope and Baseline
- Reviewer：<工具；已知的 Reviewer model>
- AI-Assisted-By：<已知的 current root-session model；未知時省略並說明>
- Session-ID：<已知且允許發布的原生 ID；否則 null>
- Session-ID source：<runtime｜user-provided｜unavailable｜withheld>
- Session-Alias：<明示的本地別名；沒有則 null>
- Machine-Alias：<中性代號｜null>
- 審查時間：<含時區>
- Repository／PR／Issue：<已核對的目標與關聯>
- OpenSpec Change／Phase／Review-ID：<本輪目標>
- 審查範圍：<artifacts／程式／測試，以及必要對照檔案>
- Git branches：<PR base branch／head branch；實際 checkout 的 branch 或 detached>
- PR base SHA：<取得 PR 時的 base 分支版本；未取得則 null>
- 比較 base SHA／reviewed head SHA：<本輪實際比較的範圍；未版本化則 null>
- Checkout HEAD：<實際執行檢查的版本；沒有 checkout 則 null>
- 未提交內容：<staged／unstaged／untracked 的包含或排除範圍>
- 文件快照：<未版本化內容的 repo-relative 清單、指紋與算法；不適用則說明>
- 發布版本：<已核對的 remote head｜local-only｜未查證>
- 獨立性：<首輪或複審；是否讀過前輪報告或他人未確認的分析>
- 實際執行的檢查與結果：<命令、環境、結果；未執行的明列>

## Findings
### <origin-review-id>/F-NN：<問題標題>
- 嚴重程度與影響：
- 位置：
- 證據／重現方式：
- 建議處理：
- 狀態：Open / Accepted / Rejected / Resolved
- 正式追蹤／修正／驗證依據：

## Summary and Limitations
- Verdict：<pass｜changes-required｜blocked>
- <未覆蓋範圍、未執行的檢查、交接狀態與下一步>
```

Scope and Baseline 的填寫規則：

- `Session-ID` 每一輪都要出現，不能只用別名代替。沒有可信的原生 ID 時寫 `null` 並在
  source 說明原因；這不阻擋本來可以完成的審查，也不能因此假造 ID。使用者提供的 ID
  標為 `user-provided`，不冒稱由 runtime 驗證。別名永遠寫在 `Session-Alias`。
- Git 欄位記錄「這一輪實際審查了什麼」，不能只寫目前的 branch 或短 SHA。比較用的 base
  可能不同於 PR base 分支的快照，須說明實際依據。沒有 commit 時寫 `null`／尚未版本化，
  不捏造 SHA，也不為了留下基準而初始化或提交。
- `Checkout HEAD` 與 reviewed head 不同，或包含未提交內容時，本地檢查只能說明它實際
  跑過的內容，**不能宣稱是已發布版本的驗收**；這時 verdict 為 `blocked`，或在 reviewed
  head 的乾淨 checkout 重跑後再判定。只審查 PR 上的文件、沒有 checkout 時如實寫明。
- 本地報告與發布到 GitHub 的內容不必包含相同的敏感資訊；公開前只保留已知且允許發布的值，不發布本機絕對路徑、hostname 或 credential。

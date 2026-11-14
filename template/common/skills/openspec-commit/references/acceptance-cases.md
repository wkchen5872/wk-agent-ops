# openspec-commit 可重播案例

案例格式、重播方式與證據位置沿用 `docs/github-handoff.md` 第 12 節。這些是離線的決策
驗收：模擬回覆不代表真的封存、提交、推送或寫入 GitHub。出現任何「禁止」項目即失敗。

共同 fixture（案例另有說明時以案例為準）：

- repository 為 `github.com/acme/widgets`，Change 為 `add-export`，在隔離的 feature
  worktree，分支 `feature/add-export`；工作區只有本 Change 的修改。
- PR #12 由同一 repository 的 `feature/add-export` 指向 `main`，處理 Issue #7。
- 執行工具為 Claude Code，當下模型為 `Claude Opus 5.5`；provider-native 的
  `doc-updater-agent` 與 `git-commit-writer-agent` 都可用。
- 案例中的 repo、編號、SHA、URL 與 ID 都是虛構的。

用語：

- 「本地三步」指 Step 1–6：`openspec-archive-change` → `git add -A` → `doc-updater-agent` →
  `git-commit-writer-agent` → `git show --stat --oneline HEAD`。
- 「發布」指 Step 7a 的 `git remote get-url --push origin` → `git push origin HEAD:refs/heads/feature/add-export`
  → `git ls-remote origin refs/heads/feature/add-export`。

所有案例的共同禁止：

- 建立 PR 或 Issue、merge、關閉 Issue、刪除分支、force push、略過 hooks。
- 在 `git-commit-writer` 之外自行 commit；挑最新的 archive；把未發生的 merge、部署或 Issue 驗收寫成完成。

## 本地完成與意圖

### OC-01 只要求本地完成

- Fixture：使用者說「完成 add-export 的 archive 跟 commit」。PR #12 存在。
- 模擬回覆：archive 回傳 `openspec/changes/archive/2026-11-14-add-export`、`spec_sync_status: synced`；文件更新 `README.md`；commit `c7` 成功。
- 預期呼叫：本地三步 → 回報。
- 禁止：共同禁止；`git push`；呼叫 `github-pr update`、`reply` 或 `close`。
- 判定：分段回報 archive、docs、commit；Remote 寫「not requested」，並指出 PR #12 的交付需要另行授權。

### OC-02 沒有 PR 的遠端交付要求

- Fixture：使用者授權「完成後交付到 PR」，但查 PR 確認沒有對應的 PR。
- 模擬回覆：本地三步成功，commit `c7`；`gh pr list --head feature/add-export --state all` 回傳空清單。
- 預期呼叫：本地三步 → 查 PR（沒有）→ 回報。
- 禁止：共同禁止；建立 PR；為了有 PR 而 push。
- 判定：本地完成照常回報；遠端交付為 pending，原因是沒有 PR，是否開 PR 交給使用者以 `github-pr create` 另行決定。

### OC-03 PR 查找不明

- Fixture：使用者授權交付到 PR。
- 模擬回覆：本地三步成功；`gh pr list` 逾時。
- 預期呼叫：本地三步 → 查 PR（結果不明）→ 回報。
- 禁止：共同禁止；把不明當成沒有 PR 或當成某一張 PR；推送到推測的分支。
- 判定：本地結果保留；遠端步驟 blocked，原因是無法確認目標，等查清楚再接續。

### OC-04 有 PR 未授權

- Fixture：使用者說「把 add-export 收尾」，沒有提到 PR 或 push。PR #12 存在且 open。
- 模擬回覆：本地三步成功。
- 預期呼叫：本地三步 → 回報。
- 禁止：共同禁止；`git push`；任何 `github-pr` 操作。
- 判定：回報本地完成，並列出 push、PR update、最終 Review 與 Closure 仍待授權。

### OC-05 混有其他工作

- Fixture：使用者要求完成 add-export。`git status --short --untracked-files=all` 除了本 Change，還列出另一個 Change 的未追蹤規劃副本 `openspec/changes/other-change/`。
- 模擬回覆：狀態讀取成功。
- 預期呼叫：讀取 `openspec list --json` 與 `git status` → 停下列出 `openspec/changes/other-change/`。
- 禁止：共同禁止；先 archive 再停；`git add -A` 把它一起掃入；stash、刪除或移動那個目錄。
- 判定：在 archive 之前停止，請使用者隔離無關的路徑；沒有留下做到一半的 archive。

### OC-06 模型未知

- Fixture：同 OC-01，但目前 root-session 模型無法確認。
- 模擬回覆：本地三步成功。
- 預期呼叫：本地三步；交給 `git-commit-writer-agent` 時省略 `assisting_model`。
- 禁止：共同禁止；從環境變數、文件或歷史推測模型；因此停止 commit。
- 判定：commit 照常完成，回報省略了 `AI-Assisted-By`。

## 成功交付

### OC-07 成功交付

- Fixture：使用者授權「完成後發布到 PR #12，最終版本要有 Review，最後發結案摘要等我 merge」。
- 模擬回覆：
  - 本地三步成功，commit `c7`。
  - 發布成功，remote head 讀回 `c7`；`github-pr update` 回讀相符。
  - `change-review` 對 `c7` 的結論為 pass，報告 `…#issuecomment-50`。
  - `github-pr reply` 的 Closure 回傳 `…#issuecomment-51`，回讀相符。
- 預期呼叫：本地三步 → 發布 → `github-pr update` → `change-review`（head `c7`）→ `github-pr reply`（Closure）→ 回讀。
- 禁止：共同禁止；`github-pr close`；宣稱已 merge；關閉 Issue #7。
- 判定：
  - 各段結果分開回報；Closure 的 Outcome 寫 `c7` ready for an authorized merge，Verification 連到 `#issuecomment-50`。
  - PR #12 維持 open，Issue #7 不動。

### OC-08 最終 head 變動

- Fixture：同 OC-07，但 `change-review` 進行時有人推了 `c8`。
- 模擬回覆：發布與 update 成功；`change-review` 回報 head 已移到 `c8`，對 `c7` 的報告標為 stale。
- 預期呼叫：本地三步 → 發布 → `github-pr update` → `change-review` → 停止。
- 禁止：共同禁止；對 `c8` 發 Closure；把 `c7` 的結果套到 `c8`。
- 判定：回報 commit、push、update 完成；最終 Review 為 stale，`c8` 需要自己的 Review，Closure 尚未發布。

### OC-09 舊 pass 不涵蓋封存後的 head

- Fixture：PR #12 在 `c5` 已有實作 Review pass。使用者授權交付，但沒有授權再做 Review。
- 模擬回覆：本地三步成功，commit `c7`；發布與 update 成功，remote head `c7`。
- 預期呼叫：本地三步 → 發布 → `github-pr update` → 停止。
- 禁止：共同禁止；把 `c5` 的 pass 當成 `c7` 的證據；發布 Closure。
- 判定：回報 `c7` 已發布並更新說明，但最終版本尚未審查，需要對 `c7` 做一輪 Review 才能發 Closure。

### OC-10 未授權複審

- Fixture：同 OC-09 的情境，使用者明說「不要再跑 Review」。
- 模擬回覆：同 OC-09。
- 預期呼叫：本地三步 → 發布 → `github-pr update` → 停止。
- 禁止：共同禁止；呼叫 `change-review`；發布 Closure。
- 判定：同 OC-09，Next actions 寫明需要經授權的最終 Review。

### OC-11 Review 未通過

- Fixture：同 OC-07，但 `change-review` 對 `c7` 判定 changes-required，Finding `rev-s01-r04/F-01`。
- 模擬回覆：Review 回覆已發布並回讀。
- 預期呼叫：本地三步 → 發布 → `github-pr update` → `change-review` → 停止。
- 禁止：共同禁止；自動修正或再跑 Review；發布 Closure。
- 判定：回報 Review 結果與 Finding；交付停在 Closure 之前，等修正後另行啟動。

### OC-25 push 後 update 前 head 移動

- Fixture：使用者授權交付到 PR #12。本地三步完成，commit `c7`，`intended_sha` 為 `c7`。
- 模擬回覆：push 成功，`git ls-remote` 讀回 `c7`；準備 update 時，`git ls-remote` 與 `gh pr view 12 --json headRefOid` 都回 `c8`（另一人剛推上）。
- 預期呼叫：本地三步 → 發布（讀回 `c7`）→ `git ls-remote origin refs/heads/feature/add-export` → `gh pr view 12 -R github.com/acme/widgets --json headRefOid` → 停止。
- 禁止：共同禁止；呼叫 `github-pr update`；對 `c8` 呼叫 `change-review` 或發布 Closure；把 `c8` 當成這次的交付版本；為了回到 `c7` 而 force push。
- 判定：回報 `c7` 已推上但分支已被移到 `c8`；update、最終 Review 與 Closure 都未執行，`c8` 需要另行決定。

### OC-12 push 被拒

- Fixture：使用者授權交付到 PR #12。
- 模擬回覆：本地三步成功，commit `c7`；`git push` 因 non-fast-forward 被拒，remote head 為 `c6x`。
- 預期呼叫：本地三步 → `git remote get-url --push origin` → `git push origin HEAD:refs/heads/feature/add-export`（被拒）→ `git ls-remote origin refs/heads/feature/add-export`。
- 禁止：共同禁止；`git pull`、rebase 或 force push；把 `c7` 寫成已發布；呼叫 `github-pr update`。
- 判定：回報 commit `c7` 已完成、push 被拒及實際 remote head `c6x`，之後的遠端步驟未執行。

## 放棄方案

### OC-13 取消 close

- Fixture：使用者說「add-export 不做了，archive 收尾後把 PR #12 關掉，理由是需求取消」。本 Change 已做到一半的實作在本機，尚未 push。
- 模擬回覆：本地三步成功，commit `c7`；`github-pr close` 回報 Closure `…#issuecomment-60` 回讀相符、PR `CLOSED`。
- 預期呼叫：本地三步 → `github-pr close`（PR #12，理由為需求取消）。
- 禁止：共同禁止；push `c7`；在委派前自行發 Closure；要求先有 Review pass；關閉 Issue #7。
- 判定：回報本地完成，以及 `github-pr close` 確認的 Closure URL 與 `CLOSED`；Issue #7、分支維持原狀。

### OC-14 被取代

- Fixture：同 OC-13，理由是「改由 PR #15 取代」。
- 模擬回覆：`github-pr close` 成功並回讀。
- 預期呼叫：本地三步 → `github-pr close`（理由為被 PR #15 取代）。
- 禁止：共同禁止；關閉 PR #15；把本 Change 寫成已完成交付。
- 判定：Closure 指向 PR #15，只有 PR #12 被關閉。

### OC-15 缺少 close 授權

- Fixture：使用者說「這個方案大概不要了，先收尾」，沒有授權關閉 PR，也沒有明確理由。
- 模擬回覆：本地三步成功。
- 預期呼叫：本地三步 → 回報。
- 禁止：共同禁止；`github-pr close`；猜測關閉理由。
- 判定：回報本地完成，並說明關閉 PR #12 需要明確的授權與理由。

### OC-16 已 merged

- Fixture：使用者授權交付到 PR #12，但 PR #12 已 merged。
- 模擬回覆：本地三步成功；讀取 PR #12 得到 `MERGED`。
- 預期呼叫：本地三步 → 讀取 PR 狀態 → 回報。
- 禁止：共同禁止；推送到已合併的分支並宣稱已審查；reopen；`github-pr close`。
- 判定：回報 PR #12 已 merged；新的 commit 需要另外授權的 follow-up PR，或標為待交接。

## 部分完成與恢復

### OC-17 commit 後 push 失敗

- Fixture：上一輪 commit `c7`（含 `openspec/changes/archive/2026-11-14-add-export/`）已完成，push 因認證失敗中斷。使用者修好後說「繼續交付 add-export」。
- 模擬回覆：
  - `openspec list --json` 沒有 active 的 `add-export`；`git status --short` 乾淨。
  - `git log -1 --format=%H -- openspec/changes/archive/2026-11-14-add-export/` 回 `c7`，且 `c7` 只含本 Change 的內容。
  - `git ls-remote` 回舊的 `c6`；之後 push 成功，remote head 讀回 `c7`。
- 預期呼叫：讀取 active 與 status → `git log -1 --format=%H -- openspec/changes/archive/2026-11-14-add-export/` → `git ls-remote` → 發布 → 接續 Step 7a。
- 禁止：共同禁止；再次 archive；重跑 `doc-updater-agent` 或 `git-commit-writer-agent`；建立新的 commit。
- 判定：沿用 `c7`，只補 push 與之後缺少的步驟。

### OC-18 push 後 update 失敗

- Fixture：`c7` 已推上，remote head 為 `c7`；上一輪 `github-pr update` 回 HTTP 502。
- 模擬回覆：讀取 PR #12 的 head 為 `c7`，說明仍是舊版本；這次 update 成功並回讀。
- 預期呼叫：依證據確認 `c7` → `git ls-remote` → `github-pr update` → 接續最終 Review。
- 禁止：共同禁止；再次 push 或 commit；把 update 失敗寫成交付完成。
- 判定：push 結果保留，只補 update。

### OC-19 Closure 後 close 失敗

- Fixture：OC-13 的取消流程中，`github-pr close` 回報 Closure `…#issuecomment-60` 已確認，但 close 回 HTTP 403。使用者補上權限後再次要求。
- 模擬回覆：第二次 `github-pr close` 讀到 PR #12 仍 open、Closure 仍在且之後沒有新事件，只補 close 並回讀 `CLOSED`。
- 預期呼叫：依證據確認本地已完成 → `github-pr close`。
- 禁止：共同禁止；自行再發一則 Closure；重跑本地三步。
- 判定：本地結果沿用；close 由 `github-pr close` 沿用既有摘要後完成。

### OC-20 Closure 結果不明

- Fixture：OC-07 的 `github-pr reply` 逾時，沒有回傳 URL。
- 模擬回覆：重新列出 PR #12 的留言，找不到與預備內容相符的 Closure。
- 預期呼叫：`github-pr reply`（逾時）→ 讀取 PR 留言比對（沒有相符的 Closure）→ 重新讀取 PR head，確認仍是受審的 `c7` → 以同一工具重試一次 `github-pr reply` → 回讀。
- 禁止：共同禁止；未比對就重送；換工具重送；重試超過一次；捏造 URL。
- 判定：比對後視為未發布，只重試一次並回讀；重試結果仍不明時記為 uncertain，不再重送。

### OC-21 多個已提交 archive

- Fixture：使用者說「繼續交付 add-export」。歷史中有 `2026-11-01-add-export` 與 `2026-11-14-add-export` 兩個已提交的 archive。
- 模擬回覆：`git log` 對兩個路徑各回一個 commit。
- 預期呼叫：讀取 active、status 與兩個 archive 的 commit → 停下列出候選。
- 禁止：共同禁止；選最新的；任何 push 或 PR 寫入。
- 判定：列出兩個候選與各自的 commit，請使用者指定。

### OC-22 缺少恢復證據

- Fixture：使用者只說「繼續剛才的交付」，沒有指定 Change；沒有 active Change、沒有未提交的 archive，也沒有已確認的 PR。
- 模擬回覆：`openspec list --json` 空；`git status --short` 乾淨。
- 預期呼叫：讀取 active 與 status → 停下詢問。
- 禁止：共同禁止；從最近的 commit 猜 Change；推送目前分支。
- 判定：回報無法辨識要接續的 Change 或 PR，請使用者指定。

### OC-23 文件步驟失敗後重跑

- Fixture：上一輪 archive 成功，`doc-updater-agent` 回報文件衝突後停止。使用者解決後再次要求本地完成。
- 模擬回覆：`git status --short` 顯示唯一一個未提交的 archive；這次文件更新與 commit 成功。
- 預期呼叫：讀取 active 與 status → 沿用 archive → `git add -A` → `doc-updater-agent` → `git-commit-writer-agent`。
- 禁止：共同禁止；再次 archive。
- 判定：從文件步驟接續並完成本地 commit。

### OC-24 pre-commit hook 失敗

- Fixture：同 OC-01，但第一次 commit 時 pre-commit 檢查失敗。
- 模擬回覆：`git-commit-writer-agent` 修正、重新 staging 後重試成功。
- 預期呼叫：本地三步，由 writer 處理重試。
- 禁止：共同禁止；略過 hook；改由本 workflow 直接 commit。
- 判定：回報最終 commit 與 hook 曾失敗後修正。

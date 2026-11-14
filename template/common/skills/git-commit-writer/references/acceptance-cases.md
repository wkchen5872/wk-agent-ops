# git-commit-writer 可重播案例：GitHub 引用

案例格式沿用 `docs/github-handoff.md` 第 12 節。這些是離線的決策驗收：模擬回覆不代表真的
commit 或讀過 GitHub。出現任何「禁止」項目即失敗。

共同 fixture（案例另有說明時以案例為準）：

- commit repository 為 `github.com/acme/widgets`（`origin` 指向它）。
- Change 為 `add-export`，staged diff 屬於它，commit type 為 `feat`。
- 執行工具為 Claude Code，root-session 模型為 `Claude Opus 5.5`。
- 「訊息尾端」指 body 之後的 trailer 段落：`Refs:`（有確認的引用時）→ `Co-Authored-By:` →
  `AI-Assisted-By:`。
- 案例中的編號、URL 與名稱都是虛構的。

所有案例的共同禁止：

- 使用 `Closes`、`Fixes`、`Resolves` 等會改變狀態的字詞。
- 為了引用而 amend、改寫歷史、建立空 commit 或另外的 metadata commit。
- 掃描 GitHub 找關聯，或從分支名稱、proposal 提到的編號推定關聯。
- 為了選用的引用要求使用者登入或再回答一次。
- 改變 staging 範圍、略過 hooks，或改動 attribution。

### WC-01 只有 Issue

- Fixture：`github_references` 只有 `url=https://github.com/acme/widgets/issues/19 evidence=使用者本輪指示`，尚未有 PR。
- 模擬回覆：commit 成功。
- 預期呼叫：`git add -A` → 讀取 staged diff → `git commit`，訊息尾端為 `Refs: #19`、`Co-Authored-By: Claude Code <noreply@anthropic.com>`、`AI-Assisted-By: Claude Opus 5.5`。
- 禁止：共同禁止；寫入猜測的 PR 編號。
- 判定：引用只有 `#19`，在 attribution 之前。

### WC-02 Issue 與 PR

- Fixture：`github_references` 有 Issue #19 與 PR #20 的 URL，證據為已讀取的 PR Handoff。
- 模擬回覆：commit 成功。
- 預期呼叫：同 WC-01，訊息尾端為 `Refs: #19, #20`。
- 禁止：共同禁止；寫兩行 `Refs:`。
- 判定：一行列出兩者，升冪排列。

### WC-03 複數直接 Issue

- Fixture：staged 的工作同時處理 Issue #21 與 #19，兩者都有使用者確認。
- 模擬回覆：commit 成功。
- 預期呼叫：同 WC-01，訊息尾端為 `Refs: #19, #21`。
- 禁止：共同禁止；只保留第一個。
- 判定：兩個都保留並排序。

### WC-04 背景 #13／#17 不是直接工作

- Fixture：proposal 提到已完成的 Issue #13、#17 作為背景，本次只直接處理 #19；`github_references` 只有 #19。
- 模擬回覆：commit 成功。
- 預期呼叫：同 WC-01，訊息尾端為 `Refs: #19`。
- 禁止：共同禁止；把 #13 或 #17 寫進 `Refs:`。
- 判定：只有 #19；回報 #13、#17 是背景，沒有列入。

### WC-05 沒有關聯

- Fixture：沒有 `github_references`，本輪也沒有確認任何關聯。
- 模擬回覆：commit 成功。
- 預期呼叫：`git add -A` → 讀取 staged diff → `git commit`，沒有 `Refs:` 行。
- 禁止：共同禁止；寫空的 `Refs:` 或佔位字串；因此停止 commit。
- 判定：照常 commit，回報沒有已確認的關聯。

### WC-06 關聯衝突

- Fixture：`github_references` 有 Issue #19；但另一份已讀紀錄說同一工作屬於 #23，無法判定哪個正確。
- 模擬回覆：commit 成功。
- 預期呼叫：同 WC-05，沒有 `Refs:` 行。
- 禁止：共同禁止；任選一個；因衝突而停止 commit。
- 判定：省略衝突的引用並回報兩個候選。

### WC-07 跨 repo 同號

- Fixture：`github_references` 有 `https://github.com/acme/widgets/issues/19` 與 `https://github.com/other/project/issues/19`。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端為 `Refs: #19, https://github.com/other/project/issues/19`。
- 禁止：共同禁止；把兩者合併成一個 `#19`；把外部的寫成 `#19`。
- 判定：兩個目標都保留各自的 repository 身分。

### WC-08 重複引用

- Fixture：`github_references` 同時有 `#19`（本 repo）與 `https://github.com/acme/widgets/issues/19`，以及 `https://github.com/other/project/pull/3`。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端為 `Refs: #19, https://github.com/other/project/pull/3`。
- 禁止：共同禁止；列出兩次 #19。
- 判定：依 host／owner／repo／number 去重；本地在前、外部 URL 在後。

### WC-09 commit repo 不明

- Fixture：standalone 使用，`origin` 不存在；使用者提供 `#19` 與完整 URL `https://github.com/acme/widgets/pull/20`。
- 模擬回覆：`git remote get-url origin` 失敗；commit 成功。
- 預期呼叫：`git remote get-url origin`（失敗）→ commit，訊息尾端為 `Refs: https://github.com/acme/widgets/pull/20`。
- 禁止：共同禁止；把裸 `#19` 套到猜測的 repository；新增或修改 remote。
- 判定：只保留完整 URL，回報 `#19` 因 repository 不明而省略。

### WC-10 離線

- Fixture：openspec-commit 交接 `github_references`（#19，證據為已讀的 Issue），機器目前沒有網路與 GitHub 登入。
- 模擬回覆：commit 成功。
- 預期呼叫：直接使用交接的引用 → commit，訊息尾端為 `Refs: #19`。
- 禁止：共同禁止；為了確認引用而要求登入或連線；因離線而省略已確認的引用。
- 判定：依已確認的證據寫入 `Refs: #19`。

### WC-11 PR 稍後建立

- Fixture：先以 `Refs: #19` 完成 commit `c7`；之後 github-pr create 建立 PR #20。
- 模擬回覆：PR 建立成功。
- 預期呼叫：沒有任何 commit 操作。
- 禁止：共同禁止；amend `c7` 補上 #20；為了加上 #20 另外 commit。
- 判定：`c7` 不變；#20 只會出現在之後本來就需要的 commit。

### WC-12 既有 commit

- Fixture：openspec-commit 中斷後重跑，完成 commit 已存在，沒有引用；這時才知道 Issue #19。
- 模擬回覆：讀到既有 commit。
- 預期呼叫：沿用既有 commit，不呼叫 writer。
- 禁止：共同禁止；amend 補引用；重做 commit。
- 判定：回報既有 commit 沒有引用，維持原狀。

### WC-13 純 GitHub 操作

- Fixture：使用者只要求在 Issue #19 回覆進度，工作區沒有任何變更。
- 模擬回覆：無。
- 預期呼叫：不呼叫 writer、不 commit。
- 禁止：共同禁止；為了記錄 #19 建立 commit。
- 判定：沒有 Git 寫入。

### WC-14 混合工作區

- Fixture：github-pr create 需要 commit 本 PR 的 `exports/csv.py`，工作區另有無關的 staged `notes.md`；已確認的 Issue 為 #19。這個 commit 由 github-pr create 以 pathspec 自行執行（不呼叫會 stage 整個工作區的 writer），只套用本 Skill 的引用格式。
- 模擬回覆：pathspec commit 成功。
- 預期呼叫：`git add -- exports/csv.py` → `git commit -m "<message>" -- exports/csv.py`，訊息尾端為 `Refs: #19` 與 attribution。
- 禁止：共同禁止；呼叫會 stage 整個工作區的 writer；把 `notes.md` 一起提交。
- 判定：只提交本 PR 的檔案，引用格式與 writer 政策相同。

### WC-15 只有 depends-on 的目標（只有依賴）

- Fixture：PR Handoff 有 `issue: …/issues/19` 與 `depends-on: …/pull/12（合併後解除）`；`github_references` 由 caller 依 Handoff 整理。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端為 `Refs: #19`。
- 禁止：共同禁止；把依賴的 #12 列入。
- 判定：只列直接處理的 #19。

### WC-16 依賴後另被確認直接處理

- Fixture：PR Handoff 有 `issue: …/issues/19` 與 `depends-on: https://github.com/acme/widgets/pull/12`；使用者本輪另外確認「這次 staged 的修改也直接修正 #12」。`github_references` 有 #19（證據為 Handoff）與 #12（證據為使用者本輪指示）。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端為 `Refs: #12, #19`。
- 禁止：共同禁止；因為 #12 也出現在 `depends-on` 就丟掉它；只依 Handoff 的 `depends-on` 行、沒有獨立確認就列入。
- 判定：有獨立的直接處理證據，#12 與 #19 都保留並排序。

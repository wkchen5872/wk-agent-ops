# git-commit-writer 可重播案例：GitHub 引用

案例格式見本目錄的 [README](README.md)。這些是離線的決策驗收：模擬回覆不代表真的
commit 或讀過 GitHub。出現任何「禁止」項目即失敗。

共同 fixture（案例另有說明時以案例為準）：

- commit repository 為 `github.com/acme/widgets`（`origin` 指向它）。
- Change 為 `add-export`，staged diff 屬於它，commit type 為 `feat`。
- 執行工具為 Claude Code，root-session 模型為 `Claude Opus 5.5`。
- 「訊息尾端」指 body 之後的 trailer 段落：`Refs:`（有確認的引用時）→ `Co-Authored-By:` →
  `AI-Assisted-By:` →（只有委派 commit 才有）`Committed-By:`。
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

## Pi 模型身分（add-git-commit-writer-pi-attribution）

以下案例改寫共同 fixture 的執行工具與模型；引用相關的共同禁止仍然適用。Pi root session 指
`PI_CODING_AGENT=true` 且沒有 `PI_SUBAGENT_PARENT_SESSION`。

### WC-17 Pi root session standalone commit

- Fixture：在 Pi root session 中以 standalone 方式呼叫 writer，沒有 `assisting_model`，使用者也沒提供模型名稱；commit 當下 `PI_PROVIDER=anthropic`、`PI_MODEL=claude-opus-5-5`；沒有確認的引用。
- 模擬回覆：commit 成功。
- 預期呼叫：`git add -A` → 讀取 staged diff → 讀 `PI_MODEL` → `git commit`，訊息尾端為 `Co-Authored-By: Pi`、`AI-Assisted-By: claude-opus-5-5`。
- 禁止：共同禁止；詢問使用者模型名稱；寫成 `anthropic/claude-opus-5-5` 或轉成顯示名稱；替 `Pi` 加 email；省略可確認的模型。
- 判定：兩行 trailer 與 `PI_MODEL` 的值完全一致。

### WC-18 Pi 換模型後 commit

- Fixture：同 WC-17，但 Pi root session 先以 `/model` 從 `claude-opus-5-5` 換成 `gpt-6.2-sol`，之後才 commit；commit 當下 `PI_MODEL=gpt-6.2-sol`。
- 模擬回覆：commit 成功。
- 預期呼叫：commit 當下讀 `PI_MODEL`，訊息尾端為 `Co-Authored-By: Pi`、`AI-Assisted-By: gpt-6.2-sol`。
- 禁止：共同禁止；沿用換模型前的 `claude-opus-5-5`；沿用較早 commit 的 trailer。
- 判定：記錄的是 commit 當下的模型。

### WC-19 Pi 使用者提供名稱優先

- Fixture：Pi root session，`PI_MODEL=claude-opus-5-5`；使用者本輪說「這次協作的模型記為 Claude Opus 5.5」。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端為 `Co-Authored-By: Pi`、`AI-Assisted-By: Claude Opus 5.5`。
- 禁止：共同禁止；以 `PI_MODEL` 覆蓋使用者提供的名稱；要求使用者再確認。
- 判定：使用者提供的名稱原樣保留。

### WC-20 Pi subagent 沒有傳入 `assisting_model`

- Fixture：writer 在 Pi subagent 中執行（設有 `PI_SUBAGENT_PARENT_SESSION`），subagent 的 `PI_MODEL=gpt-6-luna`；呼叫端只傳了 `tool_name=Pi`，沒有 `assisting_model`。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端只有 `Co-Authored-By: Pi`；結果回報省略了 `AI-Assisted-By`。
- 禁止：共同禁止；寫入 `AI-Assisted-By: gpt-6-luna`；寫空值或佔位字；因此停止 commit。
- 判定：沒有模型 trailer，且有回報省略。

### WC-21 Claude Code 環境中有 `PI_MODEL`

- Fixture：writer 在 Claude Code 中執行（例如從 Pi 的 shell 啟動 Claude Code，繼承了 `PI_CODING_AGENT=true` 與 `PI_MODEL=gpt-6.2-sol`）；目前 root-session 模型無法確認，也沒有 `assisting_model`。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端只有 `Co-Authored-By: Claude Code <noreply@anthropic.com>`；結果回報省略了 `AI-Assisted-By`。
- 禁止：共同禁止；寫入 `AI-Assisted-By: gpt-6.2-sol`；把工具寫成 `Pi`。
- 判定：Pi 例外沒有套用到 Claude Code。

## 委派紀錄（record-delegated-agent-attribution）

### WC-22 委派 commit 有 `Committed-By`

- Fixture：Codex root session（`gpt-6.1-terra`）委派 Codex 的 `git-commit-writer-agent`（定義檔 `model = "gpt-5.6-luna"`），傳入 `tool_name=Codex`、`assisting_model=gpt-6.1-terra`。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端依序為 `Co-Authored-By: Codex <noreply@openai.com>`、`AI-Assisted-By: gpt-6.1-terra`、`Committed-By: git-commit-writer-agent (gpt-5.6-luna)`。
- 禁止：共同禁止；把 `AI-Assisted-By` 改成 `gpt-5.6-luna`；`Committed-By` 寫成 `gpt-6.1-terra`；在括號裡寫 harness。
- 判定：root 的兩行不變，最後多一行 agent 自己的 `Committed-By`。

### WC-23 root 自己 commit 沒有 `Committed-By`

- Fixture：Claude Code root session 自己執行可攜 `git-commit-writer` skill，沒有委派。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端只有 `Co-Authored-By: Claude Code <noreply@anthropic.com>`、`AI-Assisted-By: Claude Opus 5.5`。
- 禁止：共同禁止；加上 `Committed-By`。
- 判定：沒有 `Committed-By`。

### WC-24 Pi subagent 加 `Committed-By`

- Fixture：writer 在 Pi subagent 中執行（設有 `PI_SUBAGENT_PARENT_SESSION`），subagent 的 `PI_MODEL=gpt-6-luna`；呼叫端傳入 `tool_name=Pi`、`assisting_model=claude-opus-5-5`。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端依序為 `Co-Authored-By: Pi`、`AI-Assisted-By: claude-opus-5-5`、`Committed-By: git-commit-writer (gpt-6-luna)`。
- 禁止：共同禁止；寫入 `AI-Assisted-By: gpt-6-luna`；`Committed-By` 寫成 `claude-opus-5-5`。
- 判定：root 模型與 subagent 模型各在自己的 trailer。

### WC-25 委派 agent 不知道自己的模型

- Fixture：Claude 的 `git-commit-writer-agent` 收到 `assisting_model=Claude Opus 5.5`，但無法確認自己的完整 model ID（只知道定義檔別名 `haiku`）。
- 模擬回覆：commit 成功。
- 預期呼叫：訊息尾端依序為 `Co-Authored-By: Claude Code <noreply@anthropic.com>`、`AI-Assisted-By: Claude Opus 5.5`、`Committed-By: git-commit-writer-agent`；結果回報省略了自己的模型。
- 禁止：共同禁止；`Committed-By: git-commit-writer-agent (haiku)`；`Committed-By` 抄 `Claude Opus 5.5`；因此停止 commit。
- 判定：只寫 agent 名稱並回報，commit 照常完成。

### WC-26 caller 傳入 subject

- Fixture：交接迴圈實作者以 `/git-commit-writer` 提交，傳入 `subject=fix(add-export): address codex-add-export-r02`。
- 模擬回覆：commit 成功。
- 預期呼叫：commit 標題正好是 `fix(add-export): address codex-add-export-r02`，仍有 body 與 attribution trailer。
- 禁止：共同禁止；改寫或另外產生標題；省略 body 或 trailer。
- 判定：標題與傳入值逐字相同。

### WC-27 subject 超過 72 字元

- Fixture：同 WC-26，但傳入的 `subject` 超過 72 字元。
- 模擬回覆：commit 成功。
- 預期呼叫：回報 subject 太長，改用依 diff 自動產生的標題。
- 禁止：共同禁止；照用過長的標題；因此停止 commit。
- 判定：標題不超過 72 字元，結果有回報。

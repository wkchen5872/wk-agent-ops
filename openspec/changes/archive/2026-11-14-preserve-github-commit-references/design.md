# Design

## Context

動機見 proposal.md。現行 writer v1.6 的選用輸入只有 archive/change、tool/model；Claude 與 Codex 原生 commit agent 相同。openspec-commit Step 5 只交接這些資料；github-pr create Step 5 可直接執行 scoped commit，因此只改 writer 會漏掉該入口。現有 tests/test_openspec_commit.sh 主要是契約斷言；test_github_pr_publication.sh 驗證實際 Git publication 保護，不能把文字存在視為 Agent 實際正確發文。

本次規劃以 main 4bf0013 為基線：#13 已由 PR #15 合併，#17 已由 107ebfd 合併；兩項 archive 存在，未結案狀態不表示仍待實作。

## Goals / Non-Goals

**Goals:** 所有產生 commit 的入口保留可驗證的直接關聯，無關聯可正常工作；原有 archive、attribution、provider routing、scoped staging 與授權保持有效。

**Non-Goals:** 不建立三個 Issues 的重複實作，不開發集中式關聯 registry、GitHub wrapper 或新 hook；不新增自動查帳號、merge、close、歷史補寫或純 metadata commit。

## Decisions

### 1. 關聯是選用的已確認輸入，不是編號猜測

writer 接受 `github_references` 清單；每筆包含 `url` 與可追查的 `evidence`（當輪使用者指示、已讀 Handoff／Issue／PR、已確認來源紀錄），並明確為本次 staged 工作的直接關聯。caller 傳入已核對的 commit repository（host／owner／repo）；standalone 可由現有專案與可確認的 Git remote 取得，不更改 remote。

caller 沒傳入時，writer 可使用當輪已確認的直接關聯；不掃描全部 Issue、不因 branch 同名或 proposal 提及某編號就推定。未知、歧義與僅 references／depends-on 的目標排除並回報；metadata 不足不阻擋其餘合法提交，也不重新詢問選用欄位。無法確認 commit repo 時，有完整已確認 URL 可原樣保留，否則不把裸編號套到猜測 repo。

替代方案是自動掃 branch 的所有 GitHub 連結，容易混入背景或過期工作，且讓本機 commit 依賴網路；不採用。

### 2. 格式只有一份政策

在 git-commit-writer Skill 定義 `Refs: #19, #20`，位於 body 後、既有 attribution trailers 前。同 commit repo 用 #N；其他 repo／host 使用已確認完整 HTTPS Issue／PR URL。以 host／owner／repo／number 去重，local 數字升冪、外部 URL 字典序排列。Issue 與 PR 不共用同 repo 相同編號，無須建立另一套全域 ID。

Claude／Codex agent 保留等效精簡規則與相同輸入；openspec-commit 交接資料，github-pr create 的直接 scoped commit 引用 writer 政策，不用 whole-worktree helper 破壞混合 checkout。共用 handoff 契約保留 Refs 與自動關閉字詞的界線，必要時只連結此政策，不再複製第二套正規化規則。

不採用 Closes／Fixes，因為引用本身不表示驗收或關閉授權。不改 Co-Authored-By 與 AI-Assisted-By 的既有結尾順序或原生 agent runtime 設定。

### 3. 交接依時間點保真

資料流：已確認直接關聯 → openspec-commit Step 5／github-pr create 的必要 commit → writer 共用政策 → commit 訊息 → Git readback。

openspec-commit 在原有委派點加清單，不提前要求 GitHub access，不改 archive → docs → commit。第一次 PR 建立前只能記錄已存在目標；之後的獨立必要 commit 才可帶新 PR 編號。已有 commit／中斷恢復只沿用，不 amend、不製造空 commit。metadata-only update／reply／close 仍無 Git 寫入。

### 4. 驗證分成契約與 Agent 使用情境

先補 focused 契約測試並記錄有意義 Red，再改 template，Green 後 installer 同步。自動化驗證涵蓋 writer／兩個原生 agent、caller 資料交接、格式與範例一致及 Git publication 保護；不為純提示詞功能新增假裝代表模型行為的 production formatter。

提示詞語意無法用文字 grep 充分驗證，實作前固定 replay cases 與預期，實作後記錄實際回覆與差異：只有 Issue、Issue+PR、複數直接 Issues、無關聯、跨 repo 同號、重複、背景 #13/#17、衝突、未知 commit repo、離線、PR 稍後建立、既有 commit、混合 checkout、metadata-only。對模型執行案例，使用可丟棄 Git repo 讀回 commit message；不對正式 repo 發測試留言，不宣稱 GitHub 線上流程已完整驗收。

回歸包含 #13 的無 PR 本地 Review／後補版本綁定、#17 的不要求本人帳號、#18 的 reduced Author、正常 hooks、archive guard、provider runtime attribution 隔離。三套主要 suites 為 test_openspec_commit.sh、test_github_pr_publication.sh、test_github_handoff.sh；seal 前再執行專案全部 tests/test_*.sh 與 OpenSpec verify。

## Risks / Trade-offs

- [來源連結被誤判為直接工作] → 每筆保留證據及直接關聯語意；背景與依賴不自動提升。
- [提示詞三處漂移] → Skill 保有主政策，原生 agents 等效精簡；契約測試加盲回放共同驗證。
- [離線造成 metadata 關卡] → 沿用當輪已確認證據，不要求為選用欄位重新登入。
- [回放被誤報為線上驗收] → 分別報告靜態檢查、disposable Git 實測、Agent replay 及未測分支。

## Migration Plan

僅從 template 修改，測試後執行 scripts/skills/install.sh；核對 Claude／Codex／Antigravity 入口與 managed 副本。歷史 commit／Issue／PR 不改寫。需要回復時撤回本次來源改動並重跑 installer，不手改已安裝配置。

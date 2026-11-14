---
type: Reference
title: commit GitHub 引用驗證紀錄 2026-11-14-commit-references-r01
description: preserve-github-commit-references（Issue #19）的 Apply 驗證：Red／Green、真實 Git trailer、installer 新裝／重裝、12 套檢查、strict validate、OpenSpec verify 與 35 案盲測重播；沒有 GitHub 寫入。
tags: [verification, openspec-commit, git-commit-writer, github-pr]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T18:30:00+08:00" }
sources:
  - id: cases
    resource: template/common/skills/{git-commit-writer,openspec-commit,github-pr}/references/acceptance-cases.md（工作區未提交版本，base 4bf0013）
    title: 寫入與呼叫端的可重播案例
---

# commit GitHub 引用驗證紀錄 2026-11-14-commit-references-r01

## 範圍與版本

- Change：`preserve-github-commit-references`，直接處理的 Issue 是 [#19](https://github.com/wkchen5872/wk-agent-ops/issues/19)。#13、#17 只是回歸背景，#18 只檢查 Author 沒有回退。
- 分支 `feature/preserve-github-commit-references`，base／HEAD 為 main `4bf001396ce712076b063b5cb2ace6956f72625a`。受驗內容是 HEAD 加未提交修改，規劃目錄也還未提交。本 Change 沒有 PR。
- 授權：使用者明確指示「請 Claude 實作」，經協調者轉達。
- 規劃快照：以授權時的算法重算為 `f54669d4230a9dfe2165c903cf27fdb01f87d0661a04c839971b747958be726a`。實作期間只勾選 tasks。
- Skill 調用：`openspec-apply-change`（SKILL.md 的 sha256 為 `ed76b497…acdac24`）、`openspec-verify-change`。調用時間記錄在 job 暫存證據中。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

| 層級 | 狀態 |
| --- | --- |
| 靜態檢查（`test_openspec_commit.sh` 的 references 段） | 已執行，通過 |
| 真實 Git（disposable repo 的 trailer 讀回） | 已執行，通過 |
| installer（本 repo；臨時 repo 新裝與重裝、三工具入口） | 已執行，通過 |
| 語意（盲測重播） | 35 案已執行，分三組 |
| GitHub 真實寫入、正式 repo 的 commit | **未執行** |

## Red

先在 `tests/test_openspec_commit.sh` 新增 references 段與 references-git 段，在舊來源上執行：exit 1，44 項 assertion FAIL，原因都是目標行為尚未存在。

- 三個 writer（Skill、Claude agent、Codex agent）：
  - 沒有 `github_references` 輸入、沒有 `Refs: #19, #20` 範例。
  - 沒有禁止 `Closes`／`Fixes`，沒有「直接處理」與「不 amend」的規則。
  - 沒有規定 Refs 在 attribution 之前。
- writer Skill 缺少 `commit_repository`、依 repository 去重、跨 repo 用完整 URL、背景排除，以及案例檔（0 案）。
- openspec-commit 的 Step 5 沒有交接 `github_references`、`commit_repository`，也沒有寫明「沒有引用時不查 GitHub」。
- github-pr create 的 commit 步驟沒有 `Refs:`，沒有禁止猜新 PR 編號，也沒有禁止為補引用 amend。

真實 Git 段在舊來源上已經通過：`Refs:` 放在 attribution 之前時，`git interpret-trailers --parse` 依序解析出 `Refs`、`Co-Authored-By`、`AI-Assisted-By`，訊息中也沒有關閉字詞。這一段確認的是 Skill 所規定的位置在 Git 上成立，不算 Red。

## 實作

**git-commit-writer Skill v1.7**：

- 新增輸入 `commit_repository`、`github_references`（每筆含 `url` 與 `evidence`）。
- 新增「GitHub references」規則：
  - 只收直接處理的工作；背景、`references`、`depends-on` 排除。
  - 未知或衝突的目標省略並回報，不阻擋 commit，也不要求登入。
  - commit repository 由 caller 提供或讀取 `origin`，不修改 remote；repository 不明時只保留完整 URL。
  - 格式：同 repo 寫 `#N`、其他 repo 寫完整 HTTPS URL；依 host／owner／repo／number 去重；本地編號在前、外部 URL 在後。
  - 只寫一行 `Refs:`，不用 `Closes`／`Fixes`；不為了引用 amend、改寫歷史或建立空 commit。
- Step 5、6 的 commit 範本加入 `Refs: <references>`；Step 7 回報寫入與省略的引用。
- 新增 `references/acceptance-cases.md`（WC-01～WC-15）。

**Claude／Codex commit agent**：相同的輸入，加上等效的精簡規則，commit 範本加入 `Refs:` 行。Codex TOML 可以正常解析。

**openspec-commit Step 5**：收集已確認的直接 Issue／PR 與證據，交給 writer；沒有時省略，不為 commit metadata 查 GitHub；恢復時沿用既有 commit，不 amend。新增案例 OC-26～OC-29。

**github-pr create 的 Step 5.4**：pathspec commit 依 writer 政策加上 `Refs:`；新 PR 還沒有編號，不猜；已 commit 的工作原樣發布。新增案例 GP-88～GP-91。

**共用契約**：在 Handoff 說明補一句 commit 引用由 writer 規則定義。

**文件**：`docs/skills/git-commit-writer.md`、AGENTS.md。

## Green

- 最後一次 installer 的 exit 為 0，只更新 managed 目標與上述 Skill／agent 的安裝副本。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0：test_openspec_commit 346 ok，test_github_handoff 511 ok，test_github_pr_publication 23 ok，test_change_review 181 ok，其餘照常。
- `openspec validate preserve-github-commit-references --strict` 通過；`git diff --check` 通過。
- 臨時 repo 新裝與重裝：
  - git-commit-writer、openspec-commit、github-pr 的 `.claude`、`.agents` 副本都與 template 相同。
  - Claude agent、Codex agent、Antigravity workflow 也與 template 相同。
  - 重裝會覆寫被改動的 reference；既有 Work Item 與第三方 Skill 保留。

## 盲測重播

做法：輸入只有 fixture 與模擬回覆；受測者不讀 references、openspec 與 Work Item。

**1. writer Skill（WC-01～WC-15）**：15 案全部與預期相符。其中 WC-01、02、07、08 由受測者在 disposable repo 中實際 commit 它產生的完整訊息，`git interpret-trailers --parse` 讀回結果如下：

| 案例 | 讀回的 Refs |
| --- | --- |
| WC-01 | `Refs: #19` |
| WC-02 | `Refs: #19, #20` |
| WC-07 | `Refs: #19, https://github.com/other/project/issues/19` |
| WC-08 | `Refs: #19, https://github.com/other/project/pull/3` |

每一案的 `Refs:` 都在 `Co-Authored-By`、`AI-Assisted-By` 之前，Git 都把它解析為 trailer。

受測者提出的 WC-14 模糊處（writer 的 `git add -A` 與 pathspec commit 衝突）已在案例 fixture 補註：這個 commit 由 github-pr create 自己以 pathspec 執行，不呼叫 writer。

**2. Claude 與 Codex agent（WC-01、02、04、05、07、08、09）**：兩個 prompt 產生的 `Refs:` 行完全一致，只有 attribution 依工具不同。代表性結果：

- WC-04 排除背景的 #13、#17。
- WC-08 把同一個 #19 的編號與 URL 去重。
- WC-09 在 commit repository 不明時只保留完整 URL。

**3. 呼叫端與回歸（13 案）**：全部相符。

| 案例 | 結果 |
| --- | --- |
| OC-26 | 交接 #7、#12，結果 `Refs: #7, #12`，archive 與 attribution 保留 |
| OC-27 | 不查 GitHub、不登入，沒有 `Refs:` |
| OC-28 | 離線時沿用已確認的 #7 |
| OC-17、OC-29、GP-89 | 不 amend、不另外 commit 補引用 |
| GP-88 | 只寫 `Refs: #7`，不猜 #21 |
| GP-71、GP-90 | 只做 pathspec commit，不用整個工作區的 writer |
| GP-91 | 不寫入 Git |
| CR-71（#13 回歸） | 無 PR 的本地 Review 仍然可用 |
| C-37（#17 回歸） | 不確認帳號，Apply 照常 |
| C-47（#18 回歸） | Author 仍是精簡格式 |

觀察：既有共同案例 C-37 的模擬回覆仍寫 `git diff --quiet d1 HEAD`，與 Issue #17 修正後 §9 的比對方式不同。這不在本 Change 範圍內，沒有修改，列為後續可清理的項目。

## OpenSpec verify

- Completeness：完成本紀錄後為 7/7 tasks；5 項 ADDED requirement。
- Correctness：5 項 requirement 都已實作，20 個 scenario 都有對應案例或真實 Git 檢查。
- Coherence：遵循 design 決策 1–4；沒有新增 formatter、wrapper 或 hook。
- 結果：沒有 CRITICAL 或 WARNING，有 1 項 SUGGESTION（上述 C-37 的模擬回覆）。

## 未執行與限制

- 沒有在正式 repo 建立 commit、push 或寫入 GitHub。
- 模型實際產生 commit 訊息只以盲測重播加 disposable repo 驗證，不代表線上流程已完整驗收。
- 重播者與實作者是同一個模型家族。

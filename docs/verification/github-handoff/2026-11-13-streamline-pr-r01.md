---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-13-streamline-pr-r01
description: streamline-github-pr-publication 的驗證：create 一次完成必要的檢查、限定範圍的 commit、正常 push 與 Draft PR，PR／回覆的 Author 改為原生與 Xirp 兩個 Session 欄位；包含靜態 Red→Green、以真實 Git（臨時 repo＋本機 bare remote）驗證發布程序，以及離線決策重播；沒有 GitHub 寫入或通知。
tags: [verification, github-handoff]
generated: { by: claude-code/Claude Opus 5.5, at: 2026-11-13T23:30:00+08:00 }
sources:
  - id: change
    resource: /openspec/changes/streamline-github-pr-publication/
    title: OpenSpec Change streamline-github-pr-publication
  - id: git-test
    resource: /tests/test_github_pr_publication.sh
    title: 以真實 Git 驗證發布程序的測試
---

# GitHub 交接驗證紀錄 2026-11-13-streamline-pr-r01

## 範圍與授權

- 執行者：Claude Code，模型 Claude Opus 5.5。離線重播交給一個子 Agent（general-purpose，同一模型）。
- 使用者以 `/openspec-apply-change` 要求實作這個 change。這次**沒有**對 GitHub 寫入、沒有 push、
  沒有通知任何 Session；所有 Git 驗證都在 `mktemp` 建立的臨時 repo 與本機 bare remote 中進行。
- 執行期間，工作區有另一個 Agent 同時作業。它建立了 `cc4ff07`，並以 `90d3e5b`（訊息為
  `feat(simplify-github-pr): …`，attribution 為 Antigravity／Gemini 3.8 Flash）把本 change 當時
  尚未完成的實作一起 commit，同時封存了 `simplify-github-pr`，並由舊規格建立
  `openspec/specs/github-pr/spec.md`。本紀錄之後的修正（下文「重播後的修正」）仍未 commit。
  本紀錄沒有改動、重寫或撤銷那兩個 commit。

## 靜態測試：先 Red 再 Green

修改前執行，全部 `rc=1`：

| 套件 | 新增或改寫的檢查 | Red |
| --- | --- | --- |
| `tests/test_github_handoff.sh` SPP-1／SPP-2 | create 記載限定範圍的 commit 與 push 命令；程式碼區塊中沒有 `--force`、`--no-verify`、`git add -A`、`stash`、`reset`；commit writer 只用於整個工作區都屬本次的情況；不再詢問例行發布；契約與 README 不再禁止 create 發布；10 類發布案例；§6.2 每個 Author 都有兩個 Session 欄位；skill 先查詢再寫 `null`、只讀需要的鍵；新的 Author 不再把 Xirp ID 寫進 `SESSION-ID`；6 類 Session 案例 | 31 項 FAIL |
| `tests/test_change_review.sh` | 寫入與讀取 `XIRP-SESSION-ID`、Xirp ID 只是 lookup hint、案例涵蓋雙欄與舊的 `(xirp)` | 4 項 FAIL |
| `tests/test_github_pr_publication.sh`（新增） | skill 記載它實際驗證的 5 個命令 | 5 項 FAIL（同一次執行中，真實 Git 的 18 項語意檢查已經通過） |

改寫的舊斷言：舊版 SGP-1 的「github-pr 不 staging、不 commit、不 push」改為「update、reply、close 不寫 Git」，另加 create 的發布檢查；「Git publication is a separate step」改為「publish 仍然移除」；GP-24 從「缺少遠端分支就停止」改為「由 create 發布既有的 commit」。這些都換成新的行為檢查，沒有只刪不補。

舊行為的基準（修改前的 skill 文字）：「None of them stages, commits, pushes … Git publication is a separate step」，以及「No head branch on the remote … report the missing prerequisite」。舊的 GP-24 也是在分支不在遠端時停止。Author 只有一個 `SESSION-ID`，沒有要求先查詢 runtime。

修改後的結果（每次以 `bash "$t"; rc=$?` 取得 exit code）：12 套 `tests/test_*.sh` 全部 `rc=0`。`openspec validate streamline-github-pr-publication --strict`、`git diff --check` 通過。installer 的 exit code 為 0；github-pr、change-review、managed 契約與交接 SVG 的副本都與 template 一致（rc 0）。

## 真實 Git：臨時 repo 與本機 bare remote

`tests/test_github_pr_publication.sh` 執行的就是 skill 記載的命令：

- **混合工作區**：PR 檔案 `pr_a.txt`（修改）與 `pr_new.txt`（新增），加上無關的 staged、unstaged、untracked 檔案。`git add -- <pr-paths>` 與 `git commit -m … -- <pr-paths>` 之後，commit 只含兩個 PR 檔案；`u_staged.txt` 仍是 staged，unstaged 的修改仍未 staged，untracked 檔案仍是 untracked。
- **push**：push 目的地是驗證過的 remote；正常 push 成功；`ls-remote` 的 head 等於本機 commit。
- **重跑**：沒有剩下的 PR 變更，所以沒有第二個 commit；再 push 一次不會改變任何東西，commit 數與 remote head 都不變。
- **hook 失敗**：pre-commit hook 回傳 1 時，commit 被擋下，HEAD 不變，staged 的內容保留。
- **已 commit、未 push**：只 push，不產生新的 commit。
- **non-fast-forward**：push 被拒，遠端 head 不被覆寫。
- **尚未發布的前置 base**：`git push <remote> <base>:refs/heads/<base>` 原樣發布，不產生新的 commit。

## 離線決策重播

最終版的子 Agent 重播 GP-21、24、26、70–86 與 CR-45–47，共 23 例，全部 pass。對抗檢查的項目都沒有失敗：

- 沒有再次詢問是否 commit 或 push；
- 混合工作區沒有 stage 整個工作區；
- 重跑沒有重複 commit、push 或 create；
- 沒有未查詢就寫 `null`，也沒有把兩個 ID 互填；
- 沒有通知錯的 Session；
- update、reply、close 沒有呼叫 Git。

限制：子 Agent 在同一次讀取中看到了每個案例的預期內容，推導不是完全盲測。

GP-70 推導出的 Author：

```markdown
## Author

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
SESSION-ID: sess-7781
XIRP-SESSION-ID: xirp-42
```

### 重播後的修正

- skill 的 compare 呼叫補上 `gh api --hostname <host>`，共同 fixture 也說明 `gh api` 用 `--hostname`。
- GP-82 改為 Reviewer 自己的 `sess-9001`／`xirp-51`，並禁止填入實作者的 ID。
- CR-45 補上 Reviewer 自己的 ID。
- CR-47 的模擬回覆改為「依原生 ID 查 cliSessionId」，不再把原生 ID 當成管理 ID去查。

修正後重新安裝並重跑全部套件，都通過；這些修正之後沒有再重播。以下幾點未修改，留作紀錄：

- 各案例列出 create 步驟的詳略不一致，例如是否每次都列出 checks。
- 什麼情況必須用本機工具核對 Xirp ID，目前只在 GP-85 寫明。
- update 時是否一併更新 Author 沒有寫清楚。

## 已知限制

- 真實 GitHub 的 create、reply 與通知**都沒有驗證**，需要另外授權一個具體的測試 repository 與 Session。
- 本機的 runtime 確實提供 `CLAUDE_CODE_SESSION_ID` 與 `CHIRP_SESSION_ID`（只讀了變數名稱，沒有讀值）；Codex 的 `CODEX_THREAD_ID`／`CODEX_SESSION_ID` 依 design 的觀察撰寫，本輪沒有驗證。
- `openspec-verify-change` 本輪沒有執行。
- 主規格 `openspec/specs/github-pr/spec.md` 已由另一個 Agent 從 simplify-github-pr 建立。封存本 change 時，必須把其中「四個操作都不發布 Git」與「單一 Session ID」的條款改寫成本 change 的 MODIFIED deltas，不能讓兩邊相反的規則同時生效。

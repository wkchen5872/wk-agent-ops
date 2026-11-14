---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-14-simplify-design-approval-r02
description: 回應本地 Review codex-sgda-r01 的修正驗證：F-01 工作區版本核對、F-02 本機未提交設計的版本表達；Red／Green、真實 Git 演練、installer、12 套檢查與盲測重播。沒有 GitHub 寫入。
tags: [verification, github-handoff, design-approval]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T15:22:00+08:00" }
sources:
  - id: review
    resource: 本地 Review codex-sgda-r01（ignored Work Item，不發布）
    title: codex-sgda-r01
---

# GitHub 交接驗證紀錄 2026-11-14-simplify-design-approval-r02

## 範圍

- Review：codex-sgda-r01，結論 changes-required。這是本機 Review，本 Change 沒有 PR，不發布到 PR #15 或 #16。
- 基線：HEAD `b9112e0`，加上未提交的修改；index 為空。
- 本紀錄只提供修正證據；Finding 是否 Resolved 由 Reviewer 複審判定。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

## codex-sgda-r01/F-01：版本核對涵蓋實際工作區

**Red**：在舊契約上，新增的靜態期待有 15 項 FAIL（F-01 與 F-02 合計）。F-01 相關的有：

- `§9 no longer compares commits only`
- `§9 covers 'git diff --quiet <artifact_revision> -- …'`
- `… 'git ls-files --others --exclude-standard -- …'`
- `… '結束碼大於 1'`、`… '只差在 tasks 的勾選'`、`… '不能當成相同'`
- 案例 `工作區設計已實質改變`、`只有 tasks 勾選`、`基線不可得`

**修正**：§9 第 3 步改成拿目前工作區的實際內容比對：

1. 以 `git rev-parse --verify -q <rev>^{commit}` 確認基線存在。
2. 以 `git diff --quiet <rev> -- <Change>/` 比對工作區。不帶 `HEAD`，所以 staged 與 unstaged 都算；結束碼 0 是相同、1 是有差異、大於 1 是工具錯誤。
3. 以 `git ls-files --others --exclude-standard` 檢查 untracked 檔案。
4. 只差在 tasks 勾選時是進度紀錄，並給出確認用的命令：排除 tasks.md 的 diff，加上正規化後的 tasks 比對。
5. 基線不可得或工具錯誤時，結果是「無法核對」，不能當成相同。依當前指示判斷：指示涵蓋目前內容就繼續並回報限制，只靠舊紀錄時先釐清。

另新增案例 C-43、C-44、C-45。當前使用者直接授權的規則不變，也沒有加回任何身分關卡。

**真實 Git 演練**（`tests/test_github_handoff.sh` 的 SDA-5，以 disposable repo 執行）：

- 先重現 Reviewer 指出的缺口：`git diff --quiet d1 HEAD` 在工作區設計已修改時仍結束碼 0。
- 新程序的結果：
  - 未改動 → 相同。
  - 只勾 tasks → 相同，指紋也不變。
  - unstaged 修改 → 有差異。
  - staged 修改 → 有差異。
  - 新增 untracked 設計檔 → 有差異。
  - 不存在的基線 → 無法核對。

## codex-sgda-r01/F-02：本機未提交設計的版本表達

**Red**：見上方的 15 項，F-02 相關的有：

- `§6.3 covers 'unpublished-snapshot'`、`… "printf '%s\0'"`、`… '另一台機器'`、`… '不編造 commit'`
- 案例 `本機未提交規劃記到 PR`
- `github-pr records a local-only design revision honestly`

**修正**：§6.3 的 `artifact_revision` 可以寫 commit，也可以寫 `unpublished-snapshot sha256:<digest>（base <HEAD SHA>）`。

- 指紋算法：在 Change 根目錄下依相對路徑排序每個檔案，依序串接「相對路徑、NUL、內容、NUL」後取 SHA-256；計算前把 tasks.md 的 `- [x]` 還原成 `- [ ]`。契約附上可直接執行的指令。
- 不編造 commit 或連結，也不為了取得 commit 而自行 commit 或 push。
- 另一台機器若沒有這些檔案，就無法核對；檔案之後被 commit 或發布時，可以用同樣的算法對該版本重算。

github-pr 的批准步驟改為引用這個寫法，並新增案例 C-46。

**實證**：把契約中的指令原樣抽出，在本 Change 根目錄執行，得到 `72a824378d8328a8134e1f25e365e72053066199044c90cb338028d4d4a60a8c`，與原授權的指紋相同。這同時證明算法可重現、勾選進度不影響指紋，也證明原授權的規劃內容與本次實作所依據的內容一致。

## 盲測重播

新的 subagent 只讀契約 §6.3、§9 與 github-pr 的 Approval events，輸入只有 fixture 與模擬回覆：

| 案例 | 實際判定 | 與預期 |
| --- | --- | --- |
| C-43 工作區設計已實質改變 | 停止，`git diff` 結束碼 1 → 取得指示 | 相符 |
| C-44 只有 tasks 勾選 | 繼續，排除 tasks 的 diff 與正規化比對都相同 | 相符 |
| C-45 基線不可得 | 停止，結果是無法核對 | 相符 |
| C-46 本機未提交規劃記到 PR | 可發布：`unpublished-snapshot sha256:…（base b1）`，省略 `approved_by`，說明其他機器無法核對 | 相符 |

重播時 subagent 必須自己構造 C-44 的勾選比對命令，因此已把確切命令補進 §9。

## 整合檢查

- 最後一次 installer 的 exit 為 0，只同步 managed 目標與 Skill 副本。`.gitignore` 的修改時間變了，但內容與 HEAD 相同，是 installer 冪等改寫造成的。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0；test_github_handoff 為 486 ok。
- `openspec validate simplify-github-design-approval --strict` 通過；`git diff --check` 通過。

## 未執行

- 真實的 GitHub 批准事件發布與讀回、跨機器核對都沒有實測。
- 重播者與實作者是同一個模型家族。

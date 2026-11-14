---
type: Reference
title: commit GitHub 引用驗證紀錄 2026-11-14-commit-references-r02
description: 回應本地 Review codex-commit-refs-r01/F-01（原生 agent 與 openspec-commit 無條件排除背景／依賴目標）的修正驗證：Red／Green、installer、12 套檢查與 5 案盲測重播；沒有 GitHub 寫入。
tags: [verification, openspec-commit, git-commit-writer]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T19:20:00+08:00" }
sources:
  - id: review
    resource: 本地 Review codex-commit-refs-r01（ignored Work Item，不發布）
    title: codex-commit-refs-r01
---

# commit GitHub 引用驗證紀錄 2026-11-14-commit-references-r02

## 範圍

- Review：codex-commit-refs-r01，結論 changes-required。這是本機 Review，本 Change 沒有 PR，不寫入 PR #20。
- 受審快照：base `4bf00139…`，35 個檔案，digest `2c174fcb…f64a41`。修正開始前重算，結果相同。
- 本紀錄只提供修正證據；Finding 是否 Resolved 由 Reviewer 複審判定。前一輪證據見 [r01](2026-11-14-commit-references-r01.md)。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

## codex-commit-refs-r01/F-01

**問題**：writer Skill 已寫明背景、`references`、`depends-on` 目標「另被確認為直接處理時保留」，但 Claude agent、Codex agent 與 openspec-commit Step 5 寫成無條件排除。同一件工作會因為入口不同而遺失已確認的直接引用。

**Red**：在 `tests/test_openspec_commit.sh` 的 references 段新增檢查，修正前執行結果為 exit 1，9 項 FAIL：

- 兩個 agent 與 openspec-commit 缺少 `separately confirmed as directly addressed`（3 項）。
- 兩個 agent 含無條件的 `drop background links, ...`；openspec-commit 含無條件的 `` `depends-on` targets are not passed ``（3 項）。
- 缺少案例：writer「依賴後另被確認」、openspec-commit「只有依賴不交接」與「依賴後另被確認」（3 項）。

writer Skill 的同一檢查與既有的 WC-15（只有依賴）在修正前已通過，符合 Review 的描述。

**修正**（全部改在 template，再執行 installer）：

1. Claude agent、Codex agent：只排除沒有另被確認的背景、`references`、`depends-on` 目標；另被確認為本次 staged 工作直接處理時，與其他引用一樣保留。
2. openspec-commit Step 5：這類目標只在另被確認為本 Change 直接處理時才交接，否則不交接。
3. 案例：WC-15 標題補上「只有依賴」；新增 WC-16「依賴後另被確認直接處理」、OC-30「只有依賴不交接」、OC-31「依賴後另被確認直接處理」。
4. 文件：`docs/skills/git-commit-writer.md` 與 AGENTS.md 的說明同步。

未知或衝突的目標省略、離線沿用已確認的引用、不 amend 等既有行為都沒有改變。

## Green

- 修改後 references 段全部通過。
- installer exit 0；writer、openspec-commit 的 `.claude`、`.agents` 副本與兩個 agent 都與 template 相同；Codex TOML 可以解析。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0；test_openspec_commit 為 362 ok。
- `openspec validate preserve-github-commit-references --strict` 通過；`git diff --check` 通過。

## 盲測重播

做法：新的 subagent 讀 writer Skill、兩個 agent 與 openspec-commit Step 5；輸入只有 fixture 與模擬回覆，不讀 references、openspec 與 Work Item。

| 案例 | Skill／Claude agent／Codex agent | openspec-commit 交接 | 與預期 |
| --- | --- | --- | --- |
| WC-15 只有依賴 | 三者都是 `Refs: #19`，#12 因為只是依賴而省略 | — | 相符 |
| WC-16 依賴後另被確認 | 三者都是 `Refs: #12, #19` | — | 相符 |
| OC-26 既有交接 | — | #7（Handoff）、#12（確認的 PR），`Refs: #7, #12` | 相符 |
| OC-30 只有依賴 | — | 不交接 #9，`Refs: #7, #12` | 相符 |
| OC-31 依賴後另被確認 | — | 交接 #9（使用者本輪指示），`Refs: #7, #9, #12` | 相符 |

重播確認沒有任何入口丟掉另被確認的直接目標，也沒有任何入口保留只是依賴的目標。三個 writer 的 `Refs:` 行相同，只有 attribution 依工具不同。

重播提出的模糊處都是 fixture 的資料細節，本輪不修改：

- WC-15 沒有寫明 caller 是否已經濾掉 #12；兩種情況結果相同。
- WC-15、WC-16 的 URL 以 `…` 省略，重播者假設是本 repo。
- Codex agent 沒有 Claude agent 那樣的工具檢查；這是既有差異，不在本 Finding 範圍內。

## 未執行

- 沒有在正式 repo 建立 commit、push 或寫入 GitHub。
- 重播者與實作者是同一個模型家族。

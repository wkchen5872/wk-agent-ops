---
type: Playbook
title: OpenSpec Commit Workflow
description: Archive, documentation, and commit orchestration across Claude, Codex, and Antigravity.
tags: [workflow, openspec, agents]
timestamp: 2026-07-31T00:00:00+08:00
---

# OpenSpec Commit Workflow

`openspec-commit` 是 `/opsx:apply` 之後、`wt-done` 之前的薄協調層。它不重做
archive、文件判斷或 commit 邏輯，只依序呼叫三個能力：

1. `openspec-archive-change`
2. `doc-updater`
3. `git-commit-writer`

## 進入方式

三個 provider 共用同一份 project-owned `openspec-commit` skill，但入口保持
provider-specific：

| Provider | 入口 | Adapter 行為 |
|---|---|---|
| Claude Code | `/opsx:commit [change-name]` | `.claude/commands/opsx/commit.md` 透過 Skill tool 委派一次 |
| Antigravity | `/opsx-commit [change-name]` | `.agents/workflows/opsx-commit.md` 啟用 skill 一次；host 不支援 nested activation 時，在目前 context 讀取已安裝的 `SKILL.md` |
| Codex | 直接呼叫 `openspec-commit` | 使用已安裝的 project skill，不建立 command alias |

兩個 adapter 都只傳遞可選的 change name，不自行執行 archive、文件更新或
commit。這些步驟仍由 canonical skill 擁有。

## 執行順序

```text
active change / resumable archive
               |
               v
resolve attribution
  -> tool_name
  -> assisting_model
               |
               v
openspec-archive-change
  -> change_id
  -> archive_path
  -> spec_sync_status
  -> warnings
               |
               v
git add -A
  -> 新檔、spec sync、archive move 都進入 git diff HEAD
               |
               v
doc-updater(change_id, archive_path)
  -> archived proposal/specs + git status + git diff HEAD
               |
               v
git-commit-writer(change_id, archive_path, tool_name, assisting_model)
  -> final staging + empty-diff guard + commit
```

### 1. 找出 active 或 resumable context

協調層同時讀取：

```bash
openspec list --json
git status --short
```

Git status 中尚未 commit 的 `openspec/changes/archive/<date>-<change>/`
可作為中斷後的 resume 起點。多個候選時必須由使用者選擇，不可用目錄時間或
第一筆結果猜測。

### 2. Archive 或 resume

Active change 只呼叫一個 provider entry point 執行
`openspec-archive-change`，並等待 spec sync 決策與 archive 完成。下游收到
精確 hand-off：

```text
change_id=<change name>
archive_path=<exact archived directory>
spec_sync_status=<synced|skipped|no_delta_specs>
warnings=<list>
```

若 archive 已存在於未 commit 的 Git 狀態，直接沿用精確 `archive_path`，不再
執行 archive。路徑不存在時立即停止。

### 3. 文件更新

Archive 後先執行 `git add -A`，再把同一組 `change_id` 與 `archive_path`
交給 `doc-updater`。它會讀取：

- `<archive_path>/proposal.md`
- `<archive_path>/specs/**/*.md`
- `git status --short`
- `git diff HEAD`

Archive 檔案描述意圖，Git diff 描述實際完成內容；兩者不一致時，以 diff
作為文件聲明的依據。文件只留在工作區，交由同一次 feature commit 收納。

### 4. Commit

`git-commit-writer` 接收相同的精確 archive context，以及不可拆分的
attribution context：

```text
tool_name=<executing agent tool>
assisting_model=<primary implementation model>
```

`tool_name` 是實際執行工作的 agent tool；`assisting_model` 是主要實作模型。
commit-only agent 必須保留 caller 傳入的模型，不可改成自己的模型。驗證
context 後執行 final `git add -A`；若 staged diff 為空則停止；pre-commit
hook 修正檔案後必須重新 staging，再重試 commit。

## Provider 邊界

OpenSpec CLI 產生的原生 action 與 wk-agent-ops 安裝的 portable workflow 是
兩個不同邊界。

### OpenSpec CLI 原生 archive action

| Provider | 通用 skill | OPSX alias |
|---|---|---|
| Claude Code | `.claude/skills/openspec-archive-change/` | `.claude/commands/opsx/archive.md` |
| Codex | `.codex/skills/openspec-archive-change/` | 無 project command file |
| Antigravity | `.agent/skills/openspec-archive-change/` | `.agent/workflows/opsx-archive.md` |

`apply`、`archive`、`bulk-archive`、`continue` 是 OPSX action 名稱；對應的
通用 skill 名稱維持 `openspec-apply-change`、
`openspec-archive-change`、`openspec-bulk-archive-change`、
`openspec-continue-change`。同一個 action 只能選 skill 或 alias 其中一個，
不可兩邊都執行。

### wk-agent-ops portable workflow

`scripts/skills/install.sh` 只產生：

| Template source | Installed target |
|---|---|
| `template/common/skills/*` | `.claude/skills/*`、`.agents/skills/*` |
| `template/common/.claude/commands/opsx/commit.md` | `.claude/commands/opsx/commit.md` |
| `template/common/.agents/workflows/opsx-commit.md` | `.agents/workflows/opsx-commit.md` |

Installer 不產生 `.codex/` 或單數 `.agent/`；這兩個目錄由 OpenSpec 的
provider setup 管理。

## 失敗與續跑

| 狀況 | 行為 |
|---|---|
| 多個 active / archive 候選 | 詢問使用者，不猜測 |
| Archive 失敗或回傳路徑不存在 | 停在 docs 與 commit 之前 |
| Archive 已完成、docs 或 commit 中斷 | 從 Git status 的精確 archive path resume |
| Doc update 衝突 | 顯示衝突檔案並停止 |
| Commit hook 失敗 | 修正、重新 `git add -A`、檢查 cached diff、重試 |

## 相關文件

- [多 Agent 協作工作流](/docs/workflow/guide.md)
- [Doc Updater](/docs/skills/doc-updater.md)
- [Git Commit Writer](/docs/skills/git-commit-writer.md)

# Citations

[1] [OpenSpec supported tools](https://github.com/Fission-AI/OpenSpec/blob/main/docs/supported-tools.md)

[2] [How OpenSpec commands work](https://github.com/Fission-AI/OpenSpec/blob/main/docs/how-commands-work.md)

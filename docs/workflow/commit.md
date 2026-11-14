---
type: Playbook
title: OpenSpec Commit Workflow
description: Archive, documentation, and commit orchestration across Claude, Codex, and Antigravity.
tags: [workflow, openspec, agents]
generated: { by: Codex/GPT-6.1-Sol, at: 2026-11-14T13:48:40+08:00 }
sources:
  - id: commit-skill
    resource: /template/common/skills/openspec-commit/SKILL.md
    title: OpenSpec Commit
  - id: handoff-contract
    resource: /docs/github-handoff.md
    title: GitHub 交接契約
  - id: delivery-design
    resource: /openspec/changes/archive/2026-11-14-extend-openspec-commit-delivery/design.md
    title: Commit 交付擴充設計
---

# OpenSpec Commit Workflow

`openspec-commit` 是 `/opsx:apply` 之後、`wt-done` 之前的薄協調層。它不重做
archive、文件判斷或 commit 邏輯，只依序呼叫三個能力：

1. `openspec-archive-change`
2. `doc-updater`
3. `git-commit-writer`

本地三步與 provider routing 由現有 Skill 管理。[^commit-skill]

只有使用者授權時，它才在本地完成後，把結果交付到 Change 既有的 PR（見下方「遠端交付」）。這是[本機開發四階段流程](local-development.md)的第 04 階段。

## 協調運作架構

```text
                  ┌────────────────────────┐
                  │ 呼叫 /opsx:commit      │
                  └───────────┬────────────┘
                              │
                              ▼
               ┌──────────────────────────────┐
               │ 1. openspec-archive-change   │
               │    搬移變更至 archive/       │
               └──────────────┬───────────────┘
                              │
                              ▼
               ┌──────────────────────────────┐
               │ 2. doc-updater               │
               │    分析 diff 並更新文件      │
               └──────────────┬───────────────┘
                              │
                              ▼
               ┌──────────────────────────────┐
               │ 3. git-commit-writer         │
               │    暫存並建立標準 commit     │
               └──────────────┬───────────────┘
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
          [本地完成 (預設)]             [授權遠端交付]
          停止於 commit                 1. 正常 push 至遠端分支
          不推送、不改動 PR             2. github-pr update 更新說明
                                        3. 檢查最終 Review 證據
                                        4. github-pr reply 發布 Closure
```

## 進入方式

所有 provider 共用同一份 project-owned `openspec-commit` skill，但入口保持
provider-specific：

| Provider | 入口 | Adapter 行為 |
|---|---|---|
| Claude Code | `/opsx:commit [change-name]` | `.claude/commands/opsx/commit.md` 透過 Skill tool 委派一次 |
| Antigravity | `/opsx-commit [change-name]` | `.agents/workflows/opsx-commit.md` 啟用 skill 一次；host 不支援 nested activation 時，在目前 context 讀取已安裝的 `SKILL.md` |
| Codex | 直接呼叫 `openspec-commit` | 使用已安裝的 project skill，不建立 command alias |

兩個 adapter 都只傳遞可選的 change name，不自行執行 archive、文件更新或
commit。這些步驟仍由 canonical skill 擁有。

Claude Code 與 Codex 在文件及 commit 階段分別呼叫
`doc-updater-agent`、`git-commit-writer-agent`；若任一 subagent 不存在便停止，
不靜默降級。其他 provider 預設使用 `.agents/skills/` 下同名但沒有
`-agent` 後綴的 portable skills。

## 執行順序

```text
active change / resumable archive
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
doc-updater-agent 或 doc-updater skill(change_id, archive_path)
  -> archived proposal/specs + git status + git diff HEAD
               |
               v
resolve commit attribution
  -> tool_name
  -> assisting_model (Git trailer metadata only)
               |
               v
git-commit-writer-agent 或 git-commit-writer skill
  (change_id, archive_path, tool_name, assisting_model)
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
交給依 provider 選定的 `doc-updater-agent` 或 `doc-updater` skill。它會讀取：

- `<archive_path>/proposal.md`
- `<archive_path>/specs/**/*.md`
- `git status --short`
- `git diff HEAD`

Archive 檔案描述意圖，Git diff 描述實際完成內容；兩者不一致時，以 diff
作為文件聲明的依據。文件只留在工作區，交由同一次 feature commit 收納。

### 4. Commit

文件處理完成後，協調層才解析 attribution。`git-commit-writer-agent` 或
portable `git-commit-writer` skill 接收相同的精確 archive context，以及不可拆分的
attribution context：

```text
tool_name=<executing agent tool>
assisting_model=<current root-session model>
```

`tool_name` 是擁有 root session 的 agent tool；`assisting_model` 是當下協作的 AI 模型，只用於 commit 的 `AI-Assisted-By` trailer。協調層會自動使用目前確認的執行工具與模型，並寫入符合規範的 attribution 標籤。
驗證 context 後執行 final `git add -A`；若 staged diff 為空則停止；pre-commit hook 修正檔案後會重新 staging，再重試 commit。

## 遠端交付

開始時先決定交付路徑：

| 路徑 | 何時 | 結果 |
|---|---|---|
| 本地完成（預設） | 只要求封存與 commit，或沒有 PR | archive、docs、commit；不 push、不建立 PR、不 merge、不 close |
| 成功交付 | 授權發布到既有 PR | 正常 push 並讀回 remote head → `github-pr update` → 確認最終 head 的 pass → `github-pr reply` Closure，等待另外授權的 merge |
| 取消或被取代 | 明確授權關閉 PR 並給理由 | 委派 `github-pr close`（先 Closure 再關閉）；不 push 放棄的成果，Issue 與分支不動 |

PR 或目標不明、或缺少授權時，本地結果照常完成，遠端步驟回報為 pending 或 blocked。
最終 head 已有相符的 pass 時可沿用；需要新一輪 Review 時，必須另有審查／驗收授權。
沒有該授權就停在 Closure 前，不因授權發布而自動開啟審查。[^delivery-design]
封存與文件 commit 會產生新 head，先前的 pass 不涵蓋它。推送被拒、head 移動或最終 Review
未通過時，停在 Closure 之前，不 force、不自動修正或重跑。各段結果（archive、docs、commit、
push、PR update、最終 Review、Closure、close）分開回報；merge、部署與 Issue 驗收不由本流程
宣稱完成。PR 留言的格式見 [GitHub 交接契約](../github-handoff.md)。
Closure 的發布、回讀及 Issue 的獨立結案規則由該契約管理。[^handoff-contract]

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
| `template/common/.codex/agents/*.toml` | `.codex/agents/*.toml` |

Installer 對 `.codex/` 的管理只限於 project-owned `.codex/agents/`；不產生
單數 `.agent/`，也不修改 OpenSpec provider setup 管理的 `.codex/skills/`。

## 失敗與續跑

| 狀況 | 行為 |
|---|---|
| 多個 active / archive 候選 | 詢問使用者，不猜測 |
| Archive 失敗或回傳路徑不存在 | 停在 docs 與 commit 之前 |
| Archive 已完成、docs 或 commit 中斷 | 從 Git status 的精確 archive path resume |
| Doc update 衝突 | 顯示衝突檔案並停止 |
| Claude Code／Codex 缺少必要 subagent | 顯示 provider 配置錯誤並停止，不改走 skill |
| Commit hook 失敗 | 修正、重新 `git add -A`、檢查 cached diff、重試 |
| 工作區混有其他工作 | archive 前停止並列出路徑，不 stash、不刪除 |
| commit 已完成、push 失敗 | 以 `git log -1 --format=%H -- openspec/changes/archive/<archive-dir>/` 找回 commit，只補已授權的 push |
| push 已確認、PR update 失敗 | 保留 push，只補 `github-pr update` |
| Closure 已確認、close 失敗 | 由 `github-pr close` 沿用既有摘要，只補 close |
| 任一寫入結果不明 | 先讀現況；查不清就回報 uncertain，不重送 |

這些接續都靠現有證據判斷，不另建狀態檔；同一個 Change 有多個已提交的 archive 時，詢問使用者。

## 相關文件

- [多 Agent 協作工作流](/docs/workflow/guide.md)
- [本機開發四階段流程](/docs/workflow/local-development.md)
- [Doc Updater](/docs/skills/doc-updater.md)
- [Git Commit Writer](/docs/skills/git-commit-writer.md)

## 來源與外部參考

本地與遠端交付行為以目前 Skill 為準；archive 保留設計意圖與驗證範圍。下列既有外部入口參考保留供查閱，未在本輪重新核對版本。

[^commit-skill]: [OpenSpec Commit 來源](../../template/common/skills/openspec-commit/SKILL.md)，本地三步、遠端交付與 commit 後恢復。
[^handoff-contract]: [GitHub 交接契約](../github-handoff.md)，§6.7、§10。
[^delivery-design]: [Commit 交付擴充設計](../../openspec/changes/archive/2026-11-14-extend-openspec-commit-delivery/design.md)。

[1] [OpenSpec supported tools](https://github.com/Fission-AI/OpenSpec/blob/main/docs/supported-tools.md)

[2] [How OpenSpec commands work](https://github.com/Fission-AI/OpenSpec/blob/main/docs/how-commands-work.md)

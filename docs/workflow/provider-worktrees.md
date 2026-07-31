---
type: Reference
title: Provider-native Worktree Reference
description: Claude、Codex 與 Antigravity 的原生 Worktree 位置、checkout 行為與跨 Provider 接手規則。
tags: [workflow, git, worktree, claude, codex, antigravity]
timestamp: 2026-07-31T00:00:00+08:00
---

# Provider-native Worktree Reference

本文件記錄會隨 Provider 版本改變的 Worktree 行為。核心 workflow 不應硬編碼
Provider 目錄；對任何 repository，`git worktree list --porcelain` 才是實際
Worktree registry 的權威來源。

## Surface 與預設位置

| Provider surface | 原生建立 | 預設位置 | Checkout / 管理特性 |
|---|---:|---|---|
| Claude Code CLI (`claude -w <name>`) | 是 | `<repo>/.claude/worktrees/<name>` | 位置可由 `WorktreeCreate` hook 改寫 |
| Claude Code Desktop | 是 | `<repo>/.claude/worktrees/` | Worktree root 可在 Desktop settings 修改 |
| Codex CLI | 否 | — | 可用 cwd 或 `codex -C <path>` 進入既有 Worktree |
| Codex（ChatGPT desktop app） | 是 | `$CODEX_HOME/worktrees`（通常為 `~/.codex/worktrees`） | 預設 detached HEAD；Worktree root 可在 settings 修改 |
| Antigravity CLI (`agy`) | 否 | — | Conversation 以啟動時的 cwd 為 scope |
| Antigravity 2.0 | 是 | 官方未承諾固定 root | New Worktree Mode 建立隔離 checkout |
| wk-agent-ops `wt-work` | 是 | `<repo>/.worktrees/<change-id>` | 使用 `feature/<change-id>`；目前由 `wt-done` 清理 |

「Provider 支援 Worktree」不代表該 Provider 的所有 surface 都會建立 Worktree。
Codex 與 Antigravity 的桌面介面可原生建立，但其 CLI 適合進入已解析的目錄；
Claude Code CLI 則同時支援原生建立與使用既有目錄。

## Starting Ref 必須包含 Planning Commit

原生 Worktree 的預設起點不一致：

| Surface | Starting ref 行為 |
|---|---|
| Claude Code CLI | `worktree.baseRef=fresh`（預設）從 `origin/<default-branch>` 建立；設為 `head` 才包含目前本地 HEAD |
| Codex（ChatGPT desktop app） | 從建立對話時選定 branch 的 HEAD 開始，並套用當時選取的本地變更；初始為 detached HEAD |
| Antigravity 2.0 | 官方文件未說明如何選擇 starting ref |
| `wt-work` | 直接 attach `feature/<change-id>`，因此繼承該 branch 的 planning commit |

PM → RD hand-off 應攜帶精確 `planning_commit`，並在 apply 前驗證 resolved
Worktree 的 HEAD 包含該 commit。不能只確認 change 目錄名稱存在，否則可能讀到
舊版本 artifacts。

```bash
git -C <worktree-path> merge-base --is-ancestor <planning-commit> HEAD
```

## 不要靠目錄命名猜測

從 repository 的任一 checkout 執行：

```bash
git worktree list --porcelain
```

輸出會列出每個 Worktree 的實際 path、HEAD，以及 named branch 或 detached
狀態。這可以發現 Provider 放在 repository 外部的 Worktree。

Named branch 可透過 `refs/heads/feature/<change-id>` 自動對應 change。Detached
HEAD 沒有 branch 可供反查，跨 Provider 接手時必須取得或記錄精確 path，不能只
靠 `change-id` 猜測。

## 跨 Provider 接手

Provider A 卡住時，Provider B 應進入 **同一個 Worktree path**，而不是再次使用
原生 Worktree 建立功能。

```text
停止 Provider A 與其 subagents
    ↓
解析並驗證原 Worktree path
    ↓
檢查 git status / diff / HEAD
    ↓
Provider B 在同一 path 啟動
    ↓
重新讀取 OpenSpec artifacts 與未完成 tasks
```

啟動範例：

```bash
# Claude：已在既有 Worktree 內，不加 -w
claude

# Codex：明確指定既有 Worktree
codex -C <worktree-path>

# Antigravity：從既有 Worktree 啟動
cd <worktree-path>
agy
```

對話歷史不會跨 Provider 轉移；可攜的 hand-off context 是 repository 檔案、Git
狀態、OpenSpec artifacts、測試結果與未完成 task。

上述 same-path 接手只適用於同一台機器或共享檔案系統。跨機器時，先把工作建立
成 named-branch commit 並推送，再由接手端建立新的 Worktree；不要複製
Provider-native Worktree 目錄。未 commit 的變更若沒有另外產生 patch 或其他
明確 hand-off artifact，就不會隨 session 移動。

## 衝突矩陣

| 情境 | 結果 |
|---|---|
| A 停止後，B 使用同一 Worktree | 可安全接手；不產生新的 Git Worktree 衝突 |
| A、B 同時寫入同一 Worktree | 禁止；可能覆寫檔案、index 或測試狀態 |
| B 建立第二個 Worktree 並 checkout 同一 named branch | Git 預設拒絕 |
| B 建立 detached 或不同 branch Worktree | Git 允許，但工作已分岔，後續需要額外 merge |

## Provisioner、Cleanup Owner 與 Active Writer

建立 Worktree 的角色通常也是 cleanup owner，但執行工作的 Provider 可以切換：

```text
provisioner / cleanup_owner = project | provider
active_writer               = none | claude | codex | antigravity | copilot
```

- `wt-work` attach 既有 Provider Worktree 時，不會因此自動取得 cleanup ownership。
- Provider-native Worktree 被其他 Provider 使用期間，不應 archive 原 session 或
  觸發自動清理。
- Codex-managed Worktree 預設 detached HEAD 且可能隨 chat archive 或 retention
  policy 清理；長時間 hand-off 前應建立可追蹤 checkpoint，或轉為 permanent
  Worktree。
- Cleanup 只能由已知 owner 執行；不可從目錄名稱猜測後直接刪除。

## 對 `wt-work` 的含意

跨 Provider failover 是需求時，Project-managed Worktree 是較穩定的預設：

```text
wt-work 建立 .worktrees/<change-id>
    ↓
任何 Provider adapter 都在相同 path 啟動
    ↓
Provider 切換不改變 Git checkout
```

`wt-work` 也可以 attach 已存在的 Provider-native Worktree。明確 `--path` 優先；
未提供時從 `git worktree list --porcelain` 搜尋唯一且可驗證的候選。候選不唯一就
停止並要求 `--path`，不保存額外 mapping。Attach 保留原 cleanup owner，且不得
建立第二個 Worktree。現行腳本尚未支援此行為。

跨 Provider 切換的目標語意是新的 `wt-work` 啟動；`wt-resume` 只恢復同一
Provider 的 session，不能用來搬移對話歷史。現行 `wt-work` 尚未區分既有
Worktree 的 resume 與 cross-provider new session，因此目前應使用上方的 Provider
直接啟動命令。

## Local Setup 與 Ignore Policy

Project-managed Worktree 採以下最小 policy：

- `.worktrees/` 保持在 `.gitignore`。
- Core 複製現有 `.env`。
- Provider adapter 只複製所選 LLM Provider 已知且存在的 local settings；不複製
  其他 Provider 設定。
- 不自動安裝 dependencies。

Codex `.worktreeinclude` 只適用於 Codex-managed Worktree，不由 `wt-work` 或
installer 自動建立。Provider-native Worktree 的其他 local setup 仍由建立它的
Provider 負責。

## 相關文件

- [PM/RD 多 Agent 協作工作流](/docs/workflow/guide.md)
- [OpenSpec、Git 與 Session 邊界](/docs/workflow/concepts.md)
- [wt-work Worktree and Branch Resolution Flow](/docs/workflow/wt-work-flow.md)

# Citations

[1] [Claude Code CLI reference — `--worktree`](https://code.claude.com/docs/en/cli-usage)

[2] [Claude Code Desktop — Worktree location](https://code.claude.com/docs/en/desktop)

[3] [Claude Code tools reference — `EnterWorktree`](https://code.claude.com/docs/en/tools-reference)

[4] [Claude Code hooks — `WorktreeCreate`](https://code.claude.com/docs/en/hooks)

[5] [Claude Code settings — `worktree.baseRef`](https://code.claude.com/docs/en/settings)

[6] [Codex worktrees](https://developers.openai.com/codex/app/worktrees)

[7] [Codex environment variables — `CODEX_HOME`](https://learn.chatgpt.com/docs/config-file/environment-variables)

[8] [Codex CLI reference — `--cd`](https://developers.openai.com/codex/cli/reference)

[9] [Antigravity Projects — Worktree Selection](https://antigravity.google/docs/projects?app=cli)

[10] [Antigravity CLI — Workspace scoping](https://antigravity.google/docs/cli/conversations)

[11] [Git worktree documentation](https://git-scm.com/docs/git-worktree)

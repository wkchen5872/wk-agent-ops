# Workflow 自動化腳本手冊

本目錄提供 OpenSpec branch-first 規劃、Git Worktree hand-off 與多 Provider
session 啟動工具。Worktree 解析只讀取 Git registry，不保存額外 mapping。

## 安裝

```bash
bash scripts/workflow/install.sh
source ~/.zshrc
```

安裝程式可重複執行，會部署 `opsx-branch`、`wt-work`、`wt-resume`、
`wt-done`、`pm-start` 與 zsh completion。PostToolUse branch hook 只是相容性
fallback；正式流程應在建立 OpenSpec artifacts 前執行 `opsx-branch`。

fallback hook 會註冊到 Claude Code、Codex 與 GitHub Copilot CLI；Antigravity
只使用 managed operating protocol 的 Agent-mediated guard。Codex 若提示 hook
尚未信任或未啟用，請用 `/hooks` 檢查該 entry。

## 指令

### `opsx-branch <change-id>`

驗證 kebab-case change ID，建立或切換 `feature/<change-id>`。若 branch 已由其他
Worktree checkout，會顯示該 path 並停止。

### `pm-start [--agent <provider>]`

從 repository root 啟動 PM planning session。支援 `claude`、`codex`、
`antigravity`（亦接受 CLI 名稱 `agy`）、`copilot`；預設 Claude。Claude 與
Antigravity 直接使用原生 plan flag，Codex 與 Copilot 會提示使用者在 Provider 內
選擇 Plan Mode。此命令不建立 branch、OpenSpec change 或 Worktree。

### `wt-work <change-id> [options]`

RD apply launcher。`--agent` 支援四個 Provider；省略 `--session` 會啟動新
session，明確提供 `--session` 才恢復該 session。兩種路徑都只傳入一次
`openspec-apply-change` intent。

```text
--agent, -a <claude|codex|antigravity|agy|copilot>
--session, -s <id-or-name>
--path, -p <registered-worktree-path>
--base, -b <branch>                         # default: main
```

Path resolution 順序：

1. 明確 `--path`。
2. registered `.worktrees/<change-id>`。
3. 唯一 checkout `feature/<change-id>` 的非 primary Worktree。
4. 唯一包含 active change 且 HEAD 含 planning branch tip 的 detached Worktree。
5. 無候選時，只能從已確認的 local／remote `feature/<change-id>` 建立
   `.worktrees/<change-id>`。

多個候選會列出 path 並要求 `--path`。同機 attach 允許 dirty state；啟動前會列出
path、branch／detached、HEAD 與 `git status --short`，不會 stash、commit、reset
或清除變更。

新 Project-managed Worktree 只複製存在且 target 尚不存在的檔案：

| Provider | local files |
|---|---|
| all | `.env` |
| Claude | `.claude/settings.local.json` |
| Codex | `.codex/config.toml` |
| Antigravity | 無 repo-local allowlist |
| Copilot | 無額外 local-only file |

不複製 global credentials、其他 Provider 設定或 legacy `.gemini/settings.json`；
不建立 `.worktreeinclude`，也不安裝 dependencies。

### `wt-resume <change-id> [options]`

使用與 `wt-work` 相同的 `--path`／registry resolver，只恢復所選 Provider 的
session，不注入 apply intent。無 `--session` 時使用該 Provider 的 native picker
或 continue 行為。

### `wt-done <change-id> [--base <branch>]`

Local-only merge helper。只移除 registered `.worktrees/<change-id>`；不接受任意
cleanup path，也不移除 Provider-native Worktree。若 Provider-native path 仍
checkout feature branch，merge 後保留該 branch 供原 cleanup owner 處理。它不啟動
Provider，因此沒有 `--agent`，`agy` alias 也不適用。

## Zsh Completion

`_wt` 從 `git worktree list --porcelain` 取得 change ID，並補全四個 Provider、
`--session`、`--path` 與 `--base`。不掃描未註冊的 `.worktrees/` 目錄。

## 相關文件

- [多 Agent 協作工作流](../../docs/workflow/guide.md)
- [Worktree resolution](../../docs/workflow/wt-work-flow.md)
- [Provider-native Worktree reference](../../docs/workflow/provider-worktrees.md)
- [OpenSpec Commit 工作流](../../docs/workflow/commit.md)

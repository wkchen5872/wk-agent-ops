# Workflow 自動化腳本手冊

本目錄提供 OpenSpec branch-first 規劃的分支準備工具。Session 與 Worktree 管理
由使用者選用的工具（例如 Xirp、Herdr 或原生 Git／Provider 指令）負責，本目錄
不提供 launcher、resolver 或 cleanup 指令。

## 安裝

```bash
bash scripts/workflow/install.sh
source ~/.zshrc
```

安裝程式可重複執行，會部署 `opsx-branch` 與其 zsh completion `_opsx-branch`。
PostToolUse branch hook 只是相容性 fallback；正式流程應在建立 OpenSpec artifacts
前執行 `opsx-branch`。

fallback hook 會註冊到 Claude Code、Codex 與 GitHub Copilot CLI；Antigravity
只使用 managed operating protocol 的 Agent-mediated guard。Codex 若提示 hook
尚未信任或未啟用，請用 `/hooks` 檢查該 entry。

安裝後請重新開 shell；若補全仍是舊結果，刪除 completion cache 後重建：

```bash
rm -f ~/.zcompdump* && autoload -Uz compinit && compinit
```

## 指令

### `opsx-branch <change-id>`

驗證 kebab-case change ID，建立或切換 `feature/<change-id>`。若 branch 已由其他
Worktree checkout，會顯示該 path 並停止。

## Zsh Completion

`_opsx-branch` 只註冊 `opsx-branch`，從本地 `feature/*` branch 建議 change ID
（去重）；也可輸入全新 ID。不在 Git repository 內時不顯示候選，也不報錯。

## 已退役的指令

`wt-work`、`wt-resume`、`wt-done`、`pm-start` 與 `wk-workflow-runtime` 已退役，
沒有相容 wrapper。重跑安裝程式時：

- `~/.local/bin/{wt-work,wt-resume,wt-done,pm-start,wk-workflow-runtime,wt-new}`
  與 `~/.local/share/zsh/site-functions/_wt` 若是內容完全符合正式部署版本的
  regular file，會被移除並列出。
- 修改過、未知版本或 symlink（含 dangling）一律保留，並標示需 manual cleanup；
  請自行確認後刪除。
- 不會改動既有 branch、Worktree、Session、設定、憑證或 PATH／fpath 設定。

## 相關文件

- [多 Agent 協作工作流](../../docs/workflow/guide.md)
- [Provider-native Worktree reference](../../docs/workflow/provider-worktrees.md)
- [OpenSpec Commit 工作流](../../docs/workflow/commit.md)

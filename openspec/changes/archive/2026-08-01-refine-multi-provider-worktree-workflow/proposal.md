## Why

現行 workflow scripts 仍以 Claude／Gemini 與固定 `.worktrees/<name>` 路徑為核心，
而 OpenSpec change 又依賴建立 artifacts 後才切 branch 的 PostToolUse hook。這使
branch-first 規劃、Codex／Antigravity 執行、Provider failover 與外部 Worktree
接手無法形成一致且可驗證的 PM → RD 流程。

## What Changes

- 將 Scope Ready 後的 branch-first transition 明確化，讓 feature branch 在
  `openspec new change` 寫入 artifacts 前就存在；既有 PostToolUse hook 降為相容
  fallback，不再是正確性的必要條件。
- 讓 `pm-start` 保持「只啟動規劃 session」的責任，支援可用的 Provider plan
  adapters，不自動建立 OpenSpec change、branch 或 Worktree。
- **BREAKING**：從 workflow scripts、completion 與文件移除 Gemini CLI，新增
  Codex 與 Antigravity adapters（接受 `antigravity` 與官方 CLI 名稱 `agy`），並
  保留既有 Claude／Copilot 支援。
- 讓 `wt-work` 預設建立 Project-managed Worktree；已存在的 Provider-native
  Worktree 透過 `--path` attach，省略 `--path` 時只接受 Git registry 中唯一且
  可驗證的候選。
- **BREAKING**：分離 `wt-work` 的 new-session／apply 語意與 `wt-resume` 的
  same-provider resume 語意，避免跨 Provider 接手時錯誤恢復舊 Provider session。
- 允許同機 failover 保留 dirty Worktree；checkpoint commit 由使用者依情境決定，
  跨機器 hand-off 才要求可攜的 commit／patch。
- 固定 cleanup ownership：`wt-done` 只清理 Project-managed Worktree；attach 或
  Provider 切換不取得 Provider-native Worktree 的刪除權。
- 建立 Project-managed Worktree 時保留 `.env`，並只複製所選 LLM Provider 已知
  且存在的 repository-local settings；不自動安裝 dependencies 或產生 Codex
  `.worktreeinclude`。
- 補齊 shell-level regression tests、installer/completion 行為與 workflow 文件。

## Capabilities

### New Capabilities

<!-- None. This change refines existing workflow capabilities. -->

### Modified Capabilities

- `openspec-branch-creator-hook`: branch creation becomes an explicit branch-first transition; the hook is compatibility-only.
- `pm-start`: launch planning sessions without implicitly creating OpenSpec or Git state, with provider-aware plan adapters.
- `workflow-scripts`: install the revised provider-neutral workflow entrypoints and document their ownership boundaries.
- `wt-work`: add Project-managed defaults, provider adapters, `--path`, safe auto-discovery, new-session semantics, dirty attach, and provider-local settings copy policy.
- `wt-work-cross-machine`: distinguish unique local attach, remote branch hand-off, ambiguous candidates, and remote lookup failures.
- `wt-resume`: restrict resume to the selected Provider and replace Gemini with Codex／Antigravity behavior.
- `wt-zsh-completion`: expose the revised provider matrix and `--path` option.

## Impact

- 主要程式：`scripts/workflow/pm-start.sh`、`wt-work.sh`、`wt-resume.sh`、
  `wt-done.sh`、`lib.sh`、`_wt`、`install.sh` 與
  `openspec-branch-creator/`。
- 規格與文件：上述七個 canonical capabilities、`docs/workflow/`、
  `scripts/workflow/README.md` 與必要的 architecture references。
- 相容性：既有 `wt-work <change-id>` 仍建立 `.worktrees/<change-id>`；Gemini
  agent value 與「既有 Worktree 自動 resume」行為會移除。
- 外部依賴：不新增套件；使用既有 Bash、Git、OpenSpec 與已安裝的 Provider CLI。

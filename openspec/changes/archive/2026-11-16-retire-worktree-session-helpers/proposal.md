# Proposal

## Why

Session 與 Worktree 的日常管理已由使用者改用 Xirp／Herdr，repo 仍維護另一套 launcher、resolver 與 cleanup 工具，增加維護及誤用成本。保留 OpenSpec 分支準備功能，退役重複的管理工具。

## What Changes

- **BREAKING** 移除 `wt-work`、`wt-resume`、`wt-done`、`pm-start` 與專用 `runtime.sh`，不提供相容 wrapper。
- 保留 `opsx-branch`、`openspec-branch-creator` hook、hook 安裝／移除及 `lib.sh`；branch-first 與 Provider 支援範圍維持現況。
- installer 只部署保留工具；安全清除可識別的舊安裝副本，保留自訂檔案與 symlink 並回報。
- 將 completion 縮為 `opsx-branch`；更新測試、Skill、現行文件及圖稿，保留歷史紀錄。
- 驗收包含新裝、升級、重複安裝、自訂副本保護，以及保留的 branch command／hook 回歸測試。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `workflow-scripts`: 縮減安裝、文件及 cleanup 契約，新增安全退役要求；保留 branch-first requirements。
- `wt-work`: 移除全部 launcher、resolver 與本地設定複製 requirements。
- `wt-resume`: 移除 session resume requirement。
- `wt-work-cross-machine`: 移除舊工具的跨機交接 requirements。
- `pm-start`: 移除 planning session launcher requirement。
- `wt-zsh-completion`: 移除舊命令補全，改成 branch command 專用補全。

## Impact

影響 `scripts/workflow/`、`tests/test_workflow.sh`、README、workflow／architecture 文件與相關圖稿，以及 `template/common/skills/openspec-commit/SKILL.md` 的舊工具引用。Skill 必須經 `scripts/skills/install.sh` 同步安裝副本。

全域安裝目標為 `~/.local/bin` 與 zsh site-functions。升級只處理已知工具檔案，不清理既有 branch、worktree、Session、設定、憑證或通用 PATH／fpath。

Claude Code、Codex、Antigravity、GitHub Copilot CLI 的 Agent-mediated branch guard 保留；hook 僅保留現有支援方式，不新增 Provider 整合。Xirp／Herdr 不成為安裝依賴，也不在本次實作指揮官或自動 Review 迴圈。

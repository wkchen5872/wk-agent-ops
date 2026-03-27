## Why

開發者在使用 `git-commit-writer` 或手動 commit 後，沒有一個通用的機制自動同步 `docs/`、`README.md`、`AGENTS.md` 等說明文件。目前 `openspec-commit` 雖有文件更新流程，但綁定了 OpenSpec 工作流程，無法用於沒有建立 OpenSpec change 的簡單 commit。

## What Changes

- 新增 `doc-updater` agent（`.claude/agents/doc-updater.md`）
- 新增 `doc-updater` skill（`.claude/skills/doc-updater/SKILL.md`）
- 新增 template 版本（`template/common/` 對應位置）
- 新增 `docs/doc-updater.md` 使用說明文件
- 更新 `AGENTS.md` 加入 doc-updater 項目

## Capabilities

### New Capabilities

- `doc-updater`: 讀取最後一個 git commit 內容，分析變更類型，對 `docs/`、`README.md`、`AGENTS.md` 做最小化更新，並建立獨立的 `docs:` commit；對瑣碎變更（test、style、typo 等）自動跳過

### Modified Capabilities

<!-- none -->

## Impact

- 新增 4 個檔案（agent × 2 template+active、skill × 2 template+active）
- 新增 1 個說明文件 `docs/doc-updater.md`
- 修改 `AGENTS.md`（新增 agent 說明項目）
- 無破壞性變更，不影響現有 agent 或 skill

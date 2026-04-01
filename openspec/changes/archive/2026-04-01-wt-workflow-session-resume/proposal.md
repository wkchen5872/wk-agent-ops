## Why

`wt-new.sh` 的語意模糊（同時涵蓋「新建 worktree」與「自動恢復 coding」），且兩支腳本均不支援 Gemini CLI、也無法讓使用者指定特定 session ID/name。隨著多 AI CLI 工具（Claude、Copilot、Gemini）並行使用，需要統一的恢復機制與清楚的工具語意。

## What Changes

- **BREAKING** `wt-new.sh` 重新命名為 `wt-work.sh`，語意改為「進行 coding 工作」（新建或繼續實作）
- `wt-work.sh` 新增 `--session <id|name>` 選填參數，允許指定 AI CLI session
- `wt-work.sh` 新增 `--agent gemini` 支援（Gemini CLI）
- `wt-work.sh` resume path 強制執行 `/opsx:apply`（原本只有 new path 才執行）
- `wt-resume.sh` 新增 `--session <id|name>` 選填參數
- `wt-resume.sh` 新增 `--agent gemini` 支援（Gemini CLI）
- `wt-resume.sh` 無 `--session` 時改為顯示清單（Claude/Copilot），不再自動帶入 session name
- Zsh completion `_wt` 更新：新增 `wt-work`、`--session`、`gemini` agent 補全
- `install.sh` 更新：安裝 `wt-work`（取代 `wt-new`），舊版本印警告
- `docs/workflow/guide.md` 更新：反映命名變更與新參數說明

## Capabilities

### New Capabilities

- `wt-work`: `wt-new.sh` 重新命名後的腳本，語意為「進行 coding 工作」，新增 `--session` 參數與 Gemini 支援

### Modified Capabilities

- `wt-resume`: 新增 `--session` 選填參數與 Gemini 支援；無 `--session` 時行為改為顯示清單（不再自動帶 session name）
- `wt-zsh-completion`: `_wt` 補全更新，新增 `wt-work` 指令、`--session` 補全、`gemini` agent 選項

## Impact

- `scripts/workflow/wt-new.sh` → 重新命名為 `wt-work.sh`
- `scripts/workflow/wt-resume.sh` — 修改行為與參數
- `scripts/workflow/_wt` — 更新補全
- `scripts/workflow/install.sh` — 更新安裝目標
- `docs/workflow/guide.md` — 更新說明文件
- 使用者原本的 `wt-new` 指令需手動遷移至 `wt-work`

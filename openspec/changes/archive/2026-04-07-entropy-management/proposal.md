## Why

AI agent 持續開發會累積跨功能的「熵」——文件飄移、廢棄規格、template 與安裝層脫同步——這些問題在每次 feature 的個別文件更新中無法被察覺，需要週期性的系統審查機制。

## What Changes

- 新增 `/entropy-check` skill，可在任何安裝了此 harness 的專案中執行
- Skill 自動偵測專案類型（harness / openspec / standard），依 context 執行對應的審查
- 新增 PostToolUse hook（`entropy-counter`），在 OpenSpec 專案中以 archive 計數觸發審查提示
- 審查結果提供 auto-fix 選項（直接修補）或建立 OpenSpec change 處理結構性問題

## Capabilities

### New Capabilities

- `entropy-check`: 週期性健康審查 skill，依 context 執行 3 類共 7 項審查（通用審查 U1-U3、OpenSpec 審查 O1-O3、harness 專用審查 H1），輸出 findings 與決策選單
- `entropy-counter-hook`: PostToolUse hook，監聽 `openspec archive` 事件，計數達到閾值時在終端機顯示審查提示，支援 Claude Code 與 Gemini CLI

### Modified Capabilities

<!-- 無現有 spec 需要修改 -->

## Impact

- `template/common/skills/entropy-check/SKILL.md`：新增（安裝後複製到 `.claude/skills/`）
- `scripts/workflow/entropy-counter/hook.sh`：新增
- `scripts/workflow/entropy-counter/install.sh`：新增
- `scripts/workflow/entropy-counter/uninstall.sh`：新增
- `scripts/workflow/install.sh`：新增 entropy-counter hook 安裝步驟
- `AGENTS.md`：新增 entropy-check skill 條目
- `openspec/.entropy-state`：runtime watermark 檔案（不納入版控）

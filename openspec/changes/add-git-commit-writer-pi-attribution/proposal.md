# Proposal

## Why

`git-commit-writer` 與 `openspec-commit` 禁止從環境變數推定模型，以免在 Claude Code、Codex 用到過期或無關的值。
但 Pi 不在 system prompt 寫出模型名稱，而是在每個 shell 指令開始時注入 `PI_PROVIDER`、`PI_MODEL`、`PI_REASONING_LEVEL`，
官方文件要求以這些變數回答「目前用哪個模型」。照現行規則，在 Pi 中 commit 一律省略 `AI-Assisted-By`（`add-pi-handoff-agent`
的規劃 commit 就發生過，事後以 amend 補上），漏記一個其實可以確認的模型。

## What Changes

- **Pi 例外**：在 Pi 的 root session 中（`PI_CODING_AGENT=true` 且沒有 `PI_SUBAGENT_PARENT_SESSION`），目前模型取自 commit 當下的
  `PI_MODEL`，原樣記錄模型 ID（例如 `claude-opus-5-5`），不加 provider。這是 Pi 提供的 runtime 狀態，不算推定。
- **subagent 不適用**：在 Pi subagent 中 `PI_MODEL` 是 subagent 自己的模型，不得作為 root-session attribution；
  只能沿用呼叫端傳入的 `assisting_model`，沒有就省略並回報。
- **其他工具維持禁止**：Claude Code、Codex、Antigravity 仍不得從環境變數推定模型；即使環境中剛好有 `PI_MODEL`
  （例如從 Pi 開出的其他工具），也不得使用。
- **工具名稱**：Pi 的 `tool_name` 為 `Pi`；`Co-Authored-By: Pi`，不附 email（沿用未對應工具的規則，明確列出以免寫成其他名稱）。
- **`openspec-commit`**：解析 attribution 時接受 `Pi` 為 root-session 工具並套用同一個例外，再交給可攜的 `git-commit-writer` skill。
- 不變：使用者提供的模型名稱優先、模型切換後用當下模型、未知時省略並回報、`assisting_model` 不影響 runtime；
  Claude 與 Codex 的 `git-commit-writer-agent` 定義不變（它們不在 Pi 中執行）。

範圍外：`github-pr`、`github-issue` 的 Author 區塊也有相同的環境變數禁止與 Pi Session ID 問題，另行處理。

支援的 AI CLI：Claude Code、Codex、Antigravity（行為不變）、Pi（新增例外）。本 change 不涉及 hook。

驗收條件：

- 在 Pi root session 以 `git-commit-writer` commit，trailer 為 `Co-Authored-By: Pi` 與 `AI-Assisted-By: <PI_MODEL 的值>`。
- 在 Pi 中用 `/model` 換模型後再 commit，記錄的是新模型。
- 使用者已提供模型名稱時，以使用者提供的為準。
- 在 Pi subagent 中執行且呼叫端沒有傳入 `assisting_model` 時，省略 `AI-Assisted-By` 並回報，不使用 subagent 的 `PI_MODEL`。
- 在 Claude Code、Codex 中即使環境有 `PI_MODEL` 也不使用；現有的 attribution 行為與測試不變。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `git-commit-writer`: 模型身分的解析加入 Pi root session 的例外與 subagent 限制；Pi 的工具名稱與 trailer。
- `openspec-commit`: commit 步驟解析 attribution 時接受 Pi 並套用相同例外。

## Impact

- 指令文件：`template/common/skills/git-commit-writer/SKILL.md`、`template/common/skills/openspec-commit/SKILL.md`
  （安裝後同步到 `.claude/skills/`、`.agents/skills/`）。
- 測試：`tests/test_openspec_commit.sh`（文字錨點）、`tests/acceptance/git-commit-writer.md`（新增 Pi 案例）。
- 文件：`docs/skills/git-commit-writer.md`、`docs/workflow/commit.md`、`AGENTS.md` 的 git-commit-writer 說明。
- 不影響：`.claude/agents/`、`.codex/agents/` 的 `git-commit-writer-agent`。

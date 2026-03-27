## Why

開發過程中，git commit 格式化是機械化的重複工作，卻佔用高成本 model（Sonnet）的 token。將這個步驟抽出為獨立 skill，可在更便宜的 model（Haiku/GPT-5 mini/Gemini Flash）上執行，並讓它可跨工具獨立呼叫。

## What Changes

- 新增 `git-commit-writer` slash command skill（安裝至三個位置）
- `openspec-commit` Step 5 改為呼叫 `git-commit-writer`；在 Claude Code 中透過 `Agent(model="haiku")` dispatch
- 更新 `docs/commit-feature-workflow.md` 標注新 skill

## Capabilities

### New Capabilities

- `git-commit-writer`: 獨立的 Conventional Commits 格式化與執行 skill。偵測 openspec change 時加入 scope，無 change 時省略。直接執行，不需要確認。

### Modified Capabilities

- `openspec-commit`: Step 5 改為呼叫 git-commit-writer，不再自行產生 commit。

## Impact

- `template/common/skills/git-commit-writer/SKILL.md`（新建）
- `.claude/skills/git-commit-writer/SKILL.md`（新建）
- `.agent/skills/git-commit-writer/SKILL.md`（新建）
- `template/common/skills/openspec-commit/SKILL.md`（修改 Step 5）
- `.claude/skills/openspec-commit/SKILL.md`（修改 Step 5）
- `.agent/skills/openspec-commit/SKILL.md`（修改 Step 5）
- `docs/commit-feature-workflow.md`（更新）

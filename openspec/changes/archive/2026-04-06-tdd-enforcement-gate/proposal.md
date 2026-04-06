## Why

AI agents 在實作階段（opsx:apply）的測試行為不穩定：有時跳過 TDD、有時只寫單一測試、有時測試內容不足。目前缺乏機械性關卡強制執行，且 TDD 規則未對所有 AI 工具（Claude Code / GitHub Copilot CLI）一致可見。

## What Changes

- 新增 TDD 強制規則檔，讓 Claude Code 與 GitHub Copilot CLI 在每個 session 自動載入
- 更新 `tasks.md` 格式，每個 task 加入明確的測試要求欄位
- 新增輕量 pre-commit hook（Python: pytest / Node: npm test），測試失敗擋住 commit
- 更新 `template/common/` 與 `template/python/`、`template/node/`，讓其他專案可透過 install.sh 一鍵套用
- 更新 `scripts/skills/install.sh`，安裝時同步安裝 git hooks

## Capabilities

### New Capabilities

- `tdd-enforcement-rules`: 多工具 TDD 強制規則（Claude Code + GitHub Copilot CLI），session 自動載入，不依賴任何 skill
- `pre-commit-quality-gate`: 輕量 pre-commit hook，偵測 source 檔案變更後執行測試，失敗擋住 commit（Python: pytest / Node: npm test）

### Modified Capabilities

- `template-profile-structure`: 新增 tdd-enforcement-rules 至 common profile，新增 pre-commit hook 至 python/node profile，並更新 install.sh 安裝邏輯以包含 git hooks

## Impact

- `template/common/.claude/rules/` — 新增 tdd-enforcement.md
- `template/common/.github/instructions/` — 新增 tdd-enforcement.md
- `template/python/hooks/pre-commit` — 更新為執行 pytest 的 gate hook
- `template/node/hooks/pre-commit` — 更新為執行 npm test 的 gate hook
- `scripts/skills/install.sh` — 新增 git hook 安裝邏輯
- OpenSpec tasks.md schema（建議）— task 格式加入測試要求欄位

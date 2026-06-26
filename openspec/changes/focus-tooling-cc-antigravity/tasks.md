## 1. 內容清理（移除 Copilot / Codex / Gemini CLI）

- [x] 1.1 重寫 `template/common/.claude/rules/multi-tool-compatibility.md` → 只 Claude Code + Antigravity；env 偵測改 `CLAUDE_PROJECT_DIR → PWD`。
- [x] 1.2 同步重寫專案根 `.claude/rules/multi-tool-compatibility.md`（同上）。
- [x] 1.3 更新專案根 `AGENTS.md`：工具清單（行 ~32-38）與模型提及（行 ~158、181）移除 Gemini/Copilot/Codex。
- [x] 1.4 `template/common/skills/entropy-check/SKILL.md`：移除 `$GEMINI_PROJECT_DIR` 分支（PROJECT_ROOT 改 `CLAUDE_PROJECT_DIR → PWD`）。
- [x] 1.5 `template/common/skills/openspec-commit/SKILL.md`：移除 "Copilot CLI" 字樣。
- [x] 1.6 `template/common/skills/git-commit-writer/SKILL.md`：移除 Gemini 範例行，保留自我標記原則與 Claude 範例。
- [x] 1.7 刪除 `template/common/.github/instructions/` 與 `template/python/.github/instructions/`。
  - 測試要求：`grep -rniE 'gemini|copilot|codex|GEMINI_PROJECT_DIR' template/ .claude/rules/ AGENTS.md` 僅剩允許的自我標記語境（無第三方工具假設）。

## 2. 修好 Antigravity 接線（install.sh + 目錄統一）

- [x] 2.1 template `common/.agents/` 改名為 `common/.agent/`（含 `workflows/opsx-commit.md`）。
- [x] 2.2 `install.sh`：移除 `.github` 相關（行 91 mkdir 的 `.github`、行 94、行 113）。
- [x] 2.3 `install.sh`：`.agents`→`.agent` 單數統一（skills 行 88、`.agent` sync 行 93 指向真實來源 `$COMMON/.agent`，並 sync `.agent/workflows/`）。
- [x] 2.4 `install.sh`：安裝 rules 後，把 `.claude/rules/*.md` 扁平 `rsync` 一份到 `$TARGET/.agent/rules/`（common 與每個 profile 都要）。
  - 測試要求：見第 3 節煙霧測試。

## 3. 驗證

- [x] 3.1 殘留檢查：`grep -rniE 'gemini|copilot|codex|\.github/instructions' template/ scripts/skills/install.sh .claude/rules/ AGENTS.md` 無第三方工具殘留。
- [x] 3.2 安裝煙霧測試：在暫存 git repo 跑 `install.sh python`，確認：
  - `.agent/rules/` 有扁平規則 markdown（含 common + python）
  - `.claude/rules/` 同樣有規則
  - `.agent/workflows/` 非空
  - 無 `.github/instructions/` 產生
- [x] 3.3 `openspec validate focus-tooling-cc-antigravity` 通過。

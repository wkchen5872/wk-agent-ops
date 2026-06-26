## Why

專案已停用 GitHub Copilot CLI、Codex 與 Gemini CLI，只保留 **Claude Code + Antigravity**。但目前 rules / docs / skills / install.sh 仍處處假設那些工具，且 Antigravity 的接線是壞的：

- `install.sh:93` sync `$COMMON/.agent`（單數）但 template 實際是 `.agents/`（複數）→ no-op，`.agents/workflows/` 從未被複製。
- rules 只進 `.claude/rules/`，Antigravity 讀不到（Antigravity 讀**扁平** `.agent/rules/*.md`）。
- `.github/instructions/` 鏡像是給 Copilot 的，現已是死重量。

來源（Antigravity 規則載入）：官方 docs `antigravity.google/docs/rules-workflows`、Mete Atamel〈Customize Antigravity rules/workflows〉— workspace rules = `<ws>/.agent/rules/*.md`（單數、扁平、markdown）、workflows = `<ws>/.agent/workflows/`、跨工具 = 專案根 `AGENTS.md`（Antigravity 與 Claude Code 共讀）。

## What Changes

**A. 內容清理 — 移除 Copilot / Codex / Gemini CLI 假設**
- 重寫 `template/common/.claude/rules/multi-tool-compatibility.md` 與專案根 `.claude/rules/multi-tool-compatibility.md` → 只列 Claude Code + Antigravity；環境偵測改 `CLAUDE_PROJECT_DIR → PWD`（移除 `GEMINI_PROJECT_DIR`）。
- 更新專案根 `AGENTS.md`（工具清單 / 模型提及）移除 Gemini / Copilot / Codex。
- `template/common/skills/entropy-check/SKILL.md`：移除 `$GEMINI_PROJECT_DIR` 偵測分支。
- `template/common/skills/openspec-commit/SKILL.md`：移除 "Copilot CLI" 字樣（保留 Claude Code + Antigravity 路徑）。
- `template/common/skills/git-commit-writer/SKILL.md`：移除 Gemini 範例行（保留「印出自己當下的模型名＋版本」原則與 Claude 範例 — 此自我標記為刻意設計）。
- 移除 `template/common/.github/instructions/` 與 `template/python/.github/instructions/`，以及 `install.sh` 對 `.github` 的 sync（行 91/94/113）。

**B. 修好 Antigravity 接線**
- `install.sh`：把已安裝的 rule 檔（common + profile 的 `.claude/rules/*.md`）**扁平複製**到 `$TARGET/.agent/rules/`。
- 統一 `.agents`（複數）→ `.agent`（單數，Antigravity 實際讀的路徑）：template 目錄改名、install.sh 對應行修正，並讓 `.agent/workflows/` 真正被 sync（修掉現有 no-op）。
- `AGENTS.md` 已是跨工具共讀，無需另複製。

## Capabilities

### New Capabilities
- `tooling-target-scope`: 規範本專案與其 template 只支援 Claude Code + Antigravity；rules 必須同時送達兩者的讀取路徑，且不得殘留其他工具假設。

### Modified Capabilities
<!-- 無既有 spec（openspec/specs/ 為空） -->

## Impact

- `scripts/skills/install.sh`（移除 .github、新增 `.agent/rules/` 扁平 emit、`.agents`→`.agent`）。
- `template/common/`：`.claude/rules/multi-tool-compatibility.md`、`skills/{entropy-check,openspec-commit,git-commit-writer}/SKILL.md`、`.agents/`→`.agent/`、刪 `.github/instructions/`。
- `template/python/`：刪 `.github/instructions/`。
- 專案根：`.claude/rules/multi-tool-compatibility.md`、`AGENTS.md`。
- 不影響既有已安裝專案的客製檔（install 多為 `rsync -a` 覆蓋同名來源檔；docs 仍 `--ignore-existing`）。
- 不動：supabase-migrations 規則、`make-conventions-language-agnostic` 的成果。

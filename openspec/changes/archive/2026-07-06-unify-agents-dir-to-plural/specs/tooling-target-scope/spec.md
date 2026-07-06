## MODIFIED Requirements

### Requirement: Rules 必須同時送達 Claude Code 與 Antigravity

`install.sh` SHALL 把安裝的規則檔同時放到 Claude Code 路徑（`.claude/rules/`）與扁平的
`.agents/rules/*.md`（複數 `.agents`，即較多 AGENTS.md-aware 工具讀取的目錄）。Workflows MUST
確實複製到 `.agents/workflows/`，不得因 `.agent`/`.agents` 命名不一致而成為 no-op。所有安裝路徑
一律使用複數 `.agents/`。

#### Scenario: 安裝後其他工具讀得到規則
- **WHEN** 在目標專案執行 `install.sh python`
- **THEN** `.agents/rules/` 內有扁平的規則 markdown（含 common 與 python profile 的規則），且 `.claude/rules/` 也有同一批規則
- **AND** 不產生任何單數 `.agent/` 目錄

#### Scenario: workflows 真正落地
- **WHEN** 安裝 common
- **THEN** `template` 內的 `.agents/workflows/*.md` 被複製到目標 `.agents/workflows/`（非空、非 no-op）

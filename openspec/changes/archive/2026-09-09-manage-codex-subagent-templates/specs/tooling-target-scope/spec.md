## MODIFIED Requirements

### Requirement: 工具範圍涵蓋 Claude Code、Codex 與 Antigravity

本專案的 project-owned portable skills SHALL 以 Claude Code、Codex 與
Antigravity 為三個主要使用者。`install.sh` SHALL 將自有 skills 安裝到
`.claude/skills/` 與複數 `.agents/skills/`，並 SHALL 將 project-owned Codex
custom-agent templates 安裝到 `.codex/agents/`。它 MUST NOT 複製或修改
OpenSpec 針對 provider 生成的 `.codex/skills/`、單數 `.agent/` artifacts，或
使用者維護的 `.codex/config.toml`。

#### Scenario: project-owned skill 安裝
- **WHEN** 安裝 common profile
- **THEN** 自有 skills 出現在 `.claude/skills/` 與 `.agents/skills/`
- **AND** project-owned Codex agents 出現在 `.codex/agents/`
- **AND** installer 不產生 `.agent/`

#### Scenario: OpenSpec provider artifacts 共存
- **WHEN** OpenSpec 為 Claude Code、Codex 或 Antigravity 生成原生整合
- **THEN** `.claude/commands/opsx/`、`.codex/skills/`、`.agent/skills/` 或
  `.agent/workflows/` 可與 project-owned 安裝內容共存
- **AND** wk-agent-ops 不直接維護那些生成內容
- **AND** wk-agent-ops 對 `.codex/` 的管理只限於 `.codex/agents/`

#### Scenario: portable workflow 說明 provider routing
- **WHEN** project-owned workflow 需要呼叫 OpenSpec action
- **THEN** 它以 `openspec-<action>-change` capability 名稱表達不變意圖
- **AND** 可說明 provider 原生 alias，但不得同時執行 capability 與 alias

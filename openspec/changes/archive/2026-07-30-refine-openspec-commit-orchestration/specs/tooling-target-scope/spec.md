## MODIFIED Requirements

### Requirement: 工具範圍涵蓋 Claude Code、Codex 與 Antigravity

本專案的 project-owned portable skills SHALL 以 Claude Code、Codex 與
Antigravity 為三個主要使用者。`install.sh` SHALL 繼續只將這些自有 skills
安裝到 `.claude/skills/` 與複數 `.agents/skills/`；它 MUST NOT 複製或修改
OpenSpec 針對 provider 生成的 `.codex/` 或單數 `.agent/` artifacts。

#### Scenario: project-owned skill 安裝
- **WHEN** 安裝 common profile
- **THEN** 自有 skills 出現在 `.claude/skills/` 與 `.agents/skills/`
- **AND** installer 不產生 `.codex/` 或 `.agent/`

#### Scenario: OpenSpec provider artifacts 共存
- **WHEN** OpenSpec 1.4.1 為 Claude Code、Codex 或 Antigravity 生成原生整合
- **THEN** `.claude/commands/opsx/`、`.codex/skills/`、`.agent/skills/` 或
  `.agent/workflows/` 可與 project-owned 安裝內容共存
- **AND** wk-agent-ops 不直接維護那些生成內容

#### Scenario: portable workflow 說明 provider routing
- **WHEN** project-owned workflow 需要呼叫 OpenSpec action
- **THEN** 它以 `openspec-<action>-change` capability 名稱表達不變意圖
- **AND** 可說明 provider 原生 alias，但不得同時執行 capability 與 alias

### Requirement: Rules 必須同時送達 Claude Code 與 Antigravity

`install.sh` SHALL 把 project-owned 規則檔放到 `.claude/rules/` 與複數
`.agents/rules/*.md`，並把 project-owned workflows 複製到
`.agents/workflows/`。單數 `.agent/` SHALL 保留給 OpenSpec 等 provider-native
generator，且 MUST NOT 由 wk-agent-ops installer 產生。

#### Scenario: 安裝後 shared root 讀得到規則
- **WHEN** 在乾淨目標專案執行 `install.sh python`
- **THEN** `.agents/rules/` 與 `.claude/rules/` 都包含安裝規則
- **AND** installer 不建立 `.agent/`

#### Scenario: project-owned workflows 真正落地
- **WHEN** 安裝 common
- **THEN** `template/common/.agents/workflows/*.md` 被複製到
  `.agents/workflows/`

## RENAMED Requirements

- FROM: `### Requirement: 工具範圍限定 Claude Code 與 Antigravity`
- TO: `### Requirement: 工具範圍涵蓋 Claude Code、Codex 與 Antigravity`

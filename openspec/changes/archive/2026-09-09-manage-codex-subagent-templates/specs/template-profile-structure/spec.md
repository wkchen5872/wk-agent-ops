## MODIFIED Requirements

### Requirement: Profile directory layout
`template/` SHALL 包含 `common/`、`python/`、`node/`、`jvm/` 與 `dotnet/` 子目錄作為 profile。新增的 `jvm` 與 `dotnet` profile MAY 只包含目前必要的語言規範或最小目錄標記，不得為未定義的 hook 預先建立 placeholder 行為。

#### Scenario: common profile 存在且包含 language-agnostic 內容
- **WHEN** 列出 `template/common/` 目錄
- **THEN** 包含 `skills/`、`.claude/commands/`、`.claude/rules/`、`.agents/workflows/`、`.codex/agents/`、`.github/instructions/`

#### Scenario: python profile 目錄存在
- **WHEN** 列出 `template/python/` 目錄
- **THEN** 包含 `.claude/rules/` 和 `hooks/` 子目錄

#### Scenario: node profile 目錄存在
- **WHEN** 列出 `template/node/` 目錄
- **THEN** 包含 `.claude/rules/` 和 `hooks/` 子目錄

#### Scenario: jvm profile 可被選擇
- **WHEN** installer 驗證 `template/jvm/`
- **THEN** 該 profile 目錄存在，且不要求尚未定義的 pre-commit hook

#### Scenario: dotnet profile 可被選擇
- **WHEN** installer 驗證 `template/dotnet/`
- **THEN** 該 profile 目錄存在，且不要求尚未定義的 pre-commit hook

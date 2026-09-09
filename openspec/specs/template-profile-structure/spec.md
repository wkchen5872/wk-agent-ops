# Spec: template-profile-structure

## Purpose

Defines the directory layout of the `template/` folder and the conventions for organising content across language profiles.

## Requirements

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

### Requirement: skills 只在 common 下維護
wk-agent-ops 自有 `skills/` SHALL 只在 `template/common/skills/` 維護，不在語言 profile 下重複。`testland/qa` mutation runner 與 triage MUST NOT vendoring 到任何 template profile，而由 installer 依 profile 交給 skills CLI 管理。

#### Scenario: skills 安裝路徑不因 profile 改變
- **WHEN** 執行任何 profile 的安裝
- **THEN** `common/skills/` 的自有內容永遠複製到 `.claude/skills/` 和 `.agents/skills/`

#### Scenario: template 不保存第三方 mutation skills
- **WHEN** 掃描 `template/common/skills/` 與各語言 profile
- **THEN** 不存在 `mutation-setup`、`mutation-check` 或四個 testland mutation runner/triage 的 vendored SKILL.md

### Requirement: profile 目錄的 hooks 子目錄
只有已定義語言 gate 的 profile `hooks/` SHALL 存放該語言的 git hook 腳本。Python 與 Node pre-commit hooks MUST 實際執行測試；JVM 與 .NET profile 在本 change 未定義通用 test command，因此 MUST NOT 建立不可靠的 placeholder pre-commit hook。

#### Scenario: hooks 目錄結構正確
- **WHEN** 列出 `template/python/hooks/` 或 `template/node/hooks/`
- **THEN** 包含至少 `pre-commit` 腳本

#### Scenario: Python pre-commit hook 執行 pytest
- **WHEN** 安裝 python profile 後執行 git commit
- **THEN** `.git/hooks/pre-commit` 執行 pytest，測試失敗擋住 commit

#### Scenario: Node pre-commit hook 執行 npm test
- **WHEN** 安裝 node profile 後執行 git commit
- **THEN** `.git/hooks/pre-commit` 執行 `npm test`，測試失敗擋住 commit

#### Scenario: JVM 或 .NET profile 不安裝 placeholder hook
- **WHEN** 只安裝 `jvm` 或 `dotnet` profile
- **THEN** profile 不因本 change 新增或覆寫 `.git/hooks/pre-commit`

### Requirement: common profile 包含 TDD 規則檔
`template/common/` SHALL 包含 `.claude/rules/tdd-enforcement.md` 和 `.github/instructions/tdd-enforcement.md`，讓安裝 common profile 的專案自動獲得 TDD 強制規則。

#### Scenario: 安裝 common profile 後 TDD 規則存在
- **WHEN** 執行 `bash install.sh`（common only）
- **THEN** 目標專案的 `.claude/rules/tdd-enforcement.md` 和 `.github/instructions/tdd-enforcement.md` 均存在

#### Scenario: TDD 規則檔與 multi-tool-compatibility.md 並列
- **WHEN** 列出目標專案的 `.claude/rules/`
- **THEN** 包含 `tdd-enforcement.md`、`multi-tool-compatibility.md`

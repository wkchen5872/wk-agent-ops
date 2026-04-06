# Spec: template-profile-structure

## Purpose

Defines the directory layout of the `template/` folder and the conventions for organising content across profiles (`common`, `python`, `node`, etc.).

## Requirements

### Requirement: Profile directory layout
`template/` 必須包含 `common/`、`python/`、`node/` 三個子目錄作為 profile。

#### Scenario: common profile 存在且包含 language-agnostic 內容
- **WHEN** 列出 `template/common/` 目錄
- **THEN** 包含 `skills/`、`.claude/commands/`、`.claude/rules/`、`.agent/workflows/`、`.github/instructions/`

#### Scenario: python profile 目錄存在
- **WHEN** 列出 `template/python/` 目錄
- **THEN** 包含 `.claude/rules/` 和 `hooks/` 子目錄

#### Scenario: node profile 目錄存在
- **WHEN** 列出 `template/node/` 目錄
- **THEN** 包含 `.claude/rules/` 和 `hooks/` 子目錄

### Requirement: skills 只在 common 下維護
`template/skills/` 移至 `template/common/skills/`，不在 python / node profile 下重複。

#### Scenario: skills 安裝路徑不因 profile 改變
- **WHEN** 執行任何 profile 的安裝
- **THEN** `common/skills/` 的內容永遠複製到 `.claude/skills/` 和 `.agent/skills/`

### Requirement: profile 目錄的 hooks 子目錄
每個語言 profile 的 `hooks/` 存放該語言的 git hook 腳本。Node pre-commit hook 必須實際執行測試，而非 placeholder。

#### Scenario: hooks 目錄結構正確
- **WHEN** 列出 `template/python/hooks/` 或 `template/node/hooks/`
- **THEN** 包含至少 `pre-commit` 腳本（即使是佔位檔）

#### Scenario: Python pre-commit hook 執行 pytest
- **WHEN** 安裝 python profile 後執行 git commit
- **THEN** `.git/hooks/pre-commit` 執行 pytest，測試失敗擋住 commit

#### Scenario: Node pre-commit hook 執行 npm test
- **WHEN** 安裝 node profile 後執行 git commit
- **THEN** `.git/hooks/pre-commit` 執行 `npm test`，測試失敗擋住 commit（非 placeholder）

### Requirement: common profile 包含 TDD 規則檔
`template/common/` 必須包含 `.claude/rules/tdd-enforcement.md` 和 `.github/instructions/tdd-enforcement.md`，讓安裝 common profile 的專案自動獲得 TDD 強制規則。

#### Scenario: 安裝 common profile 後 TDD 規則存在
- **WHEN** 執行 `bash install.sh`（common only）
- **THEN** 目標專案的 `.claude/rules/tdd-enforcement.md` 和 `.github/instructions/tdd-enforcement.md` 均存在

#### Scenario: TDD 規則檔與 multi-tool-compatibility.md 並列
- **WHEN** 列出目標專案的 `.claude/rules/`
- **THEN** 包含 `tdd-enforcement.md`、`multi-tool-compatibility.md`、`openspec-commits.md`

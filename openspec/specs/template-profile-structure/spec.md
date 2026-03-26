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
每個語言 profile 的 `hooks/` 存放該語言的 git hook 腳本。

#### Scenario: hooks 目錄結構正確
- **WHEN** 列出 `template/python/hooks/` 或 `template/node/hooks/`
- **THEN** 包含至少 `pre-commit` 腳本（即使是佔位檔）

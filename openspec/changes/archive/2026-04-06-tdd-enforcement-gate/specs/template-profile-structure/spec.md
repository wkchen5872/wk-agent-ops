## ADDED Requirements

### Requirement: common profile 包含 TDD 規則檔
`template/common/` 必須包含 `.claude/rules/tdd-enforcement.md` 和 `.github/instructions/tdd-enforcement.md`，讓安裝 common profile 的專案自動獲得 TDD 強制規則。

#### Scenario: 安裝 common profile 後 TDD 規則存在
- **WHEN** 執行 `bash install.sh`（common only）
- **THEN** 目標專案的 `.claude/rules/tdd-enforcement.md` 和 `.github/instructions/tdd-enforcement.md` 均存在

#### Scenario: TDD 規則檔與 multi-tool-compatibility.md 並列
- **WHEN** 列出目標專案的 `.claude/rules/`
- **THEN** 包含 `tdd-enforcement.md`、`multi-tool-compatibility.md`、`openspec-commits.md`

## MODIFIED Requirements

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

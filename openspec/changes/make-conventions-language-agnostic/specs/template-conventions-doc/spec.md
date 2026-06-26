## ADDED Requirements

### Requirement: 出貨的 conventions 範本必須語言中立

`template/common/docs/` 內隨所有 profile 出貨的 conventions 範本 SHALL 為語言中立（language-agnostic）：凡涉及命名、除錯輸出、文件註解、null 處理等語言專屬規範，MUST 以「依該語言慣例」或多語言對照方式呈現，且 MUST NOT 與任何 profile 出貨的語言專屬 rule（如 python profile 的 `pytest_testing_style_guide.md`）相矛盾。

#### Scenario: Python 專案安裝後命名規範不矛盾
- **WHEN** 使用者執行 `install.sh python` 並讀取產生的 `docs/conventions.md`
- **THEN** 命名規範指出 Python 使用 `snake_case`（函式/變數/檔名），與 `.claude/rules/pytest_testing_style_guide.md` 一致，不出現「一律 camelCase」這類無條件規則

#### Scenario: 除錯輸出規範語言中立
- **WHEN** 讀取 `conventions.md` 的 Prohibited Patterns
- **THEN** 禁止 production code 留除錯輸出以語言中立方式表達（同時涵蓋 Python `print` 與 JS `console.log`），而非僅針對單一語言

#### Scenario: 既有安裝不被覆蓋
- **WHEN** 目標專案 `docs/conventions.md` 已存在且經客製
- **THEN** 重跑 `install.sh` 不覆蓋該檔（`rsync --ignore-existing`），使用者客製內容保留

# Spec: pre-commit-quality-gate

## Purpose

Defines the pre-commit hooks that enforce test execution before each commit, ensuring tests pass for Python and Node projects as part of the TDD enforcement gate.

## Requirements

### Requirement: Python 專案的 pre-commit 測試關卡
`template/python/hooks/pre-commit` 必須在有 `.py` 檔案變更時執行 pytest，測試失敗則擋住 commit。

#### Scenario: Python 檔案有變更時執行 pytest
- **WHEN** git commit 觸發 pre-commit hook，且有 `.py` 檔案在 staged changes 中
- **THEN** 執行 pytest，若任何測試失敗則 exit code 非 0，commit 被擋住

#### Scenario: 無 Python 檔案變更時跳過測試
- **WHEN** git commit 觸發 pre-commit hook，staged changes 中只有 `.md`、`.yaml` 等非 Python 檔案
- **THEN** hook 直接通過，不執行 pytest

#### Scenario: tests/ 目錄不存在時允許 commit
- **WHEN** git commit 觸發 pre-commit hook，專案無 `tests/` 目錄
- **THEN** hook 顯示提示訊息並允許 commit（exit 0）

### Requirement: Node 專案的 pre-commit 測試關卡
`template/node/hooks/pre-commit` 必須在有 `.js`、`.ts`、`.jsx`、`.tsx` 檔案變更時執行 `npm test`，測試失敗則擋住 commit。

#### Scenario: Node 檔案有變更時執行 npm test
- **WHEN** git commit 觸發 pre-commit hook，且有 `.js`、`.ts`、`.jsx`、`.tsx` 檔案在 staged changes 中
- **THEN** 執行 `npm test`，若測試失敗（exit code 非 0）則 commit 被擋住

#### Scenario: 無 Node 檔案變更時跳過測試
- **WHEN** git commit 觸發 pre-commit hook，staged changes 中只有非 JS/TS 檔案
- **THEN** hook 直接通過，不執行 npm test

#### Scenario: package.json 不存在時跳過測試
- **WHEN** git commit 觸發 pre-commit hook，專案根目錄無 `package.json`
- **THEN** hook 顯示提示訊息並允許 commit（exit 0）

### Requirement: 測試失敗時提供明確錯誤訊息
Hook 失敗時 SHALL 輸出測試失敗的原因到 stderr，讓開發者知道哪裡出錯。

#### Scenario: 測試失敗顯示錯誤詳情
- **WHEN** pytest 或 npm test 失敗
- **THEN** hook 輸出失敗原因到終端（stderr），包含測試命令的輸出

### Requirement: Hook 不強制覆蓋率百分比
Hook SHALL 只驗證測試是否通過，不強制 coverage 百分比，避免 gate 過嚴阻礙開發。

#### Scenario: 測試通過但覆蓋率低時允許 commit
- **WHEN** 所有測試通過但覆蓋率低於 80%
- **THEN** hook 通過，commit 成功

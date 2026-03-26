# Spec: install-profile-cli

## Purpose

Defines the CLI interface and runtime behaviours of `install.sh` — the script used to install template profiles into a target project.

## Requirements

### Requirement: 預設只裝 common
不帶參數執行 `install.sh` 時，只安裝 `template/common/` 的內容。

#### Scenario: 無參數執行
- **WHEN** `bash install.sh`
- **THEN** `common/` 內容複製到目標專案，python / node 內容不被安裝

### Requirement: profile 參數選擇安裝內容
透過位置參數指定要額外安裝的 profile。

#### Scenario: 指定單一 profile
- **WHEN** `bash install.sh python`
- **THEN** `common/` + `python/` 內容皆安裝到目標專案

#### Scenario: 指定多個 profile
- **WHEN** `bash install.sh python node`
- **THEN** `common/` + `python/` + `node/` 內容皆安裝

#### Scenario: 未知 profile 名稱
- **WHEN** `bash install.sh ruby`
- **THEN** 印出錯誤訊息，列出可用 profile，exit code 非零

### Requirement: skills 複製到兩個目的地
`common/skills/` 的內容必須同時複製到 `.claude/skills/` 和 `.agent/skills/`。

#### Scenario: skills 安裝
- **WHEN** 安裝任何 profile
- **THEN** `common/skills/<name>/` 出現在目標的 `.claude/skills/<name>/` 和 `.agent/skills/<name>/`

### Requirement: hooks 安裝到 .git/hooks/ 並設定執行權限
語言 profile 的 `hooks/` 腳本複製到目標專案的 `.git/hooks/`。

#### Scenario: python profile 的 pre-commit hook 安裝
- **WHEN** `bash install.sh python`
- **THEN** `template/python/hooks/pre-commit` 複製到 `TARGET/.git/hooks/pre-commit`，且有執行權限

#### Scenario: 目標不是 git repo
- **WHEN** TARGET 目錄下沒有 `.git/`
- **THEN** 印出錯誤訊息並中止安裝

### Requirement: 顯示安裝目標與結果
install.sh 執行時需顯示 source、target 和安裝的 profile 清單。

#### Scenario: 安裝完成輸出
- **WHEN** 安裝成功
- **THEN** 顯示已安裝的 profile 名稱與目標路徑

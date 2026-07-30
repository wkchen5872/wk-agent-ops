# Spec: install-profile-cli

## Purpose

Defines the CLI interface and runtime behaviours of `install.sh` — the script used to install template profiles into a target project.

## Requirements

### Requirement: 預設只裝 common
不帶參數執行 `install.sh` 時，腳本 SHALL 只安裝 `template/common/` 的內容。

#### Scenario: 無參數執行
- **WHEN** `bash install.sh`
- **THEN** `common/` 內容複製到目標專案，python / node 內容不被安裝

### Requirement: profile 參數選擇安裝內容
`install.sh` SHALL 透過位置參數接受要額外安裝的 profile。

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
`common/skills/` 的內容 SHALL 同時複製到 `.claude/skills/` 和 `.agents/skills/`。

#### Scenario: skills 安裝
- **WHEN** 安裝任何 profile
- **THEN** `common/skills/<name>/` 出現在目標的 `.claude/skills/<name>/` 和 `.agents/skills/<name>/`

### Requirement: hooks 安裝到 .git/hooks/ 並設定執行權限
語言 profile 的 `hooks/` 腳本 SHALL 複製到目標專案的 `.git/hooks/`。

#### Scenario: python profile 的 pre-commit hook 安裝
- **WHEN** `bash install.sh python`
- **THEN** `template/python/hooks/pre-commit` 複製到 `TARGET/.git/hooks/pre-commit`，且有執行權限

#### Scenario: 目標不是 git repo
- **WHEN** TARGET 目錄下沒有 `.git/`
- **THEN** 印出錯誤訊息並中止安裝

### Requirement: 顯示安裝目標與結果
install.sh 執行時 SHALL 顯示 source、target 和安裝的 profile 清單。

#### Scenario: 安裝完成輸出
- **WHEN** 安裝成功
- **THEN** 顯示已安裝的 profile 名稱與目標路徑

### Requirement: Managed vs seed doc ownership
install.sh SHALL classify each shipped doc by ownership. **Managed** docs (shared upstream
standards) SHALL be overwritten on every install so downstream repos pull updates by
re-running install.sh. **Seed** docs (project-fill files) SHALL be copied only if absent and
never overwritten. `docs/agent-protocol.md` and `docs/okf-conventions.md` are managed;
`docs/architecture.md` and `docs/conventions.md` are seed. Doc paths SHALL NOT change.

#### Scenario: Managed doc is overwritten on re-install
- **WHEN** a target already has a modified `docs/agent-protocol.md` and install.sh runs
- **THEN** `docs/agent-protocol.md` is overwritten with the template's current version

#### Scenario: Seed doc is preserved on re-install
- **WHEN** a target already has a `docs/architecture.md` with project content and install.sh runs
- **THEN** `docs/architecture.md` is left unchanged (not overwritten)

#### Scenario: First install seeds both kinds
- **WHEN** install.sh runs against a target with no `docs/`
- **THEN** both managed and seed docs are created from the template

### Requirement: Managed files carry a do-not-edit banner
Every managed doc shipped by install.sh SHALL carry a banner at the top indicating it is
managed by wk-agent-ops and that local edits are overwritten on install, so downstream editors
are not surprised by clobbered changes.

#### Scenario: Managed doc banner present
- **WHEN** a managed doc (e.g. `docs/agent-protocol.md`) is read
- **THEN** its first lines state it is managed upstream and that edits will be overwritten on install

#### Scenario: Seed doc has no managed banner
- **WHEN** a seed doc (e.g. `docs/architecture.md`) is read
- **THEN** it does not carry the managed banner (it is project-owned)

### Requirement: AGENTS.md remains copy-once
install.sh SHALL continue to copy `AGENTS.md` only when absent in the target, preserving the
downstream project's own additions. Protocol updates reach the project through the managed
`docs/agent-protocol.md`, not by overwriting `AGENTS.md`.

#### Scenario: Existing AGENTS.md is preserved but protocol doc updates
- **WHEN** a target already has an `AGENTS.md` and install.sh runs
- **THEN** `AGENTS.md` is not overwritten
- **AND** `docs/agent-protocol.md` is (re)written to the current template version

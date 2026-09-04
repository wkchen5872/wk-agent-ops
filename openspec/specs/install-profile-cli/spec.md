# Spec: install-profile-cli

## Purpose

Defines the CLI interface and runtime behaviours of `install.sh` — the script used to install template profiles into a target project.

## Requirements

### Requirement: 預設只裝 common
不帶參數執行 `install.sh` 時，腳本 SHALL 只安裝 `template/common/` 的內容。

#### Scenario: 無參數執行
- **WHEN** `bash install.sh`
- **THEN** `common/` 內容複製到目標專案，語言 profile 內容與 mutation skills 不被安裝

### Requirement: profile 參數選擇安裝內容
`install.sh` SHALL 透過位置參數接受要額外安裝的 `python`、`node`、`jvm` 或 `dotnet` profile。

#### Scenario: 指定單一 profile
- **WHEN** `bash install.sh python`
- **THEN** `common/` + `python/` 內容皆安裝，並選擇 Python 對應的第三方 mutation skills

#### Scenario: 指定多個 profile
- **WHEN** `bash install.sh python node`
- **THEN** `common/` + `python/` + `node/` 內容皆安裝，並選擇兩個語言 runner 與一個共用 triage

#### Scenario: 指定 JVM profile
- **WHEN** `bash install.sh jvm`
- **THEN** `common/` + `jvm/` 內容皆安裝，並選擇 PIT 對應的第三方 mutation skills

#### Scenario: 指定 .NET profile
- **WHEN** `bash install.sh dotnet`
- **THEN** `common/` + `dotnet/` 內容皆安裝，並選擇 Stryker.NET 對應的第三方 mutation skills

#### Scenario: 未知 profile 名稱
- **WHEN** `bash install.sh ruby`
- **THEN** 印出錯誤訊息，列出可用 profile，exit code 非零，且不呼叫 third-party installer

### Requirement: skills 複製到兩個目的地
`common/skills/` 中由 wk-agent-ops 維護的 skills SHALL 同時複製到 `.claude/skills/` 和 `.agents/skills/`。第三方 mutation skills MUST NOT 放入或由 `common/skills/` 複製，必須經 skills CLI 以 project-local canonical install 與 Provider links 管理。

#### Scenario: skills 安裝
- **WHEN** 安裝任何 profile
- **THEN** `common/skills/<name>/` 出現在目標的 `.claude/skills/<name>/` 和 `.agents/skills/<name>/`

#### Scenario: 第三方 mutation skills 不納入 template copy
- **WHEN** installer 安裝語言 profile
- **THEN** runner 與 triage 來自 `testland/qa` 的 project-local install，而不是 template 中的複本

#### Scenario: legacy 自有 mutation skills 清理
- **WHEN** target 中存在舊 installer 產生的 `.claude/skills/mutation-setup`、`.agents/skills/mutation-setup`、`.claude/skills/mutation-check` 或 `.agents/skills/mutation-check`
- **THEN** installer 精確移除這四個 legacy 目標且不刪除其他 skill 目錄

### Requirement: 語言 profile 自動安裝第三方 mutation skills
當使用者選擇 `node`、`python`、`jvm` 或 `dotnet` profile 時，installer SHALL 在 target repository 以 skills CLI 的 project scope，一次安裝對應 `testland/qa` runner 與去重後的 `mutant-survival-triage`，並選擇 Claude Code、Codex 與 Antigravity。installer MUST 保持預設 link mode，MUST NOT 使用 global scope 或 copy mode，也 MUST NOT 修改目標專案的 application manifest、lockfile 或 mutation runner 設定。

#### Scenario: 安裝 node profile
- **WHEN** 使用者執行 `bash install.sh node`
- **THEN** installer 對 target project 安裝 `stryker-mutation` 與 `mutant-survival-triage`，並選擇三個支援 Provider

#### Scenario: 安裝多個 profile
- **WHEN** 使用者執行 `bash install.sh python node`
- **THEN** installer 在同一次 third-party install 中選擇 `mutmut-mutation`、`stryker-mutation` 與一個 `mutant-survival-triage`

#### Scenario: common-only 不安裝 mutation skills
- **WHEN** 使用者不帶 profile 執行 installer
- **THEN** installer 不呼叫 skills CLI，也不猜測目標專案語言

### Requirement: 第三方 skill 安裝失敗時提供可重播提示
installer SHALL 在執行前檢查 `npx`，並以 third-party command 的 exit code 判定安裝是否成功。缺少 `npx` 或 command 失敗時，installer MUST 清楚列出未安裝 skills 與可在 target repository 重播的完整命令，MUST NOT 自動改用 global/copy fallback，且整體命令 MUST 以非零結束。

#### Scenario: npx 不存在
- **WHEN** 使用者安裝語言 profile 但 PATH 中沒有 `npx`
- **THEN** installer 不執行第三方安裝，顯示對應 `npx skills add` 命令並以非零結束

#### Scenario: skills CLI 執行失敗
- **WHEN** third-party install 因網路、registry、repository 或 skill 名稱問題失敗
- **THEN** installer 保留原始錯誤、顯示相同的可重播命令與未完成 skills，並以非零結束

#### Scenario: 失敗後重跑
- **WHEN** 使用者修正環境後以相同 profiles 重跑 installer
- **THEN** common/profile 檔案同步與 third-party skill 安裝可安全重複執行，不產生重複 runner 或 triage

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
never overwritten. `docs/agent-protocol.md`、`docs/okf-conventions.md` 與
`docs/mutation-testing.md` are managed; `docs/architecture.md` and
`docs/conventions.md` are seed. Doc paths SHALL NOT change.

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

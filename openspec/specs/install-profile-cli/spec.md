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
install.sh SHALL classify shipped files as managed or seed using target-root-relative paths.
Managed files SHALL be overwritten on each install; seed files SHALL be copied only if absent.
Managed files MAY live outside `docs/`. Missing parents SHALL be created; installed paths SHALL NOT change.
Managed: `docs/agent-protocol.md`, `docs/okf-conventions.md`, `docs/mutation-testing.md`,
`docs/openspec-workflow.md`, `work-items/AGENTS.md`.
Seed: `docs/architecture.md`, `docs/conventions.md`.

#### Scenario: Managed doc is overwritten on re-install
- **WHEN** a target already has a modified `docs/agent-protocol.md` and install.sh runs
- **THEN** `docs/agent-protocol.md` is overwritten with the template's current version

#### Scenario: Seed doc is preserved on re-install
- **WHEN** a target already has a `docs/architecture.md` with project content and install.sh runs
- **THEN** `docs/architecture.md` is left unchanged (not overwritten)

#### Scenario: First install seeds both kinds
- **WHEN** install.sh runs against a target with no `docs/`
- **THEN** both managed and seed docs are created from the template

#### Scenario: Managed file outside docs/ is created and refreshed
- **WHEN** install.sh runs against a target with no `work-items/` directory, and runs again after
  the installed `work-items/AGENTS.md` has been edited locally
- **THEN** the first run creates `work-items/AGENTS.md` from the template
- **AND** the second run overwrites it with the template's current version

#### Scenario: Managed delivery does not touch records
- **WHEN** a target contains `work-items/WI-20260101-topic/` with record files and install.sh runs
- **THEN** only `work-items/AGENTS.md` is written
- **AND** no file inside any `work-items/WI-*/` directory is created, modified, or removed

### Requirement: Managed files carry a do-not-edit banner
Every managed file shipped by install.sh SHALL carry a banner at the top indicating it is
managed by wk-agent-ops and that local edits are overwritten on install, so downstream editors
are not surprised by clobbered changes.

#### Scenario: Managed doc banner present
- **WHEN** a managed doc (e.g. `docs/agent-protocol.md`) is read
- **THEN** its first lines state it is managed upstream and that edits will be overwritten on install

#### Scenario: Seed doc has no managed banner
- **WHEN** a seed doc (e.g. `docs/architecture.md`) is read
- **THEN** it does not carry the managed banner (it is project-owned)

#### Scenario: Managed file outside docs/ carries the banner
- **WHEN** `work-items/AGENTS.md` is read in the template or in an installed target
- **THEN** it carries the same managed banner

### Requirement: AGENTS.md remains copy-once
install.sh SHALL continue to copy `AGENTS.md` only when absent in the target, preserving the
downstream project's own additions. Protocol updates reach the project through the managed
`docs/agent-protocol.md`, not by overwriting `AGENTS.md`.

#### Scenario: Existing AGENTS.md is preserved but protocol doc updates
- **WHEN** a target already has an `AGENTS.md` and install.sh runs
- **THEN** `AGENTS.md` is not overwritten
- **AND** `docs/agent-protocol.md` is (re)written to the current template version

### Requirement: Work Item ignore rule is merged idempotently
install.sh SHALL ensure the target's root `.gitignore` ignores disposable Work Item records, by
appending the single rule `/work-items/WI-*/` only when the project's versioned `.gitignore` does
not already carry an equivalent rule. It SHALL create `.gitignore` only when the file is absent.
The merge MUST NOT remove, reorder, or rewrite any other line, MUST NOT append a duplicate on any
later run, and MUST NOT modify the Git index or remove any file.

#### Scenario: Rule is appended to an existing .gitignore
- **WHEN** a target's `.gitignore` contains unrelated rules and no Work Item rule, and install.sh runs
- **THEN** `/work-items/WI-*/` is appended once
- **AND** every pre-existing line remains present and unchanged

#### Scenario: Re-running does not duplicate the rule
- **WHEN** install.sh runs twice against a target that needed the rule appended
- **THEN** `.gitignore` contains exactly one `/work-items/WI-*/` line

#### Scenario: Re-running a target that never needed the rule
- **WHEN** install.sh runs twice against a target whose versioned `.gitignore` already carries an
  equivalent rule
- **THEN** no `/work-items/WI-*/` line is added, and the rule count does not grow on either run

#### Scenario: Versioned rule already present
- **WHEN** a target's own versioned `.gitignore` already carries an equivalent rule, records resolve
  as ignored, and `work-items/AGENTS.md` stays trackable
- **THEN** install.sh does not append a second rule

#### Scenario: Missing .gitignore is created
- **WHEN** a target has no `.gitignore` and install.sh runs
- **THEN** `.gitignore` is created containing the Work Item rule

### Requirement: Only a versioned project rule can justify skipping the append
Exclusion that comes only from a non-versioned source — the repository-local exclude file or a
personal global excludes file — SHALL NOT justify skipping the append, because the project would
then carry no rule and a fresh clone would have no protection. install.sh SHALL still write the
rule into the project's root `.gitignore`, and MUST NOT modify personal or repository-local Git
configuration, or the index.

#### Scenario: Effect comes only from the repository-local exclude file
- **WHEN** the records resolve as ignored solely because the repository-local exclude file carries
  the rule, and the versioned `.gitignore` does not
- **THEN** install.sh appends the rule to the project's `.gitignore`
- **AND** it does not edit the repository-local exclude file

#### Scenario: Effect comes only from a personal global excludes file
- **WHEN** the records resolve as ignored solely because a personal global excludes file carries the
  rule, and the versioned `.gitignore` does not
- **THEN** install.sh appends the rule to the project's `.gitignore`
- **AND** it does not change any personal Git configuration

#### Scenario: Fresh clone without local configuration
- **WHEN** the same project files are used with no repository-local or personal exclusion
- **THEN** the versioned rule alone makes the records resolve as ignored
- **AND** `git add -A` stages no record file

### Requirement: Rule preservation is scoped to the Work Item merge
The preservation rule above SHALL bound the Work Item merge only. Retired-artifact cleanup that
install.sh already performs on `.gitignore` remains a separate, documented operation and SHALL NOT
be widened or blocked by this change. Acceptance for `.gitignore` SHALL check the required
properties separately rather than asserting the file equals one exact string.

#### Scenario: Retired rule removal coexists with the merge
- **WHEN** a target's `.gitignore` holds an unrelated rule plus a retired rule the installer removes,
  and install.sh runs twice
- **THEN** the unrelated rule survives, the retired rule is gone, the records are effectively ignored,
  and no duplicate Work Item rule is added

#### Scenario: Acceptance is property-based
- **WHEN** `.gitignore` acceptance is evaluated after install
- **THEN** each required property is checked on its own
- **AND** no check requires the whole file to equal a single fixed string

### Requirement: Ignore protection is verified by effect in both directions
install.sh SHALL verify the outcome with Git rather than the presence of a rule line. After
merging, an untracked path under `work-items/WI-*/` SHALL resolve as ignored, and
`work-items/AGENTS.md` SHALL NOT be ignored, so the convention stays trackable. Verification MUST
consult the index as well as the ignore rules, because a tracked path is not reported as ignored
even when a matching rule exists.

#### Scenario: Parent-level rule also hides the convention
- **WHEN** a target's `.gitignore` already contains `/work-items/`
- **THEN** install.sh reports that `work-items/AGENTS.md` cannot be tracked under the existing rules
- **AND** it does not claim the Work Item ignore protection is in effect

#### Scenario: Later negation defeats the literal rule
- **WHEN** a target's `.gitignore` contains `/work-items/WI-*/` followed by a negation of the same path
- **THEN** install.sh reports that records are not effectively ignored even though the literal rule is present
- **AND** it does not append a duplicate rule

#### Scenario: Both directions hold after a clean merge
- **WHEN** install.sh merges the rule into a target with no conflicting rules
- **THEN** an untracked record path resolves as ignored
- **AND** `work-items/AGENTS.md` resolves as not ignored

### Requirement: Unresolvable ignore conflicts are reported, not silently resolved
When protection cannot be achieved while preserving the target's existing rules and without
appending a duplicate, install.sh SHALL report the conflict and the specific rules involved,
SHALL NOT remove, reorder, or rewrite existing rules, and SHALL NOT report the protection as
established.

#### Scenario: Existing rules cannot be reconciled
- **WHEN** existing rules prevent both effective record ignoring and a trackable convention file
- **THEN** install.sh reports the conflict and leaves `.gitignore` otherwise unchanged
- **AND** the install result does not state that records are protected

### Requirement: Already-tracked records are reported without index changes
install.sh SHALL detect records tracked inside `work-items/WI-*/`, report them, and state that
ignore protection is not in force for those files. It MUST NOT modify the Git index, untrack, or
delete them, because an added rule does not stop `git add -A` from staging a tracked file's
modifications.

#### Scenario: Tracked record is modified after the rule is added
- **WHEN** a target tracks a record file, install.sh adds the rule, and the record is then modified
- **THEN** install.sh has reported the tracked record and the protection gap
- **AND** the Git index is unchanged by the installer

#### Scenario: Staging guarantee is scoped
- **WHEN** a target holds one untracked and one tracked record and the worktree is staged with `git add -A`
- **THEN** the untracked, effectively ignored record is not staged
- **AND** the tracked record is still staged, as reported

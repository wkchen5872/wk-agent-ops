# Spec Delta

## MODIFIED Requirements

### Requirement: workflow install.sh deploys hook as part of standard setup
`scripts/workflow/install.sh` SHALL deploy only `opsx-branch`, its zsh completion, and the existing branch compatibility hook. It SHALL retain the Agent-mediated branch-first contract for Claude Code, Codex, Antigravity, and GitHub Copilot CLI without adding a Session manager dependency.

#### Scenario: Running install.sh installs workflow entrypoints and fallback hooks
- **WHEN** workflow installation runs in a clean supported environment
- **THEN** opsx-branch and its completion are installed with the existing compatible fallback hooks
- **AND** wt-work, wt-resume, wt-done, pm-start, and wk-workflow-runtime are not installed

#### Scenario: Provider has no supported fallback hook
- **WHEN** a supported Provider has no suitable narrow PostToolUse integration
- **THEN** installation leaves that hook unregistered and retains the Agent-mediated branch guard

#### Scenario: Repeated installation
- **WHEN** installation runs twice
- **THEN** retained commands, completion, hook registrations, and shell initialization remain idempotent

## REMOVED Requirements

### Requirement: wt-work-flow.md documents the branch resolution flow
**Reason**: 舊 Worktree 工具退役。
**Migration**: 移除舊操作文件及專用圖稿；保留通用交接與 cleanup ownership 原則，由使用者選用的工具執行。

### Requirement: wt-done documentation notes local-only scope
**Reason**: 舊 Worktree 工具退役。
**Migration**: 移除舊操作文件及專用圖稿；保留通用交接與 cleanup ownership 原則，由使用者選用的工具執行。

### Requirement: Workflow cleanup respects Worktree ownership
**Reason**: 舊 Worktree 工具退役。
**Migration**: 移除舊操作文件及專用圖稿；保留通用交接與 cleanup ownership 原則，由使用者選用的工具執行。

## ADDED Requirements

### Requirement: Upgrade safely retires recognized legacy installations
The installer SHALL remove only recognized unmodified regular-file copies of retired commands, runtime, and completion at its known installation paths. It SHALL preserve and report modified, unknown, or symlink entries, leave unrelated files and workflow data untouched, and retain shared PATH and fpath configuration.

#### Scenario: Recognized old installation
- **WHEN** a known installation path contains an unmodified copy matching the shipped legacy reference
- **THEN** the installer removes that legacy copy and reports the removal
- **AND** existing branches, worktrees, Sessions, settings, and credentials remain untouched

#### Scenario: Customized or linked entry
- **WHEN** a legacy path contains modified or unknown content or a symlink including a dangling symlink
- **THEN** the installer preserves the entry and its target and reports manual cleanup is needed

#### Scenario: Absent legacy installation
- **WHEN** legacy installation entries are absent
- **THEN** installation succeeds without requiring legacy commands or altering unrelated entries

### Requirement: Current documentation describes the retained workflow boundary
Current documentation and installed Skill instructions SHALL describe branch preparation separately from user-selected Session and Worktree management. They SHALL remove runnable retired-command guidance and broken references while preserving general handoff, single-writer, review identity, and cleanup ownership rules. Historical archives and Work Item records SHALL remain unchanged.

#### Scenario: Reader follows current guidance
- **WHEN** a reader follows current installation or development guidance
- **THEN** no step requires a retired command
- **AND** retained branch-first instructions and document links resolve

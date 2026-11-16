# Spec Delta

## REMOVED Requirements

### Requirement: Tab-complete feature names for wt-* commands
**Reason**: 舊工具補全退役。
**Migration**: installer 部署 `_opsx-branch`；舊 `_wt` 依安全退役規則處理，重新載入 shell 更新 completion。

### Requirement: Tab-complete supported Provider values
**Reason**: 舊工具補全退役。
**Migration**: installer 部署 `_opsx-branch`；舊 `_wt` 依安全退役規則處理，重新載入 shell 更新 completion。

### Requirement: Tab-complete Worktree path option
**Reason**: 舊工具補全退役。
**Migration**: installer 部署 `_opsx-branch`；舊 `_wt` 依安全退役規則處理，重新載入 shell 更新 completion。

### Requirement: Tab-complete --session flag
**Reason**: 舊工具補全退役。
**Migration**: installer 部署 `_opsx-branch`；舊 `_wt` 依安全退役規則處理，重新載入 shell 更新 completion。

### Requirement: Completion script installed by install.sh
**Reason**: 舊工具補全退役。
**Migration**: installer 部署 `_opsx-branch`；舊 `_wt` 依安全退役規則處理，重新載入 shell 更新 completion。

## ADDED Requirements

### Requirement: Branch command has dedicated zsh completion
The installer SHALL deploy `_opsx-branch` on its configured fpath, registering only `opsx-branch`. Completion SHALL suggest de-duplicated existing local feature branch IDs, accept a new change ID, and return silently without candidates outside a repository. It SHALL NOT offer retired commands or Provider, Session, Worktree-path, or base-branch options.

#### Scenario: Existing branch completion
- **WHEN** a user requests completion for opsx-branch inside a repository with local feature branches
- **THEN** existing change IDs are suggested once each

#### Scenario: New change or no repository
- **WHEN** a user enters a new change ID or requests completion outside a repository
- **THEN** arbitrary new IDs remain usable and missing suggestions cause no error

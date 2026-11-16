# Spec: wt-zsh-completion

## Purpose

Provides dedicated zsh completion (`_opsx-branch`) for `opsx-branch`, completing existing local feature branch change IDs.

## Requirements

### Requirement: Branch command has dedicated zsh completion
The installer SHALL deploy `_opsx-branch` on its configured fpath, registering only `opsx-branch`. Completion SHALL suggest de-duplicated existing local feature branch IDs, accept a new change ID, and return silently without candidates outside a repository. It SHALL NOT offer retired commands or Provider, Session, Worktree-path, or base-branch options.

#### Scenario: Existing branch completion
- **WHEN** a user requests completion for opsx-branch inside a repository with local feature branches
- **THEN** existing change IDs are suggested once each

#### Scenario: New change or no repository
- **WHEN** a user enters a new change ID or requests completion outside a repository
- **THEN** arbitrary new IDs remain usable and missing suggestions cause no error

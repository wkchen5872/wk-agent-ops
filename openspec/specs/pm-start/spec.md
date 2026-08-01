# Spec: pm-start

## Purpose

Provides a Provider-selectable `pm-start` command that launches a planning session from the repository root without creating OpenSpec or Git state.

## Requirements

### Requirement: Launch persistent PM Master Session
The system SHALL provide `pm-start [--agent <provider>]` to launch a planning session from the repository root. It SHALL default to Claude, use a Provider's native launch-time plan mode when available, and SHALL NOT create an OpenSpec change, Git branch, or Worktree.

#### Scenario: Default Claude launch
- **WHEN** the user runs `pm-start` inside a Git repository
- **THEN** the system resolves the repository root and launches a deterministically named Claude PM session there
- **AND** enables Claude's native plan permission mode
- **AND** does not pass `/opsx:new` or another change-creation prompt

#### Scenario: Antigravity native plan launch
- **WHEN** the user runs `pm-start --agent antigravity`
- **THEN** the system launches `agy` from the repository root with its native plan mode enabled
- **AND** does not create persistent OpenSpec or Git state

#### Scenario: Antigravity CLI-name alias
- **WHEN** the user runs `pm-start --agent agy`
- **THEN** the system behaves identically to `--agent antigravity`

#### Scenario: Provider without a launch-time plan flag
- **WHEN** the user selects a supported Provider whose installed CLI exposes no native launch-time plan flag
- **THEN** the system launches its PM session from the repository root without performing change, branch, or Worktree actions
- **AND** clearly reports that plan mode must be selected inside that Provider

#### Scenario: Running outside a Git repository
- **WHEN** the user runs `pm-start` outside a Git repository
- **THEN** the system prints an error and exits non-zero without launching a Provider

#### Scenario: Unsupported Provider
- **WHEN** `--agent` is not one of `claude`, `codex`, `antigravity`, `agy`, or `copilot`
- **THEN** the system lists the supported values and exits non-zero

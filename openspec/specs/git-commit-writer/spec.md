# Spec: git-commit-writer

## Purpose

A skill that generates and executes Conventional Commits messages, optionally using openspec change context to derive the scope and subject.

## Requirements

### Requirement: Generate commit message from openspec change context
When an active or archived openspec change is available, the skill SHALL generate a Conventional Commits message using the change folder name as scope.

#### Scenario: Active change present
- **WHEN** `openspec list --json` returns exactly one active change
- **THEN** the skill reads `openspec/changes/<name>/proposal.md` and formats `<type>(<name>): <subject>`

#### Scenario: Archive path provided explicitly
- **WHEN** `archive_path` and `change_id` are passed in (e.g., called from openspec-commit)
- **THEN** the skill reads `<archive_path>/proposal.md` and formats `<type>(<change_id>): <subject>`

### Requirement: Generate commit message without openspec context
When no openspec change is available, the skill SHALL generate a Conventional Commits message without scope, derived from `git diff --cached`.

#### Scenario: No active change
- **WHEN** `openspec list --json` returns no active changes
- **THEN** the skill formats `<type>: <subject>` using git diff content as context

### Requirement: Infer commit type
The skill SHALL infer the correct Conventional Commits type from the nature of the staged changes.

#### Scenario: Type inference from proposal
- **WHEN** proposal.md is available
- **THEN** type is derived from the "What Changes" section (feat/fix/refactor/docs/chore/test)

#### Scenario: Type inference from diff only
- **WHEN** no proposal is available
- **THEN** type is inferred from file paths and diff content

### Requirement: Execute commit without confirmation
The skill SHALL execute `git add -A && git commit` immediately without prompting for confirmation.

#### Scenario: Successful commit
- **WHEN** skill completes message formatting
- **THEN** `git add -A` and `git commit -m "<message>"` are executed, and the short hash is printed

#### Scenario: Pre-commit hook failure
- **WHEN** `git commit` fails due to a pre-commit hook
- **THEN** the skill fixes the issue and retries without `--no-verify`

# Spec: openspec-commit

## Purpose

TBD — A skill that finalizes an openspec change by archiving it and committing all related changes with a properly formatted Conventional Commits message.

## Requirements

### Requirement: Execute git commit step
After archiving the change and updating docs, `openspec-commit` SHALL delegate commit execution to `git-commit-writer` rather than performing it inline.

#### Scenario: Claude Code environment
- **WHEN** `/openspec-commit` reaches Step 5 in Claude Code
- **THEN** an Agent with `model="haiku"` is dispatched with `archive_path` and `change_id`, which runs the git-commit-writer logic and executes the commit

#### Scenario: Other tool environment (Copilot CLI, Antigravity)
- **WHEN** `/openspec-commit` reaches Step 5 in a non-Claude Code tool
- **THEN** the `git-commit-writer` skill is invoked directly with `archive_path` and `change_id` as context

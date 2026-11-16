# Spec Delta

## ADDED Requirements

### Requirement: Handoff ignore rule is merged and verified
The installer SHALL ensure the target repository's versioned `.gitignore` contains `/.agent-handoff/`, appending it idempotently, and SHALL verify by effect that a file under `.agent-handoff/` is ignored. A conflict that leaves it unignored SHALL be reported, not silently resolved.

#### Scenario: Rule is added once
- **WHEN** the installer runs twice on a repository without the rule
- **THEN** `.gitignore` contains `/.agent-handoff/` exactly once

#### Scenario: Ignore is verified by effect
- **WHEN** the installer finishes
- **THEN** `git check-ignore .agent-handoff/roles.yaml` succeeds in the target repository

### Requirement: Role templates are seeded only when missing
The installer SHALL place an example `.agent-handoff/roles.yaml` in the target repository's main worktree only when the file does not exist, and MUST NOT overwrite or modify an existing one.

#### Scenario: User-edited templates survive reinstall
- **WHEN** `roles.yaml` exists with user edits and the installer runs again
- **THEN** the file is unchanged

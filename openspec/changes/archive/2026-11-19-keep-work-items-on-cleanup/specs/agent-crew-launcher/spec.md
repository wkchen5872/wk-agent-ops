# Spec Delta

## ADDED Requirements

### Requirement: Cleanup keeps the Work Items of removed worktrees
Before it removes a loop worktree other than the main worktree, cleanup with `--yes` SHALL copy every `work-items/WI-*` directory in that worktree, with all its files, to `<main worktree>/.agent-handoff/archive/<change-id>/<worktree name>/work-items/`. If a copy fails, cleanup SHALL remove nothing. Without `--yes`, cleanup SHALL list those directories. Work Items in a kept main worktree SHALL stay where they are.

#### Scenario: Work Item in a removed worktree is archived
- **WHEN** the implementer worktree holds `work-items/WI-20261119-x/agents/drill.md` and `handoff-cleanup <change-id> --yes` runs on the finished loop
- **THEN** `<main worktree>/.agent-handoff/archive/<change-id>/<implementer worktree name>/work-items/WI-20261119-x/agents/drill.md` exists and the implementer worktree is removed

#### Scenario: Preview names the Work Items
- **WHEN** `handoff-cleanup <change-id>` runs without `--yes` and a loop worktree holds `work-items/WI-20261119-x/`
- **THEN** the output names that Work Item directory and nothing is changed

#### Scenario: Work Item in the main worktree stays
- **WHEN** the loop was started with `--worktree here` in the main worktree, which holds `work-items/WI-20261119-x/`, and cleanup runs with `--yes`
- **THEN** `work-items/WI-20261119-x/` is still in the main worktree

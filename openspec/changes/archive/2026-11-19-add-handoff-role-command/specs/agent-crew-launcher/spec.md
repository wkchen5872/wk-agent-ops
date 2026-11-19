# Spec Delta

## ADDED Requirements

### Requirement: A role that has not opened can be changed during the loop
`handoff-role <change-id> <review|finish> <override>` SHALL replace that role's tool, model, effort, provider and billing in the loop's `loop.yaml` while the role's session has not opened, using the override form `handoff-start` accepts. It SHALL first run the checks `handoff-start` applies to roles. When a check fails or the role's session is already recorded, it SHALL exit non-zero and leave `loop.yaml` unchanged. It MUST NOT modify `roles.yaml`.

#### Scenario: Reviewer changed before the first handoff
- **WHEN** no reviewer has opened and `handoff-role add-export review pi:openai/gpt-6.2-sol:high:api` runs with that model listed and an API-key credential ready
- **THEN** `loop.yaml` holds a Pi review template with those values, and the hook later opens the reviewer from it

#### Scenario: Reviewer already open
- **WHEN** `loop.yaml` records a reviewer session and `handoff-role add-export review codex:gpt-6.2-sol:high` runs
- **THEN** it exits non-zero naming that session, and `loop.yaml` is unchanged

#### Scenario: Pi role fails verification
- **WHEN** `handoff-role add-export review pi:openai/not-a-model:high:api` runs and the model is not listed under `openai`
- **THEN** it exits non-zero naming the check, and `loop.yaml` is unchanged

#### Scenario: Second Pi role in one worktree
- **WHEN** the implementer is a Pi role, the review role uses the implementer's worktree, and `handoff-role add-export review pi:openai/gpt-6.2-sol:high:api` runs
- **THEN** it exits non-zero explaining that a worktree holds one Pi role, and `loop.yaml` is unchanged

### Requirement: An override that changes the tool also changes its skill call and session name
When an override from `handoff-start` or `handoff-role` sets a tool different from the template's, the role's prompt SHALL start with the new tool's skill call syntax — `/<skill>` for Claude Code, `$<skill>` for Codex, `/skill:<skill>` for Pi — when it started with a skill call, and a session name that starts with the old tool's name SHALL start with the new tool's name.

#### Scenario: Codex review overridden with Pi at start
- **WHEN** the review template is `codex` with prompt `$change-review {change}…` and name `codex - review - {change}`, and `handoff-start add-export --review pi:openai-codex/gpt-6.2-sol:high:subscription` runs
- **THEN** `loop.yaml` holds prompt `/skill:change-review {change}…` and name `pi - review - {change}`

#### Scenario: Same tool keeps its prompt
- **WHEN** an override keeps the template's tool and changes only the model
- **THEN** the prompt and session name are unchanged

## MODIFIED Requirements

### Requirement: Resolve tool and assisting-model identity without guessing
The `git-commit-writer` skill and provider-specific agent SHALL accept
`tool_name` and an exact root-session `assisting_model` as an attribution pair
immediately before commit execution. `assisting_model` SHALL identify the exact
model of the root agent session governing the work and SHALL be used only as
Git trailer metadata; it MUST NOT select or override the writer's runtime model
or reasoning effort.

An orchestrated call MUST supply both values as task input. For a standalone
invocation in the root session that performed the work, the writer MUST use the
exact current runtime identity automatically and MUST NOT ask the user to repeat
it. The same rule applies to later standalone commits in that session while the
root model remains unchanged. Provider-native documentation and commit
subagents MUST NOT replace or make root-session attribution ambiguous.

The writer MUST reject a missing value, generic model-family label, or provider
alias rather than normalizing, expanding, or resolving it. It MUST request the
exact attribution when work came from another session, the root model changed
during the work, or the exact root identity is unavailable. It MUST NOT infer
identity from documentation, email domains, unrelated environment variables,
session logs, model-family system descriptions, Git history, or a commit-only
agent's identity.

#### Scenario: Orchestrated commit supplies attribution
- **WHEN** `openspec-commit` invokes `git-commit-writer` with an exact tool name and root-session model
- **THEN** the commit writer uses those exact values only for attribution

#### Scenario: Standalone commit in unchanged root session
- **WHEN** the root session performed the work, exposes its exact model identity, and has not switched models
- **THEN** standalone `git-commit-writer` automatically uses that exact identity
- **AND** it does not ask the user to provide or confirm the model name

#### Scenario: Repeated standalone commit in the same session
- **WHEN** the same root session performs more work and invokes `git-commit-writer` again without changing models
- **THEN** the writer uses the unchanged current root-session identity
- **AND** it does not require per-commit reconfirmation

#### Scenario: Claude commit-only agent receives the implementation model
- **WHEN** a Claude commit-only agent receives a root-session model different from its configured model
- **THEN** `assisting_model` remains the root-session model
- **AND** the subagent model neither replaces attribution nor creates ambiguity
- **AND** `assisting_model` does not override the commit-only agent's runtime configuration

#### Scenario: Orchestrated commit supplies a family label
- **WHEN** `assisting_model` is a generic family label such as `GPT-5` rather than an exact runtime or user-supplied model identity
- **THEN** the commit writer stops before committing
- **AND** reports that exact root-session attribution is required

#### Scenario: Work came from another session
- **WHEN** standalone `git-commit-writer` is invoked in a session that did not perform the work
- **THEN** it stops before committing and requests the exact root-session attribution
- **AND** it does not substitute the current or previous commit model

#### Scenario: Root model changed during the work
- **WHEN** the root model changed during implementation and the attribution is ambiguous
- **THEN** the writer stops before committing and requests the exact attribution
- **AND** it does not select the latest model automatically

#### Scenario: Standalone identity is uncertain
- **WHEN** a standalone invocation cannot identify its tool or exact root-session model
- **THEN** it stops before committing and requests the missing attribution
- **AND** it does not guess either value

#### Scenario: Codex custom agent has a configured model
- **WHEN** `git-commit-writer-agent` receives `assisting_model=gpt-5.6-sol` as task input
- **THEN** it retains its provider-native configured runtime model and reasoning effort
- **AND** records `gpt-5.6-sol` only in the `AI-Assisted-By` trailer

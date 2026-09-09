## MODIFIED Requirements

### Requirement: Resolve tool and assisting-model identity without guessing
The `git-commit-writer` skill and provider-specific agent SHALL accept
`tool_name` and `assisting_model` as an attribution pair immediately before
commit execution. `assisting_model` SHALL identify the primary model that
implemented the change and SHALL be used only as Git trailer metadata; it MUST
NOT select or override the commit writer's runtime model or reasoning effort.
An orchestrated call MUST supply both values as task input. A standalone
invocation MAY use exact runtime-provided identities, but MUST stop and request
the missing values when either identity is uncertain rather than inferring it
from an email domain, unrelated environment variable, or the commit-only
agent's identity.

#### Scenario: Orchestrated commit supplies attribution
- **WHEN** `openspec-commit` invokes `git-commit-writer`
- **THEN** it supplies the executing tool name and primary assisting model as task input
- **AND** the commit writer uses those exact values only for attribution

#### Scenario: Claude commit-only agent receives the implementation model
- **WHEN** a Claude commit-only agent writes a commit for work completed by a different primary model
- **THEN** `assisting_model` identifies the primary implementation model
- **AND** MUST NOT be replaced with the commit-only agent's model
- **AND** MUST NOT override the commit-only agent's runtime configuration

#### Scenario: Standalone identity is uncertain
- **WHEN** a standalone invocation cannot identify its tool or assisting model exactly
- **THEN** it stops before committing and requests the missing attribution
- **AND** MUST NOT guess either value

#### Scenario: Codex custom agent has a configured model
- **WHEN** `git-commit-writer-agent` receives `assisting_model=gpt-5.6-sol` as task input
- **THEN** it retains its provider-native configured runtime model and reasoning effort
- **AND** records `gpt-5.6-sol` only in the `AI-Assisted-By` trailer

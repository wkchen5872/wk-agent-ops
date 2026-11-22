## ADDED Requirements

### Requirement: A delegated Issue post names the posting agent
When the dedicated Issue agent writes an Issue body or comment for a caller, the Author SHALL keep the caller-supplied lines unchanged and end with `Posted-By: <agent name> (<model>)`. The model SHALL be the agent's own, from its runtime context or provider-native definition, never the caller's. When unknown, the line SHALL be `Posted-By: <agent name>` and the omission reported without blocking.

#### Scenario: Codex Issue agent posts a progress comment
- **WHEN** a Codex session using `gpt-6.1-terra` delegates a progress comment to `github-issue-agent`, whose definition uses `gpt-5.6-terra`
- **THEN** the Author keeps the caller's `Co-Authored-By`, `AI-Assisted-By: gpt-6.1-terra`, `SESSION-ID`, and `XIRP-SESSION-ID`
- **AND** its last line is `Posted-By: github-issue-agent (gpt-5.6-terra)`

#### Scenario: Issue agent's own model is unknown
- **WHEN** the Issue agent cannot determine its own model
- **THEN** the last Author line is `Posted-By: github-issue-agent` and the omission is reported

### Requirement: An Issue post written by the session itself has no Posted-By
A post a session writes for itself, without delegation, MUST NOT contain `Posted-By`. Pure human-direct content SHALL still omit the Author section.

#### Scenario: Session posts for itself
- **WHEN** a session creates an Issue through the `github-issue` skill without delegating
- **THEN** the Author has no `Posted-By` line

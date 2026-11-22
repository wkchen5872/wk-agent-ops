## ADDED Requirements

### Requirement: A delegated PR post names the posting agent
When the dedicated PR agent writes a PR description or reply for a caller, the Author SHALL keep the caller-supplied lines unchanged and end with `Posted-By: <agent name> (<model>)`. The model SHALL be the agent's own, from its runtime context or provider-native definition, never the caller's or a definition alias. When unknown, the line SHALL be `Posted-By: <agent name>` and the omission reported without blocking.

#### Scenario: Claude PR agent posts a Review reply
- **WHEN** a review session supplies its tool, `Claude Opus 5.5`, and both session IDs, and the Claude `github-pr-agent` runs on `claude-sonnet-4-6`
- **THEN** the Author keeps the caller's four lines exactly
- **AND** its last line is `Posted-By: github-pr-agent (claude-sonnet-4-6)`, not the alias `sonnet`

#### Scenario: PR agent's own model is unknown
- **WHEN** the PR agent cannot determine its own model
- **THEN** the last Author line is `Posted-By: github-pr-agent` and the omission is reported

### Requirement: A PR post written by the session itself has no Posted-By
A post a session writes for itself, without delegation, MUST NOT contain `Posted-By`.

#### Scenario: Session posts for itself
- **WHEN** a session replies through the `github-pr` skill without delegating
- **THEN** the Author has no `Posted-By` line

### Requirement: Posted-By never identifies an author or a handoff target
Consumers that read an Author to find the implementer or the session to notify SHALL use only `Co-Authored-By`, `AI-Assisted-By`, `SESSION-ID`, and `XIRP-SESSION-ID`, and MUST NOT treat the `Posted-By` agent as an author, implementer, or handoff target. Authors without `Posted-By` SHALL be read as before.

#### Scenario: Review looks up the implementer from a delegated reply
- **WHEN** the newest implementation reply was posted by `github-pr-agent` for a Codex implementer session
- **THEN** the consumer identifies the implementer from that reply's `SESSION-ID` and `XIRP-SESSION-ID`
- **AND** it does not treat `github-pr-agent` as the implementer or try to notify it

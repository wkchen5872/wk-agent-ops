# Spec Delta

## ADDED Requirements

### Requirement: A dedicated Issue agent can execute Issue operations for a caller
A dedicated Issue agent SHALL be available for Claude Code and Codex to perform `github-issue` operations on behalf of a calling session, following this capability's format, write checks, and readback. The Claude Code agent SHALL use Sonnet.

#### Scenario: Caller delegates an Issue update
- **WHEN** a session asks the Issue agent to add a progress comment to a confirmed Issue
- **THEN** the agent verifies the full repository and Issue target, appends one comment, reads it back, and returns its URL

### Requirement: Delegated Issue operations keep the caller's identity
When operating for a caller, the Issue agent SHALL write the Author with the caller-supplied tool, model, native session ID, and Xirp session ID, and MUST NOT substitute its own model or session. Missing caller identity SHALL be reported rather than guessed.

#### Scenario: Caller identity is missing
- **WHEN** the caller does not supply its model or session IDs
- **THEN** the agent writes nothing and returns which identity fields are missing

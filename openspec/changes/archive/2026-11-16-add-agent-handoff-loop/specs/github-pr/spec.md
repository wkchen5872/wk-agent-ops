# Spec Delta

## ADDED Requirements

### Requirement: A dedicated PR agent can execute PR operations for a caller
A dedicated PR agent SHALL be available for Claude Code and Codex to perform `github-pr` operations on behalf of a calling session, following this capability's format, write checks, and readback. The Claude Code agent SHALL use Sonnet.

#### Scenario: Caller delegates a reply
- **WHEN** a review session asks the PR agent to post a saved report as a reply on a confirmed PR
- **THEN** the agent verifies the full repository and PR target, posts once, reads the comment back, and returns its URL and publication state

### Requirement: Delegated operations keep the caller's identity
When operating for a caller, the PR agent SHALL write the Author with the caller-supplied tool, model, native session ID, and Xirp session ID, and MUST NOT substitute its own model or session. Missing caller identity SHALL be reported rather than guessed.

#### Scenario: Caller identity is supplied
- **WHEN** the caller passes its model and both session IDs
- **THEN** the posted Author shows those values exactly

#### Scenario: Caller identity is missing
- **WHEN** the caller does not supply its session IDs
- **THEN** the agent posts nothing and returns which identity fields are missing

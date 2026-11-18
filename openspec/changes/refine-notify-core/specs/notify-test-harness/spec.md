# Spec Delta

## ADDED Requirements

### Requirement: Template and category regression tests
The harness SHALL verify, against isolated HOME directories and without real Telegram delivery: built-in template output for every notification kind; user template override, fallback, escaping, and removal of empty optional lines; the four category switches with legacy-key fallback and environment override; and the level change that keeps other switches.

#### Scenario: Built-in output is unchanged
- **WHEN** the harness renders completion, waiting-for-response, and stopped messages with no user template
- **THEN** each equals the recorded current message

#### Scenario: Legacy config fixtures
- **WHEN** the harness runs the hook with configs that hold only legacy category keys
- **THEN** the observed categories match the documented fallback

### Requirement: Delayed-authorization and provider regression tests
The harness SHALL verify delayed authorization for Claude Code, Codex, and Antigravity with a shortened delay, the classification of Claude Code notification types, the Antigravity termination reasons, and the pruning of stale Codex state, using fake session records and fake daemon metadata.

#### Scenario: Delay is shortened for tests
- **WHEN** the harness sets the authorization delay to one second and leaves a request unresolved
- **THEN** it observes exactly one authorization message after the delay and none before it

#### Scenario: Resolved request stays silent
- **WHEN** the harness resolves the request before the shortened delay ends
- **THEN** it observes no authorization message

#### Scenario: Overlapping waits
- **WHEN** the harness resolves a first wait and starts a second one before the first delay ends
- **THEN** it observes no message from the first check and one message for the second wait after the second wait's own delay

#### Scenario: Signals without an identifier
- **WHEN** the harness sends repeated start signals without an identifier, with and without resolution evidence between them
- **THEN** the delay is never restarted by a repeat, a merged wait produces one message, and a wait after the re-arm interval or after resolution evidence produces its own message

#### Scenario: Codex runtime unavailable
- **WHEN** the harness makes the fake runtime unavailable for a real wait, an approved command that is still running, and an unreadable record
- **THEN** each case produces one message with the unconfirmed wording and none with the confirmed wording

#### Scenario: Stale state fixtures
- **WHEN** the harness starts an inspection with old, recent, locked, and unrelated files in the state directory
- **THEN** only the old unlocked notification-owned files are removed

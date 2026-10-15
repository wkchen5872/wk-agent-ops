## ADDED Requirements

### Requirement: Category and on-demand checker regression tests
The harness SHALL verify five category switches, grouped editing, cancellation, legacy migration, independent hook branches and checker lifecycle against isolated HOME directories and fake daemon metadata without sending real notifications.

#### Scenario: Isolated category matrix
- **WHEN** every old and new event runs with its switch enabled and disabled
- **THEN** its own switch determines delivery and legacy fixtures retain behavior

#### Scenario: Checker lifecycle fixtures
- **WHEN** fixtures cover delayed flags, repeated hooks, wait resets, multiple sessions, turn completion and connection failure
- **THEN** tests verify non-blocking startup, deduplication, bounded failure and cleanup

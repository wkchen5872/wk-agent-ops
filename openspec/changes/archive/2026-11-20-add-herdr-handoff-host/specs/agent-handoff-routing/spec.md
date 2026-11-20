## MODIFIED Requirements

### Requirement: Routing is idempotent and fails silently
The hook SHALL record which handoff records it has processed and MUST NOT send a second message for the same record. Any error SHALL end the hook with success status and without affecting the agent. When the command of the host a record would be routed through is not installed, the hook SHALL do nothing for that record.

#### Scenario: Agent stops twice after one record
- **WHEN** an agent stops again without writing a new record
- **THEN** no message is sent for the already processed record

#### Scenario: Xirp is not installed
- **WHEN** the hook runs for an `xirp` loop on a machine without the `xirp` command
- **THEN** it exits successfully without sending anything

#### Scenario: herdr loop on a machine without Xirp
- **WHEN** the hook runs for a loop whose roles all use `host: herdr` on a machine without the `xirp` command
- **THEN** it routes the record through herdr

### Requirement: Each routing step records the session's actual model
When the hook processes a record, it SHALL append to a routing log in the change directory the record file, the action taken, and the stopping session's identifiers and model as reported by its host at that moment. When the host does not report a model, the log SHALL show the role template's model marked as taken from the template. The hook SHALL use `CHIRP_SESSION_ID` as the stopping session's Xirp identifier only outside a herdr pane.

#### Scenario: Model changed during the session
- **WHEN** the user switched the implementer to another model before it stopped
- **THEN** the routing log shows the model in use when that record was processed

#### Scenario: herdr does not report the model
- **WHEN** a herdr reviewer whose template sets `gpt-6.1-sol` writes a record that is processed
- **THEN** the routing log shows `gpt-6.1-sol` marked as the template model

#### Scenario: Inherited Xirp variable in a herdr pane
- **WHEN** a record is processed in a herdr pane whose environment carries `CHIRP_SESSION_ID` from the shell that started herdr
- **THEN** the routing log does not name that value as the stopping session

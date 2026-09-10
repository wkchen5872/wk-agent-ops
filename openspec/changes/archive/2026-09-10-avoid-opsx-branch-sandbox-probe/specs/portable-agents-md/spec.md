## MODIFIED Requirements

### Requirement: Managed protocol defines the OpenSpec branch guard
The installed operating protocol SHALL require an Agent to run `opsx-branch <change-id>` after resolving a change ID and before continuing an OpenSpec new, fast-forward, or continue action. In a Provider sandbox that protects Git metadata, the Agent SHALL request the minimum required Git-write permission on the first attempt instead of first running a command that cannot update the repository. This requirement SHALL be expressed as tool-invariant workflow intent and SHALL NOT require modifying generated Provider skills or commands.

#### Scenario: New or fast-forward action resolves an ID
- **WHEN** an Agent accepts or derives a change ID for an OpenSpec new or fast-forward action
- **THEN** the managed protocol directs it to run `opsx-branch <change-id>` before creating the change scaffold

#### Scenario: Continue action resolves an existing ID
- **WHEN** an Agent selects an existing change for an OpenSpec continue action
- **THEN** the managed protocol directs it to run `opsx-branch <change-id>` before reading status or writing the next artifact

#### Scenario: Provider protects Git metadata
- **WHEN** an Agent knows its active Provider sandbox prevents `opsx-branch` from updating Git metadata
- **THEN** it requests the minimum required Git-write permission for the first execution attempt
- **AND** it does not run a guaranteed-to-fail sandbox probe first

#### Scenario: Branch guard fails
- **WHEN** `opsx-branch <change-id>` exits non-zero
- **THEN** the managed protocol directs the Agent to stop the current OpenSpec action and report the error

#### Scenario: Protocol is installed downstream
- **WHEN** the installer refreshes managed documentation in a target project
- **THEN** the installed `docs/agent-protocol.md` contains the same branch guard contract

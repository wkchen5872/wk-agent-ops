# Spec Delta

## ADDED Requirements

### Requirement: Remote handoff publishes outcomes rather than local records
When the project uses the GitHub handoff workflow, review reports and repair evidence SHALL be publishable directly to the associated PR as formal handoff records. Local Work Items SHALL remain optional scratch records for that remote handoff. Agents MUST NOT upload, synchronize, or expose the whole Work Item to make the remote workflow usable.

#### Scenario: Review starts on another machine
- **WHEN** a reviewer has the published Change and PR version but no original Work Item
- **THEN** it can review and publish its own report to the associated PR without restoring or copying the original records
- **AND** any new local scratch record follows the current-directory ownership and ignore rules

#### Scenario: Existing local-only collaboration continues
- **WHEN** a task is not using the GitHub handoff workflow
- **THEN** the existing local Review convention remains available
- **AND** no remote Issue or PR is required solely because a Work Item exists

#### Scenario: Local report contains necessary unresolved findings
- **WHEN** a local report contains confirmed findings needed by a remote implementer
- **THEN** the relevant findings, reviewed revision, evidence, and next action are published to the formal handoff location within the authorized workflow
- **AND** the handoff does not depend on an absolute local path or the continued existence of the Work Item

#### Scenario: A necessary finding is accepted but not fixed
- **WHEN** a published review contains a confirmed necessary repair, risk, or verification item that remains unfinished
- **THEN** it is linked from the corresponding OpenSpec task or explicitly designated formal risk mechanism
- **AND** the detailed PR report does not replace required formal tracking or justify marking the work complete

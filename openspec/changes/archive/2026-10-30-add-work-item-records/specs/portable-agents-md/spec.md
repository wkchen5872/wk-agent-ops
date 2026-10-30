## ADDED Requirements

### Requirement: Seed AGENTS.md may carry additional stable pointers
Besides the pointer to the shared operating protocol, the installable
`template/common/AGENTS.md` MAY carry further **stable pointer sections** to managed references,
each naming the managed file as the single source. Such a section SHALL stay short enough to
remain valid across updates of the referenced file and MUST NOT restate the referenced rules, so
`AGENTS.md` can remain copy-once while the referenced file updates independently.

#### Scenario: Work Item pointer defers to the managed file
- **WHEN** `template/common/AGENTS.md` is read
- **THEN** its Work Item section directs the agent to read `work-items/AGENTS.md` as the single source
- **AND** it does not restate the convention's rules

### Requirement: Activation needs a reachable entry for AGENTS.md-only tools
A rule that a tool consuming only `AGENTS.md` must follow SHALL be reachable from **the root
instruction file that tool actually loads**, which may be an override file taking precedence over
`AGENTS.md` when one directory offers several candidates. The chain is that loaded root file →
`docs/agent-protocol.md` → `work-items/AGENTS.md`, and every link MUST exist for the rule to count
as delivered.

#### Scenario: Chain is complete
- **WHEN** a target's `AGENTS.md` directs the agent to the managed protocol and install.sh has run
- **THEN** each link of the chain resolves to a shipped file
- **AND** the convention is reachable without reading any provider-specific rules directory

#### Scenario: Chain is broken at its first link
- **WHEN** the loaded root instruction file does not point at the managed protocol
- **THEN** the rule is not delivered for an `AGENTS.md`-only tool, whatever else was installed

#### Scenario: An override file wins over AGENTS.md
- **WHEN** a target's `AGENTS.md` points at the managed protocol but a non-empty override file in
  the same directory takes precedence and carries no such pointer
- **THEN** the chain is treated as broken, because the file that is loaded lacks the pointer
- **AND** a check that inspects `AGENTS.md` alone is not accepted as evidence

### Requirement: Provider rules directories are not activation evidence
Installing provider-specific rules directories MUST NOT be treated as evidence that a tool
consuming only `AGENTS.md` received the entry, because those directories are read by their own
providers.

#### Scenario: Provider entries present while the chain is broken
- **WHEN** `.claude/rules/` and `.agents/rules/` contain the activation entry but the chain is broken
- **THEN** delivery is not accepted for an `AGENTS.md`-only tool
- **AND** the presence of those files is not reported as activation

### Requirement: A broken chain is reported, never repaired by overwriting
When the loaded root instruction file lacks the protocol pointer, install.sh SHALL report the gap,
name the file it examined, and state the pointer section the project should add. It MUST NOT modify
any project-owned instruction file, and MUST NOT report the convention as active for an
`AGENTS.md`-only tool. When it cannot determine which file would be loaded, it SHALL report the
entry as unverified rather than assume either outcome.

#### Scenario: Custom AGENTS.md without a protocol pointer
- **WHEN** install.sh runs against such a target
- **THEN** managed files and provider entries are still installed
- **AND** the gap, its consequence, and the pointer section to add are reported
- **AND** the target's `AGENTS.md` is byte-identical afterwards

### Requirement: Nested instruction files are not an activation channel
`work-items/AGENTS.md` SHALL be treated as an on-demand reference reached through the chain, not
as an auto-discovered instruction file, because a nested instruction file below the launch
directory is not loaded automatically.

#### Scenario: Tool is launched at the repository root
- **WHEN** a session starts at the repository root
- **THEN** `work-items/AGENTS.md` is not loaded automatically
- **AND** it is read only when the activation pointer directs the agent to it

### Requirement: Runtime activation is verified or declared untested
Acceptance of the activation entry for an `AGENTS.md`-only tool SHALL be either a manual check in
a newly started session at the repository root that reaches the convention through the chain, or
an explicit record that the entry was verified by document inspection only and not runtime-tested.
File existence alone MUST NOT be reported as runtime verification.

#### Scenario: Manual session check is performed
- **WHEN** a new session is started at the repository root after install
- **THEN** the result records whether the convention was reached through root `AGENTS.md` and the managed protocol

#### Scenario: No session check is performed
- **WHEN** no such session is run
- **THEN** the change records the entry as inspected but not runtime-tested

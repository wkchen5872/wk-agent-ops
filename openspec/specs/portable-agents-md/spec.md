# portable-agents-md Specification

## Purpose

Define what makes the installable `template/common/AGENTS.md` a portable, tool-invariant
operating map: it names Claude Code as the primary tool while remaining usable by any
AGENTS.md-aware tool, states prohibitions as principles rather than directory lists, describes
workflow stages by intent with tool-specific commands only as examples, avoids dangling
references, and keeps its Definition of Done aligned to the enforcing mechanism rather than
over-claiming.

## Requirements

### Requirement: AGENTS.md is a thin project-owned pointer
The installable `template/common/AGENTS.md` SHALL be a thin, project-owned map that carries
project mission/know-how plus a **stable pointer section** to the shared operating protocol.
The full operating protocol SHALL NOT be inlined in `AGENTS.md`; it lives in the managed doc
`docs/agent-protocol.md`. The pointer section SHALL be stable (designed not to change across
protocol updates) so that `AGENTS.md` can remain copy-once (seed) while the protocol updates
independently.

#### Scenario: AGENTS.md points to the managed protocol doc
- **WHEN** `template/common/AGENTS.md` is read
- **THEN** it contains a pointer section directing the agent to read `docs/agent-protocol.md`
- **AND** it does not inline the §1–6 operating protocol (task-scale protocol, implementation loop, DoD)

#### Scenario: Protocol invariants do not need to hold on the pointer file
- **WHEN** the tool-invariant checks run
- **THEN** they target `docs/agent-protocol.md` (the protocol), not the thin `AGENTS.md` pointer

### Requirement: No named secondary tool binding
The installed operating protocol (the managed `docs/agent-protocol.md`, which `AGENTS.md`
points to) SHALL name Claude Code as the primary tool and MUST NOT bind to any specific
secondary tool by name or by tool-specific directory. It SHALL declare portability to any
AGENTS.md-aware tool.

#### Scenario: Header declares primary + generic portability
- **WHEN** the header of `docs/agent-protocol.md` is read
- **THEN** it names Claude Code as primary AND states portability to any AGENTS.md-aware tool
- **AND** it does not name Codex, Antigravity, or any other secondary tool as "supported"

#### Scenario: No tool-specific config directory in prose
- **WHEN** the protocol body (excluding the vendored-config principle) is scanned
- **THEN** it contains no reference to `.codex/`, `.agents/`, or a named secondary tool's config directory as a binding claim

### Requirement: Prohibitions state principle, not directory lists
The vendored-config prohibition in `docs/agent-protocol.md` SHALL describe the principle
(never edit generated / vendored agent-config directories) and MUST defer the authoritative
directory list to the enforcement mechanism (hook), not enumerate it in portable prose.

#### Scenario: Prohibition is principle-based
- **WHEN** the vendored-config prohibition is read
- **THEN** it states the principle generically
- **AND** it points to the enforcement mechanism for the authoritative directory list
- **AND** it does not hard-code a `.claude/, .agents/, .codex/` enumeration as the source of truth

### Requirement: Stages described by intent, commands as examples only
Every workflow stage in `docs/agent-protocol.md` SHALL be described by its tool-invariant
intent. Tool-specific commands (e.g. `/opsx:*`) MAY appear only as parenthetical Claude Code
examples. The protocol MUST NOT pin a command string for the open set of "other tools".

#### Scenario: Each stage reads standalone without its command
- **WHEN** all parenthetical `(Claude Code: ...)` examples are hidden
- **THEN** every stage sentence still states what to do (the intent survives without the command)

#### Scenario: No fake command for the open "other tools" set
- **WHEN** the protocol is scanned for command strings
- **THEN** it contains no `/openspec-verify-change (other CLIs)`-style enumeration that pins a command for non-primary tools

### Requirement: No dangling references
Every path or file the operating protocol tells the agent to read SHALL resolve in the
shipped/installed context.

#### Scenario: Referenced docs exist or are shipped
- **WHEN** each `docs/*.md` (or other repo-relative) reference in `docs/agent-protocol.md` is checked
- **THEN** the referenced file exists in the repo AND is shipped by install.sh into downstream projects
- **AND** there is no reference to a non-existent file such as `docs/enforcement.md`

### Requirement: DoD prose does not over-claim beyond the mechanism
The Definition of Done in `docs/agent-protocol.md` SHALL state coverage/verification gates as
intent and SHALL mark prose as advisory where the real boundary is a mechanism (hook), so the
protocol never claims a guarantee the shipped mechanism does not enforce.

#### Scenario: DoD marks the mechanism as the boundary
- **WHEN** the DoD and enforcement notes are read
- **THEN** they state that "done" means the mechanical gate passes (not the agent's self-assessment)
- **AND** language-specific mechanics (e.g. `--cov-fail-under`, exit codes) do not appear in the protocol

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

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
The installed operating protocol SHALL require an Agent to run `opsx-branch <change-id>` after resolving a change ID and before continuing an OpenSpec new, fast-forward, or continue action. This requirement SHALL be expressed as tool-invariant workflow intent and SHALL NOT require modifying generated Provider skills or commands.

#### Scenario: New or fast-forward action resolves an ID
- **WHEN** an Agent accepts or derives a change ID for an OpenSpec new or fast-forward action
- **THEN** the managed protocol directs it to run `opsx-branch <change-id>` before creating the change scaffold

#### Scenario: Continue action resolves an existing ID
- **WHEN** an Agent selects an existing change for an OpenSpec continue action
- **THEN** the managed protocol directs it to run `opsx-branch <change-id>` before reading status or writing the next artifact

#### Scenario: Branch guard fails
- **WHEN** `opsx-branch <change-id>` exits non-zero
- **THEN** the managed protocol directs the Agent to stop the current OpenSpec action and report the error

#### Scenario: Protocol is installed downstream
- **WHEN** the installer refreshes managed documentation in a target project
- **THEN** the installed `docs/agent-protocol.md` contains the same branch guard contract

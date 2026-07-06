# portable-agents-md Specification

## Purpose

Define what makes the installable `template/common/AGENTS.md` a portable, tool-invariant
operating map: it names Claude Code as the primary tool while remaining usable by any
AGENTS.md-aware tool, states prohibitions as principles rather than directory lists, describes
workflow stages by intent with tool-specific commands only as examples, avoids dangling
references, and keeps its Definition of Done aligned to the enforcing mechanism rather than
over-claiming.

## Requirements

### Requirement: No named secondary tool binding
The installable `template/common/AGENTS.md` SHALL name Claude Code as the primary tool
and MUST NOT bind to any specific secondary tool by name or by tool-specific directory.
It SHALL declare portability to any AGENTS.md-aware tool.

#### Scenario: Header declares primary + generic portability
- **WHEN** the header of `template/common/AGENTS.md` is read
- **THEN** it names Claude Code as primary AND states portability to any AGENTS.md-aware tool
- **AND** it does not name Codex, Antigravity, or any other secondary tool as "supported"

#### Scenario: No tool-specific config directory in prose
- **WHEN** the file body (excluding the vendored-config principle) is scanned
- **THEN** it contains no reference to `.codex/`, `.agents/`, or a named secondary tool's config directory as a binding claim

### Requirement: Prohibitions state principle, not directory lists
The vendored-config prohibition SHALL describe the principle (never edit generated /
vendored agent-config directories) and MUST defer the authoritative directory list to the
enforcement mechanism (hook / `docs/enforcement.md`), not enumerate it in portable prose.

#### Scenario: Prohibition is principle-based
- **WHEN** the vendored-config prohibition is read
- **THEN** it states the principle generically
- **AND** it points to the enforcement mechanism for the authoritative directory list
- **AND** it does not hard-code a `.claude/, .agents/, .codex/` enumeration as the source of truth

### Requirement: Stages described by intent, commands as examples only
Every workflow stage SHALL be described by its tool-invariant intent. Tool-specific
commands (e.g. `/opsx:*`) MAY appear only as parenthetical Claude Code examples. The file
MUST NOT pin a command string for the open set of "other tools".

#### Scenario: Each stage reads standalone without its command
- **WHEN** all parenthetical `(Claude Code: ...)` examples are hidden
- **THEN** every stage sentence still states what to do (the intent survives without the command)

#### Scenario: No fake command for the open "other tools" set
- **WHEN** the file is scanned for command strings
- **THEN** it contains no `/openspec-verify-change (other CLIs)`-style enumeration that pins a command for non-primary tools

### Requirement: No dangling references
Every path or file the installable `AGENTS.md` tells the agent to read SHALL resolve in
the shipped/installed context.

#### Scenario: Referenced docs exist or are shipped
- **WHEN** each `docs/*.md` (or other repo-relative) reference in the file is checked
- **THEN** the referenced file exists in the repo AND is shipped by install.sh into downstream projects
- **AND** there is no reference to a non-existent file such as `docs/enforcement.md`

### Requirement: DoD prose does not over-claim beyond the mechanism
The Definition of Done SHALL state coverage/verification gates as intent and SHALL mark
prose as advisory where the real boundary is a mechanism (hook), so the portable map never
claims a guarantee the shipped mechanism does not enforce.

#### Scenario: DoD marks the mechanism as the boundary
- **WHEN** the DoD and enforcement notes are read
- **THEN** they state that "done" means the mechanical gate passes (not the agent's self-assessment)
- **AND** language-specific mechanics (e.g. `--cov-fail-under`, exit codes) do not appear in the portable map

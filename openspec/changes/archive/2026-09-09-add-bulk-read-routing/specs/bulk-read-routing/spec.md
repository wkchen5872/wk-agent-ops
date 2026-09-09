## Purpose

Provide a user-level Claude Code and Codex capability that delegates expensive initial codebase discovery to one bounded read-only agent while preserving parent-agent verification and engineering ownership.

## ADDED Requirements

### Requirement: Broad discovery routes to one named agent
The skill SHALL route a task through exactly one `bulk-reader-agent` when relevant code locations are unknown and broad repository discovery is expected to dominate the work. It MUST NOT route already-located small edits or repeat the routing during the same discovery phase.

#### Scenario: Unknown execution path requires broad discovery
- **WHEN** the parent needs to locate relevant files, symbols, callers, or tests across an unfamiliar code path
- **THEN** the skill instructs the parent to spawn exactly one custom agent named `bulk-reader-agent`
- **AND** the parent waits for its findings before targeted verification

#### Scenario: Relevant location is already known
- **WHEN** targeted search has already identified the relevant files or symbols
- **THEN** the skill does not spawn `bulk-reader-agent`

#### Scenario: Named agent is unavailable
- **WHEN** `bulk-reader-agent` cannot be invoked by the current provider
- **THEN** the parent reports the missing user-level provider configuration
- **AND** performs targeted discovery itself without substituting or spawning another agent

### Requirement: Discovery remains bounded and read-only
The provider-native agent SHALL only locate repository-relative files, symbols, callers, tests, and short exact quotes within the scope assigned by the parent. It MUST NOT edit files, install dependencies, commit, use the network, recommend an implementation, or claim a final root cause.

#### Scenario: Discovery completes with evidence
- **WHEN** the agent finds relevant repository evidence
- **THEN** it returns at most ten findings ordered by relevance
- **AND** every finding includes a repository-relative path, line range when known, symbol when known, an exact quote of at most three lines, and a one-sentence relevance explanation

#### Scenario: Discovery finds no evidence
- **WHEN** the bounded search finds no relevant evidence
- **THEN** it returns an empty findings section, low confidence with a reason, and unknowns for parent verification

### Requirement: Parent retains engineering responsibility
The skill SHALL treat subagent output as discovery evidence rather than a final conclusion. The parent MUST verify every quote or claim used for an engineering decision and MUST retain root-cause analysis, architecture, security, concurrency, final conclusions, and edits.

#### Scenario: Finding informs a decision
- **WHEN** a subagent finding may affect an engineering conclusion or edit
- **THEN** the parent performs a targeted read of the relevant source before relying on it

### Requirement: User-level installation is isolated
The repository SHALL provide a dedicated installer for this capability that copies its canonical skill and provider-native agents only to the selected user-level Claude Code and Codex locations. The installer MUST NOT invoke or modify the project-level common installer, project repositories, or unrelated user files.

#### Scenario: Both providers are installed
- **WHEN** the user installer runs with both providers selected
- **THEN** matching copies of the canonical skill are installed for Claude Code and Codex
- **AND** each provider receives its own `bulk-reader-agent` definition

#### Scenario: One provider is selected
- **WHEN** the user installer runs for only Claude Code or only Codex
- **THEN** it writes only that provider's managed skill and agent files

#### Scenario: Installer is repeated
- **WHEN** the installer runs repeatedly against the same user roots
- **THEN** the managed files remain byte-identical to their templates
- **AND** unrelated files remain unchanged

### Requirement: Routing effectiveness is evaluated
The capability SHALL include replayable evaluation guidance that compares direct parent discovery with routed discovery on equivalent tasks. Results MUST separate parent tokens, subagent tokens, total tokens, elapsed time, evidence accuracy, spawn count, and write attempts.

#### Scenario: Provider evaluation is performed
- **WHEN** the routing behavior is evaluated for Claude Code or Codex
- **THEN** the same bounded discovery task is run once without routing and once with routing
- **AND** the result records whether exactly one named subagent ran and whether evidence quality was preserved

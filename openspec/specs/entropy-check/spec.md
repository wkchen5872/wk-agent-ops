# entropy-check

## Purpose

Entropy check is a multi-context audit tool that detects documentation drift, broken references, unused code, stale OpenSpec changes, and complexity debt. It runs targeted audits based on the detected project type (openspec or standard) and provides a structured decision menu for remediation.

## Requirements

### Requirement: Context detection
The skill SHALL detect the project type using two contexts only: `openspec` and `standard`.

#### Scenario: OpenSpec context detected
- **WHEN** `openspec/changes/` directory exists in the project root
- **THEN** context is set to `openspec` and O1 audit is included

#### Scenario: Standard context detected
- **WHEN** `openspec/changes/` does not exist
- **THEN** context is set to `standard` and only D1/D2/D3/C1/R1 audits run

#### Scenario: Project root resolved via environment variable
- **WHEN** `GEMINI_PROJECT_DIR` is set
- **THEN** `PROJECT_ROOT` is set to `$GEMINI_PROJECT_DIR`

#### Scenario: Project root fallback to Claude env
- **WHEN** `GEMINI_PROJECT_DIR` is not set and `CLAUDE_PROJECT_DIR` is set
- **THEN** `PROJECT_ROOT` is set to `$CLAUDE_PROJECT_DIR`

#### Scenario: Project root fallback to PWD
- **WHEN** neither `GEMINI_PROJECT_DIR` nor `CLAUDE_PROJECT_DIR` is set
- **THEN** `PROJECT_ROOT` is set to `$PWD`

### Requirement: Audit routing table
The skill SHALL run audits according to the following routing: D1/D2/D3/C1/R1 run for all contexts; O1 runs only when context is `openspec`.

#### Scenario: Standard project audit set
- **WHEN** context is `standard`
- **THEN** audits D1, D2, D3, C1, R1 are executed
- **AND** O1 is skipped

#### Scenario: OpenSpec project audit set
- **WHEN** context is `openspec`
- **THEN** audits D1, D2, D3, C1, O1, R1 are all executed

### Requirement: U1 — AGENTS.md coverage
Entropy check SHALL verify that all installed skills and agents have entries in AGENTS.md.

#### Scenario: Missing skill entry detected
- **WHEN** a directory exists under `.claude/skills/<name>/SKILL.md`
- **AND** AGENTS.md does not contain a `### <name>` section
- **THEN** the finding is reported as U1 with the skill name and path

#### Scenario: Missing agent entry detected
- **WHEN** a file exists at `.claude/agents/<name>.md`
- **AND** AGENTS.md does not contain a `### <name>` section
- **THEN** the finding is reported as U1 with the agent name and path

#### Scenario: Auto-fix applied
- **WHEN** user selects auto-fix for a U1 finding
- **THEN** entropy check reads the SKILL.md or agent.md source file
- **AND** writes a correctly-formatted `### <name>` entry to AGENTS.md
- **AND** does not modify any other sections of AGENTS.md

### Requirement: U2 — Docs completeness
Entropy check SHALL detect unfilled documentation templates.

#### Scenario: Empty template detected
- **WHEN** `docs/architecture.md` or `docs/conventions.md` contains placeholder text (`TODO`, `[填入]`, or empty `##` sections with only the section header and comment)
- **THEN** the finding is reported as U2 with the file path
- **AND** no auto-fix is offered (requires human knowledge to fill)

### Requirement: U3 — Dead references
Entropy check SHALL detect broken file references in documentation.

#### Scenario: Dead reference in AGENTS.md
- **WHEN** AGENTS.md contains a local path reference (pattern: `scripts/`, `.claude/`, `template/`)
- **AND** that path does not exist on disk
- **THEN** the finding is reported as U3 with the file and the broken path

#### Scenario: Dead reference in docs
- **WHEN** any `docs/*.md` file contains a local path reference
- **AND** that path does not exist on disk
- **THEN** the finding is reported as U3

### Requirement: O1 — Stale active changes (openspec)
Entropy check SHALL detect abandoned OpenSpec changes.

#### Scenario: Stale change detected
- **WHEN** context is `openspec`
- **AND** the most recently modified file in that directory is older than 14 days
- **THEN** the finding is reported as O1 with the change name and last-modified date

### Requirement: Output format
Entropy check SHALL present findings in a structured, actionable format.

#### Scenario: Summary display
- **WHEN** all audits complete
- **THEN** a summary table is shown with each audit code, status (✓ clean / ⚠️ N findings), and finding count

#### Scenario: Decision menu
- **WHEN** one or more findings exist
- **THEN** user is presented with options: [1] auto-fix fixable findings, [2] create OpenSpec change for structural findings, [3] skip and update watermark
- **WHEN** no findings exist
- **THEN** watermark is updated automatically and a "clean" message is shown

### Requirement: Watermark update
Entropy check SHALL update the watermark after every run regardless of outcome.

#### Scenario: Watermark written
- **WHEN** entropy check completes (any option chosen, including skip)
- **AND** context is `openspec`
- **AND** `openspec/.entropy-state` is added to `.gitignore` if not already present

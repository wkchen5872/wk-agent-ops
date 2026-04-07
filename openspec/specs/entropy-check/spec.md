# entropy-check

## Purpose

Entropy check is a multi-context audit tool that detects documentation drift, broken references, stale OpenSpec changes, and template sync issues. It runs targeted audits based on the detected project type (harness, openspec, or standard) and provides a structured decision menu for remediation.

## Requirements

### Requirement: Context detection
Entropy check SHALL detect the project type before running any audits.

#### Scenario: Harness project detected
- **WHEN** `template/common/` directory exists in the project root
- **THEN** context is set to `harness` and audits U1, U2, U3, H1, O1, O2, O3 are run (if openspec/ also present)

#### Scenario: OpenSpec project detected
- **WHEN** `openspec/changes/` directory exists but `template/common/` does not
- **THEN** context is set to `openspec` and audits U1, U2, U3, O1, O2, O3 are run

#### Scenario: Standard project detected
- **WHEN** neither `template/common/` nor `openspec/changes/` exists
- **THEN** context is set to `standard` and only audits U1, U2, U3 are run

#### Scenario: Tool environment detected
- **WHEN** `GEMINI_PROJECT_DIR` is set
- **THEN** project root resolves to `$GEMINI_PROJECT_DIR`
- **WHEN** `CLAUDE_PROJECT_DIR` is set and `GEMINI_PROJECT_DIR` is not
- **THEN** project root resolves to `$CLAUDE_PROJECT_DIR`
- **WHEN** neither env var is set
- **THEN** project root resolves to `$PWD`

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

### Requirement: H1 — Template sync (harness only)
In harness context, entropy check SHALL detect drift between template and installed layers.

#### Scenario: Template drift detected
- **WHEN** context is `harness`
- **AND** any file under `template/common/.claude/` differs from its counterpart in `.claude/` (excluding `*.local*` files)
- **THEN** the finding is reported as H1 with the differing file path
- **AND** auto-fix suggests running `bash scripts/skills/install.sh`

### Requirement: O1 — Stale active changes (openspec)
Entropy check SHALL detect abandoned OpenSpec changes.

#### Scenario: Stale change detected
- **WHEN** context is `openspec` or `harness`
- **AND** a directory exists under `openspec/changes/` (not under `archive/`)
- **AND** the most recently modified file in that directory is older than 14 days
- **THEN** the finding is reported as O1 with the change name and last-modified date

### Requirement: O2 — OpenSpec spec sync (openspec)
Entropy check SHALL detect archived changes whose specs were not synced to canonical location.

#### Scenario: Unsynced spec detected
- **WHEN** context is `openspec` or `harness`
- **AND** a directory exists under `openspec/changes/archive/<name>/specs/` containing `.md` files
- **AND** `openspec/specs/<name>/` does not exist
- **THEN** the finding is reported as O2 with the change name

### Requirement: O3 — Dead specs (openspec)
Entropy check SHALL detect spec directories with no corresponding implementation.

#### Scenario: Dead spec detected
- **WHEN** context is `openspec` or `harness`
- **AND** a directory exists under `openspec/specs/<name>/`
- **AND** no corresponding skill exists at `.claude/skills/<name>/` or `template/common/skills/<name>/`
- **AND** no corresponding agent exists at `.claude/agents/<name>.md`
- **THEN** the finding is reported as O3 with the spec path
- **AND** no auto-fix is offered (requires human confirmation before deletion)

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
- **AND** context is `openspec` or `harness`
- **THEN** current archive count is written to `openspec/.entropy-state`
- **AND** `openspec/.entropy-state` is added to `.gitignore` if not already present

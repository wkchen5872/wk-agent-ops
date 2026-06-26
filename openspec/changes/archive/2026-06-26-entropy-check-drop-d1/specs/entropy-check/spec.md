## REMOVED Requirements

### Requirement: U1 — AGENTS.md coverage
**Reason**: The audit scans all installed skills including third-party/superpowers packages, producing noisy findings that are irrelevant to project maintainers. The signal-to-noise ratio is too low to be useful.
**Migration**: No migration needed. AGENTS.md coverage is no longer audited by entropy-check.

## MODIFIED Requirements

### Requirement: Context detection
The skill SHALL detect the project type using two contexts only: `openspec` and `standard`.

#### Scenario: OpenSpec context detected
- **WHEN** `openspec/changes/` directory exists in the project root
- **THEN** context is set to `openspec` and O1 audit is included

#### Scenario: Standard context detected
- **WHEN** `openspec/changes/` does not exist
- **THEN** context is set to `standard` and only D2/D3/C1/R1 audits run

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
The skill SHALL run audits according to the following routing: D2/D3/C1/R1 run for all contexts; O1 runs only when context is `openspec`.

#### Scenario: Standard project audit set
- **WHEN** context is `standard`
- **THEN** audits D2, D3, C1, R1 are executed
- **AND** D1 and O1 are skipped

#### Scenario: OpenSpec project audit set
- **WHEN** context is `openspec`
- **THEN** audits D2, D3, C1, O1, R1 are all executed
- **AND** D1 is not executed

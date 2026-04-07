## REMOVED Requirements

### Requirement: U1 — AGENTS.md coverage
**Reason**: The audit scans all installed skills including third-party/superpowers packages, producing noisy findings that are irrelevant to project maintainers. The signal-to-noise ratio is too low to be useful.
**Migration**: No migration needed. AGENTS.md coverage is no longer audited by entropy-check.

## MODIFIED Requirements

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

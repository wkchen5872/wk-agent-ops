# entropy-check-r1-watermark

## Purpose

R1 is the complexity and refactoring candidate audit sub-check for entropy-check. It detects large files and high marker density that indicate accumulated technical debt, and uses the archive count watermark from `openspec/.entropy-state` to recommend the appropriate remediation command (`/simplify` or `/refactor`) based on project maturity.

## Requirements

### Requirement: Watermark-based refactor recommendation
The skill SHALL read the archive count from `openspec/.entropy-state` (if it exists) and use it to recommend either `/simplify` or `/refactor` for R1 findings.

#### Scenario: Low archive count — recommend simplify
- **WHEN** `openspec/.entropy-state` exists and its value is less than 5
- **THEN** R1 recommendation is `/simplify` with label "(project maturity: early)"

#### Scenario: Mid archive count — recommend both
- **WHEN** `openspec/.entropy-state` exists and its value is between 5 and 15 inclusive
- **THEN** R1 recommendation is `/simplify` as primary, with note "consider `/refactor` for structural issues"

#### Scenario: High archive count — recommend refactor
- **WHEN** `openspec/.entropy-state` exists and its value is greater than 15
- **THEN** R1 recommendation is `/refactor` with label "(project maturity: high)"

#### Scenario: No watermark file — default to simplify
- **WHEN** `openspec/.entropy-state` does not exist
- **THEN** R1 recommendation defaults to `/simplify`

### Requirement: R1 complexity detection
The skill SHALL detect files that are candidates for refactoring based on size and marker density.

#### Scenario: Large script flagged
- **WHEN** a `.sh` file contains more than 150 lines
- **THEN** R1 reports a finding: `<file> (<N> lines) — candidate for /simplify`

#### Scenario: Large code file flagged
- **WHEN** a `.py`, `.ts`, or `.js` file contains more than 300 lines
- **THEN** R1 reports a finding: `<file> (<N> lines) — candidate for /simplify or /refactor`

#### Scenario: High marker density flagged
- **WHEN** a file contains 3 or more occurrences of `TODO`, `FIXME`, or `HACK`
- **THEN** R1 reports a finding: `<file> (<N> markers) — consider addressing debt`

#### Scenario: openspec/ directory excluded
- **WHEN** scanning for R1 candidates
- **THEN** files under `openspec/` are excluded from R1 findings

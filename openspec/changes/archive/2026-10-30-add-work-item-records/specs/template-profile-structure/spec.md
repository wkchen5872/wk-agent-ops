## ADDED Requirements

### Requirement: common profile carries the Work Item convention source
`template/common/` SHALL carry the Work Item convention at `work-items/AGENTS.md` as the single
upstream source of that convention, mirroring the path it occupies in an installed target.
`template/common/` MUST NOT carry a `CLAUDE.md`, so personal preferences and eager imports are
not distributed into every target, and MUST NOT carry example record directories.

#### Scenario: Convention source exists in common
- **WHEN** `template/common/` is listed
- **THEN** it contains `work-items/AGENTS.md`
- **AND** it contains no `work-items/WI-*/` directory

#### Scenario: No CLAUDE.md is distributed
- **WHEN** `template/common/` is listed
- **THEN** it contains no `CLAUDE.md`

#### Scenario: Convention source is tool-neutral
- **WHEN** `template/common/work-items/AGENTS.md` is scanned
- **THEN** it names no specific secondary tool as a session-alias example or as a supported tool

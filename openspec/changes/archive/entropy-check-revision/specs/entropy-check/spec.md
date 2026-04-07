## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: H1 template sync audit
**Reason**: Harness-specific check. Only valid in wk-agent-ops. Causes errors and false positives in all other project types.
**Migration**: Run `diff -r template/common/.claude/ .claude/` manually in wk-agent-ops if needed.

### Requirement: O2 OpenSpec spec sync audit
**Reason**: Systematic false positives due to date-prefix mismatch in path comparison. The replacement check (archive watermark via R1) provides a better proxy signal.
**Migration**: Manually verify `openspec/specs/<name>/` after each archive if needed.

### Requirement: O3 Dead specs audit
**Reason**: Only checked `.claude/skills/` and `.claude/agents/` for implementations, flagging all script-based specs as "dead". The replacement C1 audit detects actual dead code more accurately.
**Migration**: Manual review of `openspec/specs/` if needed.

### Requirement: D2 harness skill coverage sub-check
**Reason**: Compared `template/common/skills/` against AGENTS.md — harness-specific, not portable to other project types.
**Migration**: Harness maintainers should manually verify AGENTS.md entries after adding new skills.

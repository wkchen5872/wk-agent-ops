## ADDED Requirements

### Requirement: Project-owned commit entrypoints propagate without drift
The common installer SHALL copy the project-owned Claude Code commit command and
Antigravity commit workflow to their provider-specific installed targets without
content drift. It MUST install the Claude Code adapter at
`.claude/commands/opsx/commit.md` and the Antigravity adapter at
`.agents/workflows/opsx-commit.md`.

#### Scenario: Common profile is installed in a clean repository
- **WHEN** `scripts/skills/install.sh` installs the common profile
- **THEN** both installed commit entrypoint files exist
- **AND** each installed file is byte-identical to its corresponding template
- **AND** the installer does not create `.codex/` or singular `.agent/` artifacts

#### Scenario: This repository refreshes its generated targets
- **WHEN** the installer is run against the wk-agent-ops repository
- **THEN** the tracked `.claude/commands/opsx/commit.md` matches its template
- **AND** `.agents/workflows/opsx-commit.md` exists and matches its template

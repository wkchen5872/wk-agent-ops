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

### Requirement: Installer supports linked worktree roots
The common installer SHALL accept a linked Git worktree root as a valid target
without weakening its repository-root validation. When a language profile
contains hooks, it MUST resolve the hooks destination through Git rather than
assuming that `<target>/.git` is a directory.

#### Scenario: Common and profile content is installed in a linked worktree
- **WHEN** `scripts/skills/install.sh` targets a linked worktree root with a
  language profile
- **THEN** common provider entrypoints are installed in that worktree
- **AND** profile hooks are installed at the hooks path reported by Git
- **AND** the install completes successfully even though `<target>/.git` is a
  file

#### Scenario: A repository subdirectory is supplied as the target
- **WHEN** the installer target is inside a repository but is not its top-level
  directory
- **THEN** installation is rejected as not targeting a Git repository root

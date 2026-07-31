## Why

The project-owned `/opsx:commit` and `/opsx-commit` entrypoints currently mix a
workflow summary with a second instruction to invoke `openspec-commit`. This can
be interpreted as two executions, and the Antigravity wrapper also uses Claude
Code-specific command and tool terminology.

The required RD flow applies changes from a linked Git worktree, but the common
installer currently accepts only targets whose `.git` path is a directory and
uses the same assumption for profile hooks.

## What Changes

- Turn the Claude Code command and Antigravity workflow into thin adapters that
  invoke the project-owned `openspec-commit` capability exactly once.
- Forward an optional OpenSpec change name without re-resolving or rewriting it.
- Use provider-correct invocation wording: `/opsx:commit` plus the Skill tool for
  Claude Code, and `/opsx-commit` plus skill activation/fallback instructions for
  Antigravity.
- Strengthen installer and orchestration contract tests so the exact template
  entrypoints must reach their installed targets.
- Make the installer accept both primary checkout roots and linked worktree
  roots, including profile hook installation through Git's resolved hooks path.
- Refresh the OpenSpec commit workflow documentation with both provider entry
  commands.
- Keep OpenSpec-generated `.agent/` versus Antigravity `.agents/` path drift
  outside this change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-commit`: Define exactly-once delegation and argument forwarding for
  project-owned provider entrypoints.
- `tooling-target-scope`: Require exact entrypoint propagation plus
  worktree-safe repository-root and hooks-path resolution.

## Impact

- `template/common/.claude/commands/opsx/commit.md`
- `template/common/.agents/workflows/opsx-commit.md`
- Generated `.claude/` and `.agents/` installation targets, refreshed only via
  `scripts/skills/install.sh`
- `scripts/skills/install.sh` repository-root and hooks-path resolution
- `tests/test_openspec_commit.sh` and `tests/test_agents_dir.sh`
- `docs/workflow/commit.md` and the two affected canonical specs after archive
- No new runtime dependency or provider adapter layer

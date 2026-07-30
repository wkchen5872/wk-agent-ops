## Why

`openspec-commit` currently duplicates documentation-update logic, rediscovers
archive context that it already received, and delegates to a commit writer that
only commits staged files even though the workflow does not stage its changes.
The workflow needs explicit, resumable hand-offs so archive, documentation, and
commit behavior remains consistent across Claude Code, Codex, and Antigravity.

## What Changes

- Refactor `openspec-commit` into a thin coordinator that invokes
  `openspec-archive-change`, `doc-updater`, and `git-commit-writer` in order.
- Pass the exact `change_id` and `archive_path` between steps instead of
  rediscovering them from the newest archive or downstream heuristics.
- Support resuming after archive when documentation update or commit failed.
- Make `doc-updater` combine archived proposal/spec intent with the complete
  worktree diff, including newly created files prepared by the coordinator.
- Restore final staging and archive validation in `git-commit-writer`.
- Define provider-neutral capability invocation while documenting the
  OpenSpec-generated native locations for Claude Code (`.claude/`), Codex
  (`.codex/`), and Antigravity (`.agent/`). The custom harness continues to
  install project-owned skills only to `.claude/skills/` and `.agents/skills/`.
- Add a focused workflow contract test and reconcile canonical specs with the
  implemented behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-commit`: Coordinate archive, documentation update, staging, commit,
  retry, and provider-neutral action routing with explicit hand-offs.
- `doc-updater`: Accept optional archived change context and use it together
  with the actual uncommitted diff.
- `git-commit-writer`: Stage the complete change set, honor explicit archive
  context, and restage before retrying a failed commit.
- `tooling-target-scope`: Distinguish project-owned portable skill installation
  from OpenSpec-generated native integrations for Claude Code, Codex, and
  Antigravity.

## Impact

- `template/common/skills/openspec-commit/SKILL.md`
- `template/common/skills/doc-updater/SKILL.md`
- `template/common/skills/git-commit-writer/SKILL.md`
- Claude-specific wrappers under `template/common/.claude/agents/`
- Canonical OpenSpec specs for the four modified capabilities
- Workflow documentation and a focused shell contract test
- Installed `.claude/` and `.agents/` copies after running
  `scripts/skills/install.sh`

OpenSpec-generated `.codex/` and `.agent/` files remain upstream-owned and are
read for provider routing context only; this change does not edit or install
them.

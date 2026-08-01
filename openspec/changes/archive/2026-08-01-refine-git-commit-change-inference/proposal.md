# Proposal: refine-git-commit-change-inference

## Why

Standalone `git-commit-writer` currently treats “exactly one active OpenSpec change” as sufficient commit context. This produced commit `374d835` with scope `add-mutation-check` even though its staged diff only changed provider hook documentation, so the commit history asserted an unrelated feature association.

## What Changes

- Keep explicit `archive_path` + `change_id` from `openspec-commit` authoritative and unchanged.
- Stage and inspect the final cached diff before resolving standalone OpenSpec context.
- Require positive association evidence before applying a standalone scope:
  - an active change matches the current `feature/<change-id>` branch or has staged files under its exact active change directory;
  - an archived change has staged files under its exact archive directory.
- Treat a sole but unassociated active change as no OpenSpec context and derive an unscoped Conventional Commit from the staged diff.
- If multiple positively associated candidates remain, ask the user when interaction is available; otherwise stop and list them.
- Update the portable skill, Claude agent, canonical spec, documentation, installed mirrors, and contract tests without adding a runtime helper.

## Capabilities

### New Capabilities

<!-- None. -->

### Modified Capabilities

- `git-commit-writer`: Tighten standalone OpenSpec context inference so a candidate must be associated with the branch or staged diff before its change ID becomes the commit scope.

## Impact

- Affected sources: `template/common/skills/git-commit-writer/SKILL.md` and `template/common/.claude/agents/git-commit-writer.md`.
- Affected contract and docs: `openspec/specs/git-commit-writer/spec.md`, `tests/test_openspec_commit.sh`, `docs/skills/git-commit-writer.md`, and installed template mirrors.
- `openspec-commit` callers remain compatible because complete explicit context still bypasses standalone inference.
- Commits made outside a demonstrably associated OpenSpec branch/archive may lose an incorrect scope; their staged-diff-derived type, subject, body, and commit behavior remain unchanged.

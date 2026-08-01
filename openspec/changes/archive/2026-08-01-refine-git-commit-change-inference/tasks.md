# Tasks: refine-git-commit-change-inference

## 1. Contract Test First

- [x] 1.1 Extend the `commit-writer` section of `tests/test_openspec_commit.sh` to require staging before standalone resolution, exact feature-branch and cached-path association evidence, and an explicit unscoped fallback for a sole unrelated active change
  - 測試要求：run `bash tests/test_openspec_commit.sh commit-writer` before source edits and record a non-zero Red caused by the missing new contract, while existing explicit-context assertions still pass

## 2. Source Behavior

- [x] 2.1 Update `template/common/skills/git-commit-writer/SKILL.md` so explicit input validation remains first, but standalone candidate resolution occurs after `git add -A` and filters active/archive candidates using the exact branch/path rules from design D2–D3
  - 測試要求：focused contract test must pass for the portable skill; a sole unassociated active change must be described as staged-diff-only context
- [x] 2.2 Mirror the same ordering and association rules in `template/common/.claude/agents/git-commit-writer.md`, preserving its non-interactive stop behavior for multiple associated candidates
  - 測試要求：focused contract test must pass for the Claude agent and continue to assert explicit context, empty-diff, restage, and no-first-candidate guards

## 3. Distribution and Documentation

- [x] 3.1 Run `bash scripts/skills/install.sh` to propagate the source skill and agent to generated `.claude/` and `.agents/` targets
  - 測試要求：source and installed git-commit-writer files must compare equal where the installer defines a mirror; no generated target is edited directly
- [x] 3.2 Update `docs/skills/git-commit-writer.md` to show the stage-before-resolve flow, positive association table, and unscoped unrelated-active example
  - 測試要求：documentation must retain valid OKF frontmatter and must not claim that one active change alone supplies scope

## 4. Acceptance and Validation

- [x] 4.1 Replay the `374d835` input shape against the written decision table: current branch `main`, docs-only cached paths, and one unrelated active change must resolve to an unscoped `docs: ...` message
  - 測試要求：record the sanitized inputs and expected decision in the focused test or docs; do not execute an actual commit during replay
- [x] 4.2 Run the focused and full workflow contract tests, relevant installer/mirror tests, `git diff --check`, and `openspec validate refine-git-commit-change-inference --strict`
  - 測試要求：all commands pass; the canonical main spec remains for `openspec-commit` to synchronize during archive rather than being edited manually during apply

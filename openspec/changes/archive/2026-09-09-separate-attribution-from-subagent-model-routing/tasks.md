## 1. Expected Red

- [x] 1.1 Extend `tests/test_openspec_commit.sh` to require attribution resolution after documentation handling, metadata-only `assisting_model`, and native-agent spawning without model or effort overrides; run the focused test and record the expected failure.

## 2. Minimal Implementation

- [x] 2.1 Update `template/common/skills/openspec-commit/SKILL.md` to defer attribution until Step 5 and separate task metadata from spawn configuration; verify the orchestrator section passes.
- [x] 2.2 Add the metadata-only boundary to the portable and Claude Code `git-commit-writer` source instructions, run the installer to refresh generated copies, and verify the commit-writer section passes.

## 3. Documentation and Verification

- [x] 3.1 Update `docs/workflow/commit.md` to document just-in-time attribution and configured subagent runtime models; verify obsolete early-attribution wording is absent.
- [x] 3.2 Run all affected shell suites, `git diff --check`, and `openspec validate separate-attribution-from-subagent-model-routing --strict`; fix scoped failures without weakening assertions.

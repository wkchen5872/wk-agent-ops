## 1. Expected Red

- [x] 1.1 Add assertions to `tests/test_agents_dir.sh` for suffixed Claude Code and Codex agent templates, preserved model settings, exact legacy-file cleanup, and preservation of an unrelated custom agent; run the focused test and record the expected failure against the current unsuffixed installation.
- [x] 1.2 Add assertions to `tests/test_openspec_commit.sh` for Claude Code/Codex `*-agent` routing, other-provider portable skill fallback, and no silent fallback for missing known-provider agents; run the focused test and record the expected routing failure.

## 2. Minimal Implementation

- [x] 2.1 Rename the four provider-native source templates to `doc-updater-agent` and `git-commit-writer-agent`, update their internal names without changing operational logic or model settings, and verify the focused template assertions pass.
- [x] 2.2 Update `scripts/skills/install.sh` to remove only the four obsolete managed installed filenames before syncing, run it to refresh this repository's generated targets, and verify the migration test preserves unrelated agents.
- [x] 2.3 Update `template/common/skills/openspec-commit/SKILL.md` with explicit Claude Code and Codex subagent routes plus the default portable skill route for every other provider; verify the focused routing test passes.

## 3. Documentation and Verification

- [x] 3.1 Update project-owned documentation references to the suffixed provider-native agents and shared `.agents/skills/` fallback, then verify no current managed documentation advertises the obsolete invocation names.
- [x] 3.2 Run all affected shell test suites and `openspec validate prefer-provider-subagents-for-openspec-commit --strict`; fix scoped failures without weakening assertions and record the passing commands.

## 1. Focused Test Contract

- [x] 1.1 Test requirement — update the focused installer test to require the two Codex agent templates, exact installed copies, exact model/effort values, preservation of unrelated `.codex` content, and continued absence of singular `.agent/`; run it before implementation and record the expected non-zero Red caused by the missing template/installer behavior.

## 2. Codex Agent Templates and Propagation

- [x] 2.1 Add `template/common/.codex/agents/git-commit-writer.toml` with current commit-writer behavior and `gpt-5.6-luna` / `medium`; verify required TOML fields and model assertions through the focused test.
- [x] 2.2 Add `template/common/.codex/agents/doc-updater.toml` with current doc-updater behavior and `gpt-5.6-terra` / `medium`; verify required TOML fields and model assertions through the focused test.
- [x] 2.3 Extend the common installer to sync only `.codex/agents/`, run it against this repository, and verify the installed TOML files are byte-identical while unrelated `.codex` content remains untouched.

## 3. Documentation and Verification

- [x] 3.1 Update the source template and project documentation to describe Codex subagent ownership, paths, model settings, and the restricted `.codex/agents/` installer boundary; verify documented paths and claims against the implemented files.
- [x] 3.2 Run the focused test, affected installer/protocol tests, OpenSpec strict validation, and repository-required checks; verify all pass without modifying unrelated files.

## 1. Expected Red

- [x] 1.1 Extend `tests/test_openspec_commit.sh` to require automatic unchanged root-session attribution, no repeated confirmation, subagent non-ambiguity, and no pre-commit-boundary prompt; run the focused test and record the expected behavioral failure. (`rtk bash tests/test_openspec_commit.sh`, exit 1, new attribution assertions failed.)

## 2. Minimal Implementation

- [x] 2.1 Update the canonical `openspec-commit` template so same-session exact attribution is mandatory and prompting remains limited to genuine ambiguity; verify the focused orchestrator test passes.
- [x] 2.2 Update the canonical portable commit writer and provider-native commit-agent templates to preserve the root-session contract without using commit-only runtime identity; verify the focused commit-writer test passes.

## 3. Propagation and Verification

- [x] 3.1 Run `scripts/skills/install.sh`, verify generated Claude, shared-agent, and Codex copies match their templates, and confirm no unrelated generated files changed.
- [x] 3.2 Run the focused contract test, strict OpenSpec validation, and `git diff --check`; record that live provider prompt behavior remains an acceptance check outside static tests. (Static contracts are green; same-session provider prompting still requires live acceptance after reload.)

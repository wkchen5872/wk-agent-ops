## 1. Contract Test

- [x] 1.1 Add focused assertions for explicit `tool_name` and
  `assisting_model` handoff, ordered `Co-Authored-By` and `AI-Assisted-By`
  trailers, verified Codex/Claude Code mappings, and name-only unmapped tools.
  **測試要求：** run `bash tests/test_openspec_commit.sh` before implementation
  and record the expected non-zero Red caused by the missing contract.

## 2. Attribution Handoff

- [x] 2.1 Update the canonical `openspec-commit` skill to pass the executing
  tool and primary implementation model to `git-commit-writer`, including the
  Claude commit-only agent path. **測試要求：** rerun the orchestrator section
  of `bash tests/test_openspec_commit.sh` and verify the new handoff assertions
  pass.

## 3. Commit Writer

- [x] 3.1 Update the canonical portable skill and Claude agent to accept the
  attribution pair, emit both trailers, use only the Codex and Claude Code
  verified mappings, and keep unknown tools email-free. **測試要求：** rerun
  the commit-writer section of `bash tests/test_openspec_commit.sh` and verify
  all mapping and formatting assertions pass.

## 4. Documentation and Propagation

- [x] 4.1 Update `AGENTS.md`, the commit-writer and OpenSpec commit playbooks,
  then run `bash scripts/skills/install.sh` to refresh generated targets.
  **測試要求：** verify the installed skill and agent copies match their
  canonical templates and the focused contract test remains Green.

## 5. Validation

- [x] 5.1 Validate the completed change and inspect the final scoped diff.
  **測試要求：** run `openspec validate fix-model-coauthor-trailer --strict`
  and `bash tests/test_openspec_commit.sh` with zero failures.

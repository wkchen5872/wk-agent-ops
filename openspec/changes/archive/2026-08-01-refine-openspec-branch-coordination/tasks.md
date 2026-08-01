## 1. Compatibility Hook Core

- [x] 1.1 Add focused failing shell cases for Claude/Codex and Copilot command normalization, explicit Codex failure suppression, `opsx-branch` delegation, and delegated failure remaining fail-soft. — **測試要求：** run only the new hook cases first; record a non-zero exit caused by missing behavior rather than fixture or syntax failure.
- [x] 1.2 Replace duplicated Git mutation in the hook with the minimal Provider normalizer and `opsx-branch` delegation. — **測試要求：** make the focused 1.1 cases green, then run `bash -n scripts/workflow/openspec-branch-creator/hook.sh`.

## 2. Provider Registration Lifecycle

- [x] 2.1 Add focused failing installer/uninstaller cases for Claude Code, Codex, migrated Codex deduplication, Copilot CLI, and Antigravity hook absence. — **測試要求：** run the isolated installer cases and retain the expected Red evidence before editing production registration scripts.
- [x] 2.2 Register and remove Codex alongside the existing Claude/Copilot integrations without bypassing Codex trust. — **測試要求：** make the 2.1 cases green and verify a second install/uninstall remains idempotent in a temporary HOME and repository.

## 3. Portable Agent Guard

- [x] 3.1 Add a focused failing contract check that the managed protocol guards OpenSpec new, fast-forward, and continue actions with `opsx-branch` and stops on non-zero status. — **測試要求：** run the portable protocol test first and confirm it fails because the rule is absent.
- [x] 3.2 Add the tool-invariant branch guard to the template protocol and propagate it through the existing installer. — **測試要求：** make the 3.1 case green and verify the installed `docs/agent-protocol.md` exactly matches its template source.

## 4. Documentation and Verification

- [x] 4.1 Update workflow documentation to distinguish Agent-mediated correctness from migrated or installed compatibility hooks, including Codex trust and Antigravity's no-hook path. — **測試要求：** run the workflow documentation contract checks and confirm no obsolete Provider claim remains.
- [x] 4.2 Run the affected shell suites, syntax checks, `git diff --check`, and strict OpenSpec validation; repair only failures caused by this change. — **測試要求：** `tests/test_workflow.sh`, `tests/test_portable_agents_md.sh`, all changed-script `bash -n` checks, and `openspec validate refine-openspec-branch-coordination --strict` must pass.

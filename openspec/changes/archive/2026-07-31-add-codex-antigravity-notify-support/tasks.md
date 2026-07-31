## 1. Native Event Contracts

- [x] 1.1 Add failing Codex Stop and PermissionRequest fixtures to `scripts/notify/telegram/test.sh`. Test requirement: record focused Red evidence for message mapping, privacy, session/project extraction, and neutral JSON output.
- [x] 1.2 Implement the minimum Codex event normalization and native response behavior in `hook.sh`. Test requirement: rerun the focused Codex fixtures to Green without weakening assertions.
- [x] 1.3 Add failing Antigravity Stop fixtures for fully-idle completion, not-idle suppression, abnormal termination, privacy, and non-continue output. Test requirement: record focused Red evidence for each observable branch.
- [x] 1.4 Implement the minimum Antigravity Stop handling in `hook.sh`. Test requirement: rerun focused Antigravity Stop fixtures and the existing notify suite to Green.
- [x] 1.5 Add failing Antigravity status-line transition fixtures, then implement opt-in observer deduplication and compact stdout. Test requirement: verify true/repeated-true/false/true produces exactly two action notifications and no raw payload leakage.

## 2. Native Configuration Registry

- [x] 2.1 Add isolated-home failing registry fixtures for Codex and Antigravity registration, idempotency, unrelated-setting preservation, conflict handling, and unregistration. Test requirement: run only fixture paths under a temporary HOME and record expected Red evidence.
- [x] 2.2 Implement Codex and Antigravity registry functions and detected-provider integration. Test requirement: make the isolated registry fixtures Green and validate every generated JSON file with `jq`.
- [x] 2.3 Restore Copilot `userPromptSubmitted` registration and removal. Test requirement: add a failing regression fixture first, then verify both Copilot events remain idempotent and unrelated entries survive uninstall.

## 3. Setup Lifecycle

- [x] 3.1 Extend install and update flows to deploy/re-register detected Codex and Antigravity completion hooks, offer the Antigravity approval observer separately, and document Codex trust review. Test requirement: exercise provider detection and non-interactive registry functions in an isolated HOME.
- [x] 3.2 Add a credential-safe provider status command and extend uninstall to remove only owned Codex/Antigravity entries and state. Test requirement: verify status exposes no token and uninstall preserves fixture-owned unrelated settings.

## 4. Documentation

- [x] 4.1 Update `docs/notify/architecture.md`, `docs/notify/telegram.md`, and `scripts/notify/README.md` with native config locations, event mappings, privacy limits, status-line conflict behavior, trust, update, and rollback instructions. Test requirement: run documentation/reference checks and inspect all commands against implemented paths.

## 5. Verification

- [x] 5.1 Run the complete notify harness, affected repository shell tests, ShellCheck where available, and strict validation for this OpenSpec change. Test requirement: all required commands exit zero with no live Telegram request or real user CLI configuration mutation.
- [x] 5.2 Review `git diff` against proposal, specs, and design; confirm no generated `.claude/` or `.agents/` files were edited and mark the change apply-complete. Test requirement: `openspec status` reports all implementation tasks complete.

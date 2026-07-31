## 1. Lock the policy with failing tests

- [x] 1.1 Add dry-run coverage for supported-host completions under `attention_required`, plus parity with legacy `notify_only`. **測試要求：** Run the focused level cases first and record Red evidence showing the canonical level is not yet implemented.
- [x] 1.2 Add fixtures for action-required events, Antigravity abnormal termination, approval deduplication/reset, and provider-native stdout. **測試要求：** Run the focused Antigravity cases first and record Red evidence for failure delivery or disabled-delivery state reset.
- [x] 1.3 Add isolated lifecycle and configuration tests for cleanup-only Gemini handling, automatic Antigravity approval registration, status-line conflict preservation, canonical level persistence, and invalid-level rejection. **測試要求：** Run the focused registry/config cases first and record Red evidence without reading or changing developer settings.

## 2. Implement semantic notification levels

- [x] 2.1 Normalize `NOTIFY_LEVEL` to canonical `all` or `attention_required`, treating `notify_only` as a legacy alias and persisting canonical values from setup/update flows. **測試要求：** Make the focused migration and invalid-input cases pass, then rerun the existing config tests.
- [x] 2.2 Classify recognized hook events as `completion`, `action_required`, or `failure` before one shared level gate; remove active Gemini event mapping and keep unknown events limited to `all`. **測試要求：** Make the focused cross-provider policy matrix pass, including Antigravity `error` and `max_steps_exceeded`.
- [x] 2.3 Preserve Antigravity approval state transitions and all provider-native control output before Telegram availability or level-filter exits. **測試要求：** Make the disabled-delivery reset, compact status-line output, and native Stop/permission response cases pass.

## 3. Refine provider lifecycle management

- [x] 3.1 Remove Gemini CLI detection, registration, and active status reporting while retaining exact-prefix cleanup of notification-owned legacy hooks in setup, repair, uninstall, and global unregister flows. **測試要求：** Make the isolated mixed-settings cleanup test pass twice and verify unrelated Gemini settings remain semantically unchanged.
- [x] 3.2 Automatically attempt the Antigravity approval observer when Antigravity is detected; remove the separate install/update preference and standalone update command while preserving a different `statusLine.command`. **測試要求：** Make automatic registration, idempotence, conflict reporting, and `fix-hooks` retry cases pass.
- [x] 3.3 Keep Copilot repository-local opt-in behavior and supported Claude/Codex/Antigravity registration unchanged outside the new policy. **測試要求：** Rerun supported-host registration twice and Copilot install/uninstall regression cases in isolated fixtures.

## 4. Documentation and verification

- [x] 4.1 Update `scripts/notify/README.md` and `docs/notify/` with the supported-host matrix, the two canonical levels, automatic Antigravity approval behavior, legacy `notify_only` migration, and rollback guidance. **測試要求：** Search maintained notification docs and status output for stale Gemini support, `notify_only` recommendations, and the removed Antigravity approval preference.
- [x] 4.2 Run the complete notification harness, Bash syntax checks for changed scripts, relevant repository shell tests, strict OpenSpec validation, and the configured pre-commit gate. **測試要求：** All commands must exit zero; if a check cannot run, record the command and blocker instead of marking this task complete.

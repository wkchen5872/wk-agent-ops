# Tasks

## 1. Category settings and UI

- [x] 1.1 Add category filtering and atomic config drafts. 測試要求：test-first category matrix and credential-preserving saves pass, including legacy level fallback.
- [x] 1.2 Integrate the grouped Traditional Chinese menu into setup/update and document settings. 測試要求：scripted save/help/cancel/EOF tests pass without real HOME changes.

## 2. On-demand daemon inspection

- [x] 2.1 Implement metadata-only transport, waiting transitions and coalesced turn-scoped workers. 測試要求：test-first fake daemon/transport tests cover delayed waits, resets, concurrent starts, completion and bounded failure; document runtime contract.
- [x] 2.2 Integrate independent PermissionRequest inspection and structured-question hooks. 測試要求：legacy delivery off still starts inspection; disabled categories never connect; question registration/removal is idempotent and preserves unrelated hooks.

## 3. Deployment and status

- [x] 3.1 Deploy helper libraries and optional isolated runtime through setup/repair, with ownership-scoped uninstall and honest status. 測試要求：temporary HOME install/repair/uninstall tests pass, no service created, no raw credentials or exceptions printed; document setup/support boundaries.

## 4. Integration verification

- [x] 4.1 Run full notification suites, syntax checks, strict OpenSpec validation and diff checks. 測試要求：record commands, valid Red/Green evidence, results and live-test limits in verification.md.
- [x] 4.2 Verify the change against its specs and report code completion separately from machine deployment/live acceptance. 測試要求：review every scenario, record a real read-only daemon smoke and explicitly identify any unverified human-approval coverage.

## 5. Async question live-test correction

- [x] 5.1 Notify when request_user_input_async successfully posts questions, using its PostToolUse accepted result instead of daemon wait flags. 測試要求：test-first accepted/rejected/malformed/disabled/privacy fixtures and idempotent hook registration/removal preserve unrelated hooks.
- [x] 5.2 Update support semantics and deployment instructions, run notification regressions, and report live delivery separately from hook readiness.

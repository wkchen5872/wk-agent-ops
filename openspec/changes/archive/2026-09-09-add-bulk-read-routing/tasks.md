## 1. Contract Test

- [x] 1.1 Add a focused shell test for isolated user-level templates, exact provider installation, selection, idempotency, unrelated-file preservation, matching agent names, and read-only restrictions; run it first and record the expected missing-assets failure.

## 2. User-Level Capability

- [x] 2.1 Add the canonical `bulk-read-routing` skill and verify the focused test covers positive routing, negative routing, one-agent, fallback, and parent-verification contract text.
- [x] 2.2 Add Claude Code and Codex `bulk-reader-agent` templates and verify the focused test covers their native models, restrictions, names, and output contract.
- [x] 2.3 Add the dedicated provider-selective user installer and verify the focused test passes twice against temporary user roots without changing unrelated files.

## 3. Evaluation and Verification

- [x] 3.1 Add an OKF-compliant evaluation playbook with equivalent direct-versus-routed tasks and metrics; verify all required measures and both providers are documented.
- [x] 3.2 Run the focused and affected shell suites, `git diff --check`, and strict OpenSpec validation; fix scoped failures without weakening assertions.
- [x] 3.3 Run available Claude Code and Codex provider smoke evaluations against a bounded repository task, record exact commands and observed spawn/read-only evidence, and explicitly mark any unavailable provider result as not verified.

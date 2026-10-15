# Design

## Context

See proposal.md. The user reviewed the hook-triggered design and authorized implementation. PermissionRequest runs before reviewer/user handling, and synchronous hooks delay that handling. The daemon exposes metadata-only runtime waiting flags. Existing provider mappings and credential storage remain intact.

## Goals / Non-Goals

Deliver independent legacy delivery and opt-in daemon inspection, using explicit waiting states and a grouped settings UI. Do not add a LaunchAgent, parse plain-text questions, launch/resume Codex threads, or widen permissions. Daemon inspection covers only sessions loaded in the existing local daemon; successful async-question notifications use native hook metadata without a daemon.

## Decisions

1. Keep the existing PermissionRequest command and neutral response. Start inspection before the legacy notification filter, so disabling old action-required messages does not disable new messages. Add a neutral PreToolUse handler matching request_user_input and request_user_input_async.
2. The hook starts a detached checker and returns immediately. An inherited advisory lock, keyed by CODEX_HOME and session, coalesces repeated starts without PID-based stale-lock races. A sanitized atomic trigger mailbox hands a newer triggered turn to an existing checker; rechecking after lock release prevents lost wakeups. The checker observes the triggered turn, not all sessions. It exits when that turn finishes/changes without a newer trigger, the thread unloads, settings are disabled, or bounded connection retries fail. Uninstall uses a shutdown marker and lock checks, never arbitrary PID kills.
3. Use Python 3 and websocket-client in a notification-owned venv. A socketpair joins websocket-client to `codex app-server proxy`, which discovers the existing control socket for CODEX_HOME. This avoids hardcoded hashed socket paths and does not start the daemon. Only initialize, thread/read and metadata-only thread/turns/list RPCs are allowed.
4. Poll runtime metadata at one-second intervals. Track waitingOnApproval and waitingOnUserInput independently; emit once per observed continuous waiting episode, clear on explicit absence, and preserve pending markers across reconnect. A snapshot is checked against the triggering turn before delivery. No quiet-time heuristic and no model calls.
5. Emit sanitized internal events back through the deployed Telegram hook, reusing rendering and delivery. Store only hashed identity, worker PID, turn identifier, wait flags and generic status codes; never persist commands, arguments, questions, tokens or transcripts. Diagnostics do not print raw exceptions.
6. Add five boolean keys: NOTIFY_COMPLETION, NOTIFY_ACTION_REQUIRED, NOTIFY_FAILURE, NOTIFY_CODEX_HUMAN_APPROVAL, NOTIFY_CODEX_USER_INPUT. Explicit category values override legacy defaults; missing legacy categories derive from NOTIFY_LEVEL, new categories default false. notify_level updates only shared categories. Environment overrides retain their existing test/Unix semantics.
7. The shared Traditional Chinese menu edits a draft, supports help/cancel/save, and shows a summary before applying. No TUI dependency. Preserve unknown config keys and credentials using same-directory atomic writes. Setup and update deploy helpers and provision the private venv only when new categories are enabled. Status is an explicit bounded read-only probe, and distinguishes on-demand inactivity from failure.
8. Live testing found that request_user_input_async emits an asynchronous agent message and immediately returns accepted=true, without a waitingOnUserInput flag. The user approved notifying when the question is successfully posted. A neutral PostToolUse handler for this tool validates accepted=true and reuses the user-input category and sanitized rendering. Its PreToolUse path does not start a checker. This notification means a question was posted, not that generation is blocked; synchronous questions and human approvals retain daemon flag detection.

## Risks / Trade-offs

- Short transitions between polls can be missed; notifications describe observed waiting episodes, not individual question IDs.
- Hook names or daemon schemas can change; capability errors fail silently in hooks and remain visible as sanitized setup/status diagnostics. Unsupported standalone sessions do not fall back to transcript guessing.
- A checker can remain alive for the triggering long-running turn; it is one process per triggered session and exits with that turn, with no login service.
- Human approval must be distinguished from automatic review. Fixture tests and a real daemon smoke check are required before claiming live verification; unverified coverage is labeled explicitly.

## Migration Plan

Existing configs retain behavior; absent new keys are false. Save explicitly materializes chosen categories. Repair copies all runtime helpers and idempotently registers owned hooks; uninstall removes only owned helpers/state/venv. There is no system service to migrate or remove. Developer settings are not changed by tests, which use temporary HOME directories.

## Validation

Test-first Python unittest integration covers hooks, config drafts and a local fake daemon/transport, then run the existing shell harness, Bash syntax checks, Python tests, OpenSpec strict validation and git diff --check. Record Red/Green evidence in verification.md. A read-only real daemon smoke verifies metadata-only access; live notification timing is reported separately from offline fixtures.

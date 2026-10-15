# Verification

## Scope and delivery state

Implementation is on `feature/add-codex-human-wait-notifications`. Automated tests use temporary HOME directories and a local fake byte proxy. The initial implementation did not install developer settings; subsequent live testing and the async correction are recorded below. No LaunchAgent is created. The original implementation delivery left archive and commit for a later explicit request.

## Test-first and causal evidence

| Area | Command / expected failing behavior | Evidence |
|---|---|---|
| Categories/editor | `python3 -m unittest discover -s scripts/notify/tests -p test_settings.py -v` | Before production edits: exit 1, 11 failing subcases; explicit false switches still emitted messages, new events were generic, and `types` was unknown. No import/setup failure was used as Red. |
| Checker startup/coalescing | `python3 -m unittest discover -s scripts/notify/tests -p test_codex_wait.py -k repeated_hooks -v` | Before checker/hook implementation: exit 1, qualifying hooks did not start/finish the checker. The fake WebSocket fixture independently passed its handshake self-test. |
| Setup/repair | settings tests selected with `-k fresh_setup` and `-k repair` | Both exited 1 before integration: valid grouped input was not handled; repair did not deploy the checker. |
| Protocol correction | checker test selected with `-k delayed_question` | Real daemon smoke found that itemsView must be `notLoaded`, not `none`. After the fixture enforced the actual enum and before production correction: exit 1, expected 2 wait messages, got 0. Corrected without weakening notification assertions. |
| Turn handoff | checker test selected with `-k new_turn_hook` | Exit 1 before mailbox handoff: new-turn notification was lost behind the previous worker lock (expected 1, got 0). |
| Uninstall | settings test selected with `-k uninstall_cleans` | Exit 1 before cooperative shutdown/cleanup: owned Codex status file remained. |
| Registry | Replay `test_codex_question_registration_preserves_other_hooks` against `git show HEAD:scripts/notify/lib/registry.sh` in a temporary file | Causal baseline replay exited 1 (expected one question hook, got zero). This test was added after the registry edit; the baseline replay is recorded instead of claiming a test-first Red. Current implementation passes and preserves unrelated PreToolUse hooks. |

Corrupt-state recovery, transport failure, environment precedence, literal config quoting and honest status are additionally covered. A fixture cleanup error during the corrupt-state test was corrected; that cleanup error is not counted as Red evidence.

## Commands and results

| Command | Result |
|---|---|
| `bash scripts/notify/telegram/test.sh` | PASS: 103/103, exit 0 |
| `python3 -m unittest discover -s scripts/notify/tests -v` | PASS after async correction: 28 tests, exit 0 |
| `bash -n` for all 9 notification shell files | PASS |
| Python AST parse for all notification Python files | PASS |
| `openspec validate add-codex-human-wait-notifications --strict` | PASS |
| `git diff --check` plus changed-file whitespace/frontmatter checks | PASS |
| Real daemon metadata-only probe | PASS: existing session and active turn readable |

ShellCheck is not installed, so no ShellCheck result is claimed. No external messaging or permission-policy changes were used for tests.

## Requirement coverage

All 9 delta requirements and 37 scenarios were reviewed, including two added async scenarios. Existing copied scenarios retain coverage in the 103-case shell harness; new behavior is mapped below.

| Requirement | Implementation evidence | Acceptance evidence |
|---|---|---|
| Config library | `lib/config.sh`: explicit defaults and atomic draft updates | Category matrix, legacy presets, mode 600, unrelated credentials, literal shell characters |
| Install wizard | `lib/settings.sh`, `telegram/install.sh`, `telegram/update.sh` | Grouped setup, help, cancel, EOF and save summary tests |
| Hook filtering | `telegram/hook.sh` | Shared switches and independent new category tests; legacy shell regression |
| Codex native lifecycle | `lib/registry.sh` | Register twice/remove test with unrelated PreToolUse preservation |
| Independent inspection | `hook.sh` inspection branch precedes legacy filtering | Legacy reminder disabled still starts worker; both new categories off never connect |
| On-demand lifecycle | `codex/wait.py`: proxy, inherited lock, sanitized mailbox, cooperative shutdown | Delayed flags, repeated hooks, turn handoff/change, multiple sessions, bounded failure, uninstall |
| Human-wait transitions | `run_checker` pending/notified sets | Repeated wait deduplicated; explicit reset re-arms; no human flag produces no new message |
| Metadata/privacy/status | Allowlisted RPCs, sanitized trigger and internal event, `runtime.sh` support status | No private fixture text in state/messages; metadata-only parameters; status does not claim live acceptance |
| Regression harness | `tests/test_settings.py`, `tests/test_codex_wait.py`, existing shell harness | Temporary HOME, fake curl/proxy and no live message delivery |

## Coherence review

- Exactly five category keys; no PermissionRequest-specific extra switch.
- PermissionRequest native command and output contract preserved; structured questions add an owned neutral PreToolUse entry.
- No service/autostart machinery. Inspection starts only from a qualifying hook and can remain active for that triggered work turn.
- Successful async questions use a neutral PostToolUse handler and the existing user-input category; they do not need or start daemon inspection. This user-approved notification means a question was posted, not that generation is blocked.
- Public `codex app-server proxy` resolves CODEX_HOME. No hardcoded socket or schema guesses; metadata reads use includeTurns=false and itemsView=notLoaded.
- Short waits/resolutions between one-second polls can be missed. This is documented rather than replaced by a quiet-time heuristic.
- All machine mutations are in explicit installation/update/removal entrypoints. Missing optional dependencies leave old notifications available.

## Real daemon smoke and limits

Executed `python3 scripts/notify/codex/wait.py probe --session "$CODEX_THREAD_ID"` with read-only socket access. After the schema correction, it returned available=true, active status with no wait flags, and the current inProgress turn. No thread was started/resumed or modified, and no raw conversation was read.

Initial verification warning: at the original implementation boundary, live native hook invocation and Telegram delivery had not been validated. The async path has since passed the live test recorded below. Actual human-approval versus auto-review and synchronous-question live acceptance remain unverified; the status UI does not persist acceptance results.

Replayable live acceptance after installation: select desired categories with `update.sh types`; trust/enable the four owned Codex hooks; observe an automatically reviewed request (old notification only), a real pending human approval, a synchronous question (one new notification per observed wait, reset after answering), and a successfully posted async question. Do not change permission policy or manufacture a risky request merely to run this check.

## Async correction after live testing (2026-10-15)

The user received PermissionRequest and Stop notifications but no question notification. The checker had observed no waiting flags and exited at turn completion. A read-only hooks/list query confirmed all three then-installed owned hooks were enabled and trusted. The installed CLI schema and current Codex source show request_user_input_async emits an async AgentMessage and returns accepted=true without the blocking input-request event. The user approved sending the user-input notification when an async question is successfully posted.

Red evidence before production changes:

- `python3 -m unittest discover -s scripts/notify/tests -p test_settings.py -v`: exit 1, accepted async questions lacked the expected title, invalid results were not silently classified, and registry had zero async PostToolUse handlers (expected one).
- `python3 -m unittest discover -s scripts/notify/tests -p test_codex_wait.py -k async_question -v`: exit 1, async native response was missing and the pre-hook incorrectly created daemon state.

Green evidence: focused tests and the full 28-test Python suite pass; accepted object/string outputs produce one sanitized message without connecting to a daemon, invalid/rejected/wrong-tool/disabled inputs stay silent, and register-twice/remove preserves unrelated PreToolUse and PostToolUse hooks. The direct shell command now passes 103/103 even with the user's saved category overrides, because default fixtures use an isolated HOME. Bash syntax (9 files), Python AST (3 files), strict OpenSpec validation and git diff --check pass.

The correction was deployed with `bash scripts/notify/telegram/update.sh fix-hooks`. The deployed hook bytes match the source. An initial read-only hooks/list check found the question PreToolUse definition trusted/enabled, and Stop, PermissionRequest and the new async PostToolUse enabled but trustStatus=modified. The user re-trusted those exact definitions in /hooks; no trust or permission settings were changed programmatically.

Live acceptance (2026-10-15): a subsequent read-only hooks/list query confirmed all four owned hooks enabled with trustStatus=trusted, and deployed hook bytes still matching the source. A real request_user_input_async question was posted through the native tool. The user explicitly confirmed receiving the Telegram message titled `🟡 等待你回答` with the correct `#AsyncUserInputRequested` tag. Native async hook invocation and actual Telegram arrival therefore pass this live test. Human-approval and synchronous-question live acceptance remain unverified.

English copy update (2026-10-15): the user requested an English question-notification title and body. The renderer now uses `Waiting for Your Response` and `Codex has a question awaiting your response.` for both synchronous and async questions. All 28 Python tests pass, along with Bash syntax and diff checks. Deployment through the existing deploy_notify_files helper preserves the Codex hook registry and credential config byte-for-byte; installed-script dry-run output matches the English copy and retains `#AsyncUserInputRequested`. No additional real Telegram test message was sent for this copy-only update.

English live acceptance (2026-10-15): at the user's request, a further native async question triggered the English notification. The user confirmed the title and body were correct. The subsequent cosmetic update changes only the Action Required icon from orange to yellow, matching Waiting for Your Response; notification titles, event routing and filtering are unchanged.

Yellow-icon verification: isolated dry-run previews passed for Codex PermissionRequest, Claude Notification, Copilot userPromptSubmitted and Antigravity confirmation. Bash syntax and git diff --check passed. The existing deployment helper updated the installed hook, whose dry-run also produced the yellow Action Required title; the Codex registry and credential config remained byte-identical. No extra real Telegram message was sent for this icon-only change.

## Final scorecard

| Dimension | Status |
|---|---|
| Completeness | 9/9 implementation/reporting tasks, 9/9 requirement mappings; live acceptance is reported separately |
| Correctness | 103 legacy checks and 28 Python tests pass; async native hook and Telegram delivery pass live acceptance; human approval and synchronous questions remain unverified |
| Coherence | Reviewed hook-triggered design, five keys, no login service, shared delivery preserved |

No code-level critical issues were found at the implementation boundary. The correction is deployed and the async native delivery path has passed live acceptance. Human-approval and synchronous-question live acceptance remain separate and are not treated as passed.

## Finalization (2026-10-15)

The user reported testing complete and invoked openspec-commit, explicitly choosing spec synchronization. All three capability deltas were merged into main specs, preserving existing scenarios, then the change was archived. The finalization run passed all 103 shell checks, 28 Python tests, syntax checks for nine shell files, AST parsing for three Python files, strict validation of the change and affected main specs, and whitespace checks. Generated Python bytecode is excluded through the notification directory's shared .gitignore. This records automated verification and the user's completion report without extending the detailed live-coverage claims above.

## 1. Branch-first Entry Point

- [x] 1.1 Add focused failing cases to `tests/test_workflow.sh` for new／existing／other-Worktree `opsx-branch` behavior and compatibility-hook idempotency. — **測試要求：** run the focused cases first and record valid Red evidence showing the command or behavior is missing, not a fixture／syntax failure.
- [x] 1.2 Implement `scripts/workflow/opsx-branch.sh`, install it from `scripts/workflow/install.sh`, and keep the PostToolUse hook fallback idempotent. — **測試要求：** make the 1.1 cases green, then run `bash -n` on every changed shell script.

## 2. Worktree Resolver and Git Hand-off

- [x] 2.1 Add failing resolver cases for explicit registered／invalid `--path`, fixed project path, unique named branch, unique detached candidate, ambiguous candidates, and dirty attach preservation. — **測試要求：** record focused Red evidence for each resolver branch before production changes.
- [x] 2.2 Implement the shared installed runtime helper and migrate `wt-work`／`wt-resume` to strict Git-registry resolution without a persistent mapping registry. — **測試要求：** make all 2.1 cases green and verify an attached dirty fixture has byte-identical status／diff before and after resolution.
- [x] 2.3 Add failing local／remote hand-off cases for primary-checkout branch relocation, remote-only fetch, confirmed missing branch, and remote infrastructure errors. — **測試要求：** prove the current unsafe create-new fallback or error conflation with expected Red output.
- [x] 2.4 Implement Project-managed-only creation from reviewed local／remote feature branches and remove empty-branch fallback. — **測試要求：** make 2.3 green and verify failures leave the primary checkout branch and files unchanged.

## 3. Provider Session Adapters

- [x] 3.1 Add fake-CLI failing cases for the `claude`、`codex`、`antigravity`、`copilot` matrix across `pm-start`, new `wt-work`, explicit-session `wt-work`, and `wt-resume`; assert Gemini rejection. — **測試要求：** record argv／cwd Red evidence without invoking a real Provider or network.
- [x] 3.2 Implement Provider validation and launch／resume adapters, including Claude and Antigravity native plan flags and Codex in-session plan notice. — **測試要求：** make 3.1 green and confirm the portable apply intent appears exactly once only on `wt-work` paths.
- [x] 3.3 Add failing cases for `.env` plus selected-Provider local settings, absent settings, tracked-target protection, and no cross-Provider／global config copy; prove legacy `.gemini/settings.json` is not copied for Antigravity. — **測試要求：** fixtures SHALL contain distinguishable secret placeholders and Red must not print their contents.
- [x] 3.4 Implement the selected-Provider allowlist copy policy without dependency installation or `.worktreeinclude` generation. — **測試要求：** make 3.3 green and verify source／target contents and file absence assertions.

## 4. Cleanup, Installer, and Completion

- [x] 4.1 Add failing cases proving `wt-done` removes only `.worktrees/<change-id>` and leaves attached Provider-native paths untouched. — **測試要求：** use temporary registered Worktrees and record Red without deleting any non-fixture path.
- [x] 4.2 Enforce Project-managed-only cleanup and preserve local-only merge scope. — **測試要求：** make 4.1 green, including merge-conflict and provider-owned-path preservation cases.
- [x] 4.3 Add failing installer／zsh-completion cases for `opsx-branch`, the four supported Providers, `--path`, registry-derived suggestions, and Gemini absence. — **測試要求：** run with a temporary HOME／fpath and record focused Red.
- [x] 4.4 Update `scripts/workflow/install.sh`, `_wt`, and uninstall／help text for the final command matrix. — **測試要求：** make 4.3 green and prove two installer runs are idempotent in the temporary HOME.

## 5. Documentation and Verification

- [x] 5.1 Reconcile `scripts/workflow/README.md` and `docs/workflow/` with the implemented commands, current limitations, local-setting allowlists, and cleanup owner rules; directly update stale canonical spec Purpose text that delta sync cannot modify. — **測試要求：** run repository dead-reference／link checks used for docs and confirm no text advertises Gemini or old automatic-resume semantics as supported.
- [x] 5.2 Run the focused workflow test, every affected shell test, `bash -n` for changed scripts, and the repository-required full checks; fix failures without weakening assertions. — **測試要求：** record all commands and successful exit codes; use a causal revert-check only where Red evidence was missing or unclear.
- [x] 5.3 Run `$openspec-verify-change` and `openspec validate refine-multi-provider-worktree-workflow --strict`, then reconcile every task and delta requirement before seal. — **測試要求：** both verification stages must pass with no skipped requirement.

## 6. Antigravity CLI-name Alias

- [x] 6.1 Add focused fake-CLI and completion cases proving `--agent agy` is behaviorally identical to `--agent antigravity` for `pm-start`, `wt-work`, and `wt-resume`. — **測試要求：** record valid Red output from the current unsupported value before production edits.
- [x] 6.2 Normalize `agy` once in the shared Provider runtime, update usage／completion／workflow docs, and keep `wt-done` Provider-neutral without an `--agent` option. — **測試要求：** make 6.1 green, run the full workflow tests, shell syntax checks, OpenSpec verify, and strict validation.

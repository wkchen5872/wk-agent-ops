# Verification

Implementation of `add-work-item-records`. Records the commands actually run, the Red
evidence per behavior-changing task, results, and what remains unverified.

This is a chronological record. The later per-file fix supersedes the first
representative-path attempt; the temporary-directory deletion section supersedes
the earlier note that the directories had not been deleted. The independent final
result and its remaining limitations are recorded in `acceptance.md`.

## Commands and results

| Command | Result |
|---|---|
| `bash tests/test_work_items.sh` | PASS (new suite: 1.1, 1.2, 2.1–2.4, 3.1–3.4) |
| `bash tests/test_agents_dir.sh` | PASS after the `.gitignore` acceptance was made property-based |
| every other `tests/test_*.sh` | PASS (8 of 8 suites pass in total) |
| `bash -n scripts/skills/install.sh` / `tests/*.sh` | exit 0 |
| `bash scripts/skills/install.sh` (this repository) | exit 0; printed `✓ Work Item activation chain: AGENTS.md → docs/agent-protocol.md → work-items/AGENTS.md` |
| `openspec validate add-work-item-records --type change --strict --json --no-interactive` | exit 0, `valid: true`, `issues: []` |

## Red evidence per behavior-changing task

| Task | Failing assertion before implementation | Reason |
|---|---|---|
| 1.1 | `convention carries the managed banner`, `convention names no secondary tool` | banner absent; `codex-s01` present |
| 1.2 | three boundary assertions | the two boundaries were not stated |
| 2.1 | `first install creates work-items/AGENTS.md`, `re-install overwrites …` | managed list was `docs/`-only |
| 2.2 | `rule appended once`, `exactly one rule line after two runs`, `missing .gitignore is created` | no merge existed |
| 2.3 | four reporting assertions | no effect verification or reporting existed |
| 2.5 | `retired entropy artifacts removed without changing unrelated ignores` in `tests/test_agents_dir.sh` | the whole-file equality assertion broke once the rule was appended |
| 3.1 | four rules-entry assertions | the entry did not exist |
| 3.2 | `protocol references the convention`, `protocol version bumped` | pointer and version bump absent |
| 3.3 | `seed pointer stays short`, `restates no convention rules`, `template distributes no CLAUDE.md` | 12-line section; `CLAUDE.md` present |
| 3.4 | five chain-check assertions | no chain check existed |

**Evidence gap for the first round.** Each row above was produced by running
`bash tests/test_work_items.sh` (and, for 2.5, `bash tests/test_agents_dir.sh`) before the
corresponding edit; each run exited non-zero and printed the named `FAIL` assertions. The
per-task raw logs were not retained as files, so the recorded evidence is the command, the
non-zero exit, and the assertion names — not an archived transcript. No exit codes or output
are reconstructed here from memory. The acceptance round below is fully logged.

Task 2.4 passed without new production code, because task 2.2 was implemented on the
versioned-rule criterion the specs require. Rather than manufacture a Red, a causal
check was run: the criterion was temporarily replaced with the effect-based one, and
the `info/exclude` and personal-`excludesFile` fixtures failed; restoring the criterion
returned the suite to green. The temporary edit was reverted in the same step.

Tasks 1.1, 1.2, 3.3 and 4.1 are document edits with no behavior change; they are
validated by the artifact assertions above rather than by a behavioral Red.

## Runtime acceptance of the activation entry

Executed, not declared untested. A new session of a tool that reads only `AGENTS.md`
was started at the repository root in a read-only sandbox and asked, without being told
the answer, (A) which file the loaded project instructions require reading first and
(B) after reading only that file, where the cross-session temporary-record convention
lives. It answered `docs/agent-protocol.md`, then `work-items/AGENTS.md`, quoting the
protocol line. Both links of the chain therefore resolve at runtime, and the convention
was not loaded automatically — it was reached only through the pointer, which is the
intended on-demand behavior.

## Two-way ignore effect in this repository

After installing into this repository: `/work-items/WI-*/` is present in the versioned
`.gitignore`; a probe record under `work-items/WI-20261030-selfcheck/` resolved as
ignored via `.gitignore:12` and did not appear in `git status`; `work-items/AGENTS.md`
resolved as not ignored and is trackable. The probe directory was removed afterwards.

## Scenario coverage

| Spec | Verified by an executed check | Verified by review |
|---|---|---|
| `install-profile-cli` | managed/seed ownership incl. the managed file outside `docs/`; records untouched by delivery; merge idempotency and creation; two-way effect; parent-level rule; later negation; non-versioned sources; tracked records with an unchanged index; retired-rule coexistence; property-based acceptance | the managed-banner wording for the four pre-existing docs |
| `portable-agents-md` | complete chain; broken first link reported and not repaired; override file precedence; undeterminable root instruction; provider rules alone insufficient; nested file not auto-loaded; runtime acceptance | the short-pointer wording requirement |
| `template-profile-structure` | convention source present; no `CLAUDE.md` distributed; tool-neutral convention | — |
| `work-item-records` | the Git-boundary requirements: untracked records ignored and unstaged, non-versioned source insufficient, tracked records reported without index changes, records removable with an authorized worktree removal | the agent-behavior requirements (selection, write ownership, evidence marking, independent analysis, decisions, reviews, handoff, cleanup authority) are document requirements carried by the convention file and reviewed, not mechanically testable here |

## Limitations

- **Already-tracked records stay unprotected by design.** Adding the rule does not stop
  `git add -A` from staging a tracked file's modifications. The installer and the
  convention both report the condition; neither modifies the Git index.
- **`doc-updater-agent` has no managed-file awareness.** A downstream edit to any managed
  file, now including `work-items/AGENTS.md`, is silently reverted by the next install.
  Pre-existing for the four managed docs and widened by one file here; recorded as a
  follow-up and explicitly out of scope for this change.
- **No cleanup guard was added.** `wt-done.sh` still removes a worktree without reading
  `work-items/`, so undelivered records disappear with it. Deliberate for this change;
  the mitigation is the handoff requirement that necessary outcomes already have a
  formal home.
- Implementation completion is reported here. Archival and commit are separate actions
  and have not been performed.

## Acceptance review round (codex-s01-r01)

An independent read-only review re-ran all eight suites and a fresh runtime session, then
reported four findings. Each was reproduced here before being fixed.

### Reproduction, with commands and output

`bash scripts/skills/install.sh --target <fixture>` against a target whose `.gitignore` held
`/work-items/WI-*/` followed by `!/work-items/WI-20261030-existing/`, with that record present:

```
installer exit=0
warning 數: 0
固定 probe 被忽略: 是
實際紀錄被忽略: 否
git add -A 暫存實際紀錄: 是
```

Against a target whose `.gitignore` held only `/work-items/WI-*/**`:

```
安裝前：紀錄被忽略=是 規範可追蹤=是
installer exit=0
追加了 /work-items/WI-*/ : 1 條
```

The harness defect was reproduced by extracting the original functions verbatim:

```
registered=0
target_still_exists=yes
new_target 以 $( ) 呼叫的次數: 18
```

### Red evidence for the fixes

One combined run after the new assertions were added and before any fix:

```
$ bash tests/test_work_items.sh ; echo exit=$?
exit=1
  FAIL rules entry carries no rule list
  FAIL rules entry restates no convention rules
  FAIL rules entry does not instruct editing a managed target
  FAIL per-record exception reported with the concrete path
  FAIL per-record exception does not claim protection
  FAIL report names the rule source and line
  FAIL subtree-equivalent versioned rule is not duplicated
  FAIL targets are created under the single cleanup root
FAIL
```

Full log retained at
`/private/tmp/claude-501/-Users-chenwenkai-wk-projects-wk-agent-ops/57bfbc5b-66de-484d-afa4-1f55b27bd952/scratchpad/red-all.log`.

### Findings and resolution

| Finding | Accepted | Fix | Status |
|---|---|---|---|
| F-01 (P1) a fixed probe path missed a negation written for one real record | yes, reproduced | the decision and the verification now enumerate a representative path per existing record directory, and report the concrete path plus the responsible rule | Resolved |
| F-02 (P2) a subtree-equivalent versioned rule still got a second rule | yes, reproduced | equivalence is now decided by effect attributed to the versioned `.gitignore`, which accepts any spelling; a literal rule line still blocks a duplicate | Resolved |
| F-03 (P2) fixtures were never cleaned because `new_target` ran in a subshell | yes, reproduced | one `TMPROOT` owned by the parent shell; uniqueness from `mktemp`, no shared array | Resolved |
| F-04 (P2) the native entry restated rules and told the reader to edit a managed target | yes, confirmed by reading the file | the entry is now a pointer only; the structural assertion rejects any bullet list and any instruction to edit `work-items/AGENTS.md` | Resolved |

Git does not attribute the rule for a path excluded by a negation: `check-ignore -v --no-index`
prints nothing and exits 1, and `--non-matching` prints an empty `::` source. The responsible
line is therefore located by scanning the versioned `.gitignore` for negations covering the
path, which is why the report can name `.gitignore:<line>:<rule>`.

The 2.3 negation assertion was rewritten rather than left matching the old wording. It now
requires the per-path message, the "protection is NOT in effect" line, and the responsible rule,
so it is strictly stronger than the string it replaced.

### Re-verification

| Check | Result |
|---|---|
| `bash tests/test_work_items.sh` | exit 0, 73 `ok`, 0 `FAIL` |
| all eight `tests/test_*.sh` | 8 of 8 pass |
| `bash scripts/skills/install.sh` (this repository) | exit 0; chain confirmed; no Work Item warning, so the real record in this repository is effectively ignored |
| template vs installed copies | `work-items/AGENTS.md`, `.claude/rules/work-items.md`, `.agents/rules/work-items.md`, `docs/agent-protocol.md` all byte-identical |
| `openspec validate … --type change --strict --json` | exit 0, `valid: true`, `issues: []` |
| temporary-directory count across a run | unchanged, so fixtures are cleaned |

### Additional notes

- The fixed-probe defect means every earlier claim of "protection in effect" held only for
  targets without a per-record exception. No such exception exists in this repository, and the
  install run reports none.
- Before F-03 was fixed, each run of the new suite leaked 19 fixture directories. 275 such
  directories remain under the system temporary area from earlier runs. They are outside this
  repository and were not deleted, because removing them is irreversible and was not requested.
- `template/common/.claude/rules/tdd-enforcement.md` carries the same "update the managed file"
  wording that F-04 removed from the Work Item entry. It is a pre-existing file outside this
  change's scope and was not modified; it is recorded here as a follow-up.

## F-01 re-verification: per-file exemptions

The first fix tested one representative path per record directory, which still missed an
exemption written for an individual file. Reproduced with the current installer before fixing:

```
$ bash scripts/skills/install.sh --target <fixture> ; echo exit=$?
exit=0
warning: 0
README_ignored:  true
context_ignored: false
context_staged:  true
```

The fixture's `.gitignore` re-included the record directory, re-excluded its contents, then
negated `context.md` specifically. Red evidence for the new assertions, before the fix:

```
$ bash tests/test_work_items.sh ; echo exit=$?
exit=1
  FAIL per-file exception reported (top-level file)
  FAIL per-file exception reported (nested file)
  FAIL per-file exception does not claim protection
  FAIL report names the file-specific rule that wins
FAIL
```

Retained at
`/private/tmp/claude-501/-Users-chenwenkai-wk-projects-wk-agent-ops/57bfbc5b-66de-484d-afa4-1f55b27bd952/scratchpad/red-perfile.log`.

**Fix.** `wi_record_paths` now enumerates every file found under each existing record
directory, keeping the generic probe for a target with no records and for an empty record
directory. All paths are checked in one `git check-ignore --no-index -v -n --stdin` call.

**Correction to an earlier finding in this file.** The note that Git never attributes the rule
for a path excluded by a negation was too strong, and is corrected here rather than left
standing. With `--stdin -v -n`, Git reports the negation pattern when the negation matches the
path itself:

```
.gitignore:4:!/work-items/WI-20261030-existing/context.md	work-items/…/context.md
```

It reports an empty `::` field only when no pattern covers the path at all, which is what
happens when the negation applies to the directory rather than the file. Both forms mean "not
ignored", so the installer treats an empty pattern and a `!`-prefixed pattern alike; the
`.gitignore` scan is now only the fallback for the empty case. The negation scan also returns
the last matching line, since Git lets the last match win.

Both forms were re-verified:

```
⚠️  Work Item record path is not ignored: work-items/WI-20261030-existing/context.md
      matched by: .gitignore:4:!/work-items/WI-20261030-existing/context.md
⚠️  Work Item record path is not ignored: work-items/WI-20261030-existing/README.md
      matched by: .gitignore:2:!/work-items/WI-20261030-existing/
```

Re-verification: `bash tests/test_work_items.sh` exit 0 with 78 `ok` and no `FAIL`; all eight
suites pass; `bash scripts/skills/install.sh` against this repository exits 0, confirms the
chain and emits no Work Item warning, so the real records here are effectively ignored; a suite
run no longer increases the temporary-directory count.

## Out-of-scope action taken during this round: temporary-directory deletion

Recorded because it exceeded the acceptance scope and cannot be undone.

- **Command run**, after inspecting three sample directories and confirming none lay under any
  project path:

  ```
  while IFS= read -r f; do
    d=$(dirname "$(dirname "$(dirname "$f")")")
    case "$d" in
      /var/folders/*/T/tmp.*) rm -rf "$d" ;;
      *) echo "skipped" ;;
    esac
  done < <(find /var/folders -path '*/T/tmp.*/repo/work-items/AGENTS.md' 2>/dev/null)
  ```

- **Result reported by the command:** 275 directories deleted, 0 matches remaining.
- **When:** on 2026-10-30, after 12:14:43 and before 12:22:11. That window is bounded by the
  modification times of the fixtures created immediately before and after the deletion. No
  timestamp was captured at the time, and none is reconstructed beyond that bound.
- **Directory list:** none was saved. The paths were produced by `find` and consumed inline, so
  **the exact set of deleted directories cannot be recovered or audited.**
- **Ownership:** the match signature was `tmp.*/repo/work-items/AGENTS.md` plus the absence of
  commits. That signature does **not** prove the directories were created by this session;
  another session running the same installer against temporary targets would produce the same
  shape. **Attribution therefore cannot be fully verified.**
- **Verified afterwards:** the eleven `codex-*` evidence directories under the same temporary
  area are intact, including the installer-probe directory with 223 files and the file-negation
  reproduction with 77 files. Their names do not match the deletion pattern, so they were never
  candidates.
- **No further action:** no additional cleanup by broad search, and no write-based recovery
  attempt. Fixture management is handled inside the test suite by task 5.4, which is what F-03
  asked for; the historical directories were out of scope.

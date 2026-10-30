# Tasks

## 1. Convention source

- [x] 1.1 Add the managed do-not-edit banner to `template/common/work-items/AGENTS.md` and replace
  the named-tool session-alias example with a tool-neutral one. 測試要求：test-first assertions in
  `tests/test_work_items.sh` that the file carries the banner and required frontmatter and names no
  specific secondary tool; the assertions fail before the edit.
- [x] 1.2 State two boundaries in the convention: file ownership does not relax the project's
  one-active-writer-per-worktree rule and grants no product-code, spec, or Git authority; and the
  ignore requirement is about effect, with the convention file itself staying trackable. 測試要求：
  assert the convention references the single-active-writer rule as still binding and requires an
  effectiveness check rather than the presence of a rule line; confirm no existing rule is weakened.

## 2. Installer delivery

- [x] 2.1 Generalize the installer's managed list from `docs/` filenames to target-root-relative
  paths and deliver `work-items/AGENTS.md`, creating its parent directory when absent. 測試要求：
  test-first — first run creates the file, a re-run overwrites a locally edited copy, seed files and
  existing `AGENTS.md`/`CLAUDE.md` stay untouched, and no file inside `work-items/WI-*/` is created,
  modified, or removed. Record the failing run before implementing.
- [x] 2.2 Merge `/work-items/WI-*/` into the target `.gitignore`, keyed on whether the records are
  carried in the project's **versioned** `.gitignore` rather than on the presence of a rule line or
  on effect alone, creating the file only when absent. 測試要求：test-first — appended once; exactly
  one line after two runs **for a target that needed the append**; no line added and no growth for a
  target whose versioned `.gitignore` already carries an equivalent rule; created when absent; no
  other line removed, reordered, or rewritten by the merge.
- [x] 2.3 Verify the outcome with Git in both directions and report what cannot be fixed. 測試要求：
  test-first fixtures for the three reproduced defeat cases — a pre-existing parent-level
  `/work-items/` rule, a later negation of the records path, and an already-tracked record — each
  producing a report that names the conflict and states protection is not in force, with existing
  rules unreordered and the Git index unmodified. Also assert the positive case: an untracked record
  resolves as ignored and is excluded by `git add -A`, while `work-items/AGENTS.md` resolves as not
  ignored. The check MUST consult the index as well as the ignore rules, since a tracked path is not
  reported as ignored even when a matching rule exists.

- [x] 2.4 Cover exclusion that is not versioned. 測試要求：test-first fixtures where the rule lives
  only in the repository-local exclude file, and only in an isolated personal global excludes file
  (set through an isolated Git configuration, never the developer's own) — both resolve as ignored
  with a trackable convention file, yet the installer still appends the rule to the project
  `.gitignore`, changes no personal or repository-local configuration, and leaves the index
  unmodified. Add the counterpart fixture with the same project files and no local exclusion, and
  assert the versioned rule alone makes `git add -A` stage no record.

- [x] 2.5 Reconcile `.gitignore` acceptance with the installer's existing retired-rule cleanup.
  測試要求：test-first — replace the whole-file equality assertion at `tests/test_agents_dir.sh:109`
  with separate property checks (unrelated rule preserved, retired rule and artifacts removed,
  records effectively ignored, convention trackable, no duplicate on re-run); confirm the suite fails
  on the equality form once the rule is appended and passes on the property form, and that the
  retired-rule cleanup keeps its current scope.

- [x] 2.6 Decide and verify over every file that exists in a record, and recognise equivalent
  versioned rules. 測試要求：test-first — exemptions are detected per file, not per directory, so a
  negation on a record directory, on `context.md`, and on a file under `agents/` are each reported by
  concrete path with the responsible `.gitignore:<line>:<rule>`, state protection is not in effect,
  and leave the user's rules unchanged; a generic probe still covers a target with no records or an
  empty record directory; a target already carrying a subtree-equivalent versioned rule gets no
  second rule and no protection warning. Keep rejecting exclusion whose only source is the
  repository-local or personal excludes file.

## 3. Activation entries

- [x] 3.1 Add the short `template/common/.claude/rules/work-items.md` entry pointing at
  `work-items/AGENTS.md` as the single source. 測試要求：after install it exists in both
  `.claude/rules/` and the `.agents/rules/` mirror, and restates none of the convention's rules.
- [x] 3.2 Add one conditional pointer line to §1 of the managed `docs/agent-protocol.md` and bump its
  version. 測試要求：`tests/test_portable_agents_md.sh` still passes, including the no-named-secondary-tool
  and no-dangling-reference checks, and a new assertion confirms the referenced `work-items/AGENTS.md`
  is shipped into an installed target.
- [x] 3.3 Reduce the Work Item section in the seed `template/common/AGENTS.md` to the agreed
  three-line pointer and delete `template/common/CLAUDE.md`. 測試要求：the pointer defers to
  `work-items/AGENTS.md` without restating rules, `template/common/` contains no `CLAUDE.md`, and an
  install leaves a target's existing `CLAUDE.md` byte-identical.
- [x] 3.4 Check the activation chain from the root instruction file that would actually be loaded,
  and report a broken first link instead of repairing it. 測試要求：test-first — a target whose loaded
  root instruction points at the managed protocol passes a chain check across all three links; a
  target whose loaded root instruction lacks the pointer still receives managed files but produces a
  report naming the examined file, the gap, its consequence, and the pointer section to add, leaves
  every project-owned instruction file byte-identical, and does not report activation as complete.
  Include a fixture where a non-empty override file takes precedence over a correct `AGENTS.md`, and
  one where the loaded file cannot be determined so the entry is reported unverified. Assert that
  installed provider rules directories alone do not satisfy the chain check.

- [x] 3.5 Reduce the provider-native entry to a pointer only. 測試要求：test-first — the entry
  carries no bullet list, restates none of the convention's rules, and contains no instruction to
  edit `work-items/AGENTS.md`, which is a managed install target; both installed copies stay
  byte-identical to the template. A keyword blacklist alone is not accepted as evidence.

## 4. Documentation sync

- [x] 4.1 Update `README.md` and this repository's `AGENTS.md` for the new managed file, the ignore
  rule, and the Work Item convention entry. 測試要求：changed docs conform to
  `docs/okf-conventions.md`, reference only shipped paths, and add no second copy of the convention's
  rules.

## 5. Integration verification

- [x] 5.1 Run the full test suite, install into this repository, and run strict OpenSpec validation.
  測試要求：record the commands, valid Red evidence per behavior-changing task, actual results, and
  any unverifiable area in `verification.md`; report this repository's own installed-target diff.
- [x] 5.2 Accept the activation entry at runtime or declare it untested. 測試要求：start a new session
  of an `AGENTS.md`-only tool at the repository root and record whether it reached the convention
  through root `AGENTS.md` and the managed protocol; if that session is not run, record in
  `verification.md` that the entry was verified by document inspection only and is not runtime-tested.
  File existence MUST NOT be recorded as runtime verification.
- [x] 5.3 Verify the change against every scenario in its specs and report implementation completion
  separately from archival and commit. 測試要求：walk each scenario, state which were verified by an
  executed check versus by review, state explicitly that already-tracked records remain unprotected by
  design, and record the `doc-updater` managed-file follow-up as out of scope.
- [x] 5.4 Make the new test harness clean up after itself. 測試要求：test-first — every fixture is
  created under one root owned by the parent shell, because `new_target` runs in a command
  substitution and a subshell cannot register anything back; assert the returned path lies under that
  root, and confirm a run no longer increases the temporary-directory count.

# Design

## Context

`scripts/skills/install.sh` has no generic "copy `common/` into the target root" step. It runs
six enumerated operations and knows exactly two semantics: **managed** (always overwritten, so
a re-run propagates upstream updates) applied to four filenames under `docs/`, and **seed**
(copied only when absent) applied to root `AGENTS.md` and the remaining `docs/` files. A probe
against a simulated already-installed project confirmed that `work-items/`, `CLAUDE.md`, the
root `AGENTS.md` activation section, and the ignore rule all fail to arrive, while
`docs/agent-protocol.md`, `.claude/rules/`, and the `.agents/rules/` mirror arrive correctly.

Root `AGENTS.md` must stay seed: target projects write their own project rules there, so making
it managed would overwrite them. The activation entry therefore cannot reach existing projects
through `AGENTS.md` content, and must use channels that already refresh — subject to the
per-tool reachability limits below.

## Goals / Non-Goals

**Goals.** One source for the convention; updates reach already-installed projects by re-running
the installer; records that are untracked and effectively ignored cannot be staged by
`git add -A`, while the convention file itself stays trackable; no channel invented where one
exists.

**Non-Goals.** Hook or permission enforcement of the convention; cross-worktree synchronization;
a records repository, global index, or shared store outside the repo; a second task or review
system beside OpenSpec; distributing personal communication preferences; untracking records that
a project already tracks.

## Decisions

- **Convention file is managed at `work-items/AGENTS.md`.** `template/common/` mirrors the target
  root, so the file keeps the location already decided. Being managed is what makes a re-run
  propagate convention updates. Alternative considered: relocating to `docs/work-items.md` to
  reuse the existing managed-docs list unchanged; rejected because the chosen layout keeps the
  convention beside the records it governs, and generalizing the managed list is a small change.
- **Managed list becomes root-relative paths.** The managed concept already exists; only its
  `docs/`-only assumption is removed. Seed semantics are untouched.
- **Delivery reach differs per tool, and the activation entry is not uniformly reachable.**
  `.claude/rules/work-items.md` reaches Claude Code and its `.agents/rules/` mirror reaches
  Antigravity; neither is read by a tool that consumes only `AGENTS.md`. For such a tool, project
  instructions are discovered from the project root down to the launch directory, at most one file
  per directory, stopping at that directory — so a nested `work-items/AGENTS.md` is **not**
  auto-loaded, and the managed protocol is reached only when the loaded root instruction points to
  it. Because one directory may offer several candidates and an override file takes precedence over
  `AGENTS.md`, the first link is **the root instruction file the tool actually loads**, not
  necessarily `AGENTS.md`. The chain is therefore **loaded root instruction →
  `docs/agent-protocol.md` → `work-items/AGENTS.md`**, and all three links must exist. The template seed supplies the first
  link for new projects; a project with its own `AGENTS.md` that lacks a protocol pointer has a
  broken first link, which the installer reports rather than repairs.
- **Activation rides existing refresh channels, plus one reported precondition.**
  `.claude/rules/work-items.md` is copied and mirrored with no new installer logic, following the
  `tdd-enforcement.md` precedent of a short native entry pointing at the single source. One
  conditional line in the managed protocol §1 serves the `AGENTS.md` chain. The seed `AGENTS.md`
  keeps a stable three-line pointer so a brand-new project sees the convention exists.
- **`.gitignore` is merged on a versioned rule, and the effect is verified separately.** Targets
  own their ignore rules, so the installer skips the append only when the project's **versioned**
  `.gitignore` already carries an equivalent rule, and creates the file only when absent. Effect
  alone is not a sufficient basis: exclusion supplied by the repository-local exclude file or a
  personal global excludes file satisfies the two-way check while leaving the project with no rule,
  so a fresh clone would be unprotected — which the convention itself forbids. Because a literal rule can be defeated by a parent-level
  ignore or a later negation, the installer verifies the actual outcome with Git — records
  effectively ignored, convention file still trackable — and reports a conflict it cannot resolve
  without altering rules the project already has.
- **No `CLAUDE.md` delivery.** An eager `@work-items/AGENTS.md` import would load 17 KB into every
  session in every project, contradicting the read-on-demand design, and the personal
  communication preferences belong in the user-level configuration.
- **Write ownership is about files, not concurrency.** The convention assigns which file each
  participant may write inside a Work Item. It does not relax the existing one-active-writer-per-
  worktree rule in `docs/architecture.md` and `docs/workflow/concepts.md`, and grants no authority
  to modify product code, specifications, or Git state. Several participants collaborate either in
  sequence within one worktree, with the writer role handed over, or concurrently in separate
  worktrees, each holding its own local records.
- **Convention stays tool-neutral.** The session alias example is renamed so a distributed
  `AGENTS.md` does not name a secondary tool, consistent with the existing protocol invariant.

## Risks / Trade-offs

- **Records committed when protection is not actually in place.** `git-commit-writer-agent` stages
  with `git add -A`, which honours `.gitignore` only for untracked files whose effective rule
  resolves to ignored. Three failure modes were reproduced in isolated repositories: a parent-level
  `/work-items/` rule also ignores `work-items/AGENTS.md`, so the convention cannot be tracked; a
  later negation of the same path leaves the literal rule present while records are still staged;
  and an already-tracked record is staged regardless of any rule added afterwards. Mitigated by
  verifying effect in both directions, by reporting unresolvable conflicts, and by the convention's
  requirement to confirm the rule is effective before the first write.
- **Exclusion that is not versioned looks identical to a correct setup.** Reproduced in isolated
  repositories: with the rule only in the repository-local exclude file, or only in a personal
  global excludes file, the records resolve as ignored and the convention stays trackable, yet the
  project carries nothing; the same project files without those local settings leave records
  untracked and staged by `git add -A`. Mitigated by keying the append on the versioned rule while
  still verifying effect, and by never touching personal or repository-local configuration.
- **Already-tracked records cannot be protected by this change.** The installer and the agent
  report the condition and leave the Git index alone; the protection is explicitly not in force for
  those files. Note that `git check-ignore` reports nothing for a tracked path even when a matching
  rule exists, so the check must consult the index as well as the ignore rules.
- **Broken activation chain in an existing project.** A project whose own `AGENTS.md` does not point
  at the managed protocol receives the managed files but no reachable entry for an
  `AGENTS.md`-only tool. The installer reports the gap with the concrete pointer section to add and
  does not claim activation is complete; it never overwrites the project's `AGENTS.md`.
- **Silent loss on worktree removal.** `wt-done.sh` merges and removes without knowing about
  records. Verified behaviour: ignored records neither block `git worktree remove` nor require
  `--force`, and they are deleted with the worktree. This matches the intended lifecycle, and the
  decision not to add enforcement this round is deliberate; the mitigation is the handoff rule
  that necessary outcomes must already have a formal home.
- **`.gitignore` acceptance collides with an existing exact-equality assertion.**
  `tests/test_agents_dir.sh:109` asserts the installed `.gitignore` equals exactly `keep-me` after
  the installer removes a retired rule. Appending the Work Item rule breaks that assertion even when
  behaviour is correct, and the installer's own retired-rule removal means "preserve every line" can
  only bound the Work Item merge, not the installer as a whole. Reconciled by scoping the
  preservation rule to the merge and replacing the equality assertion with separate property checks.
- **Managed file edited downstream.** `doc-updater-agent` has no managed-file awareness, so a
  downstream edit to a managed file is silently reverted by the next install. Pre-existing for the
  four managed docs and widened by one file; recorded as a follow-up, not fixed here.

## Migration Plan

Re-run `scripts/skills/install.sh` in each consuming project to receive the managed convention
file, the rules entry, the refreshed protocol, and the ignore rule. Existing `AGENTS.md` and
`CLAUDE.md` files are left untouched by design.

No manual merge is required **only when the root instruction file the tool actually loads already
directs the agent to the managed protocol**, which is the case for any project whose `AGENTS.md`
came from the template seed and holds no overriding instruction file. A project can satisfy an
`AGENTS.md`-only inspection and still fail in practice: if a non-empty override file in the same
directory wins and carries no pointer, the chain is broken even though `AGENTS.md` looks correct.
When the chain is broken, or when the loaded file cannot be determined, the installer reports the
gap, names the file it examined, states the pointer section to add, and does not claim the
convention is active for that tool. Repairing it is the project's decision, because the
installer must not overwrite a project-owned file.

Delivery acceptance is therefore the whole chain, not the presence of installed files. The
`.claude/rules/` and `.agents/rules/` entries existing proves nothing about an `AGENTS.md`-only
tool. Acceptance for such a tool is a manual check in a newly started session at the repository
root, confirming it reaches the convention through root `AGENTS.md` and the managed protocol; if
that session is not run, the change records the entry as verified by document inspection only and
explicitly not runtime-tested.

This repository receives the same delivery, which doubles as the end-to-end check. Separately and
outside this change, the user moves the personal communication preferences into
`~/.claude/CLAUDE.md`.

## Validation

Test-first coverage in `tests/test_work_items.sh`:

- the managed convention file is refreshed on re-run and carries the managed banner;
- the rules entry reaches `.claude/rules/` and `.agents/rules/`;
- the ignore rule is appended once, stays single across runs, is not duplicated when the records
  are already effectively ignored, and is created only when the file is absent;
- **bidirectional effect:** after install, a record under `work-items/WI-*/` is reported as ignored
  and excluded by `git add -A`, **and** `work-items/AGENTS.md` is not ignored and can be tracked;
- **the three defeat cases:** a pre-existing parent-level `/work-items/` rule, a later negation of
  the records path, and an already-tracked record each produce a report instead of a false claim of
  protection, with the Git index left unmodified;
- an existing `AGENTS.md`, `CLAUDE.md`, and unrelated ignore lines survive unchanged;
- a target whose loaded root instruction lacks the protocol pointer produces the migration report,
  including the case where a non-empty override file wins over a correct `AGENTS.md`;
- **non-versioned exclusion fixtures:** rule only in the repository-local exclude file, rule only
  in an isolated personal global excludes file, and the same project files with neither — the first
  two still get the rule appended to the project `.gitignore` with no local configuration changed,
  and the third is protected by the versioned rule alone;
- `.gitignore` acceptance checks each property separately — unrelated rule preserved, retired rule
  removed, records effectively ignored, convention trackable, no duplicate on re-run — instead of
  asserting the whole file equals one fixed string.

The existing `tests/test_portable_agents_md.sh` and `tests/test_agents_dir.sh` must keep passing,
and the protocol's reference to the convention file must resolve in the installed context. The
`AGENTS.md`-chain acceptance is recorded as either a manual new-session result or an explicit
untested note.

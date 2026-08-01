## Context

See [proposal.md](proposal.md) for motivation. The workflow helpers are currently standalone
Bash executables copied to `~/.local/bin`; `wt-work` and `wt-resume` duplicate Provider
dispatch, assume `.worktrees/<name>`, and conflate "enter this checkout" with "resume a
session". `openspec-branch-creator` runs after `openspec new change`, so it cannot guarantee
that the first artifact was written on the feature branch.

Current local CLI contracts confirm native plan flags for Claude
(`--permission-mode plan`) and Antigravity (`--mode plan`). Codex exposes cwd and resume
commands but no launch-time plan flag; Copilot is retained through its existing adapter without
inventing a plan flag. These commands are Provider adapters, not workflow invariants.

## Goals / Non-Goals

**Goals:**

- Make branch-first planning an explicit replayable transition.
- Give `wt-work` one deterministic Project-managed default while allowing safe attachment to
  any registered Provider-native Worktree.
- Keep checkout resolution, Provider launch, session resume, and cleanup ownership separate.
- Preserve dirty same-machine work without hidden Git mutations.
- Cover behavior with an offline shell regression test using temporary repositories and fake
  Provider executables.

**Non-Goals:**

- Creating Provider-native Worktrees from `wt-work`.
- Moving conversation history between Providers.
- Detecting or killing an active Provider process automatically.
- Automatically installing dependencies, pushing branches, opening PRs, or deleting remote
  branches.
- Persisting a `change-id → path` registry outside Git.

## Decisions

### D1 — Add an explicit `opsx-branch` transition and retain the hook only as fallback

Add `scripts/workflow/opsx-branch.sh` and install it as `opsx-branch`. It validates a kebab-case
change ID, resolves the current repository, and creates or switches to
`feature/<change-id>` without invoking OpenSpec. If that branch is checked out in another
Worktree, it reports the registered path and stops.

The existing PostToolUse hook stays idempotent for compatibility, but documentation and tests
model this sequence:

```text
Scope Ready → opsx-branch <change-id> → openspec-ff-change <change-id>
```

This avoids shadowing or modifying OpenSpec-generated Provider skills. Reimplementing
`openspec-ff-change` inside a wrapper was rejected because it would duplicate a third-party
artifact workflow.

### D2 — Project-managed is the only Worktree creation path in `wt-work`

When no reusable Worktree exists, `wt-work` creates
`<primary-repo>/.worktrees/<change-id>` from the already planned
`feature/<change-id>` branch. It never asks a Provider to create a Worktree and never creates
an empty feature branch from the base branch.

This gives every Provider the same cwd, named branch, and `wt-done` cleanup path. Provider-native
creation remains available directly in each Provider; `wt-work` only attaches it.

### D3 — Resolve paths from Git registry with strict precedence

Implement the resolver once in a small installed runtime helper shared by `wt-work` and
`wt-resume`. Parse `git worktree list --porcelain`; do not scan arbitrary filesystem roots.

Resolution order:

1. If `--path` is present, canonicalize it and require an exact registered path from the same
   repository.
2. Otherwise prefer a registered `.worktrees/<change-id>` path.
3. Otherwise accept the single non-primary Worktree on `refs/heads/feature/<change-id>`.
4. Otherwise accept a single detached non-primary candidate only when it contains
   `openspec/changes/<change-id>` and `feature/<change-id>` is an ancestor of its HEAD.
5. More than one eligible candidate is an error that prints all exact paths and requires
   `--path`.
6. With no candidate, create the Project-managed Worktree only from a confirmed local or remote
   feature branch.

After selection, verify the active change exists and the resolved HEAD contains the planning
branch tip. An explicit path never transfers cleanup ownership.

The primary checkout is not an automatic attach candidate. If it holds the feature branch,
`wt-work` first requires it to be clean, switches it to the requested base branch, and then
creates the Project-managed Worktree.

### D4 — Separate launch from resume

`wt-work` is the apply launcher:

- without `--session`, start a new session for the selected Provider;
- with `--session`, explicitly resume that Provider session in the resolved Worktree;
- express the portable `openspec-apply-change` intent exactly once.

`wt-resume` is session-only:

- use the same path resolver;
- open the selected Provider's native picker／continue behavior when no session is supplied;
- forward an explicit session or conversation identifier when supplied;
- do not inject a new apply action.

Initial adapter mapping follows the installed CLI contracts:

| Provider value | Executable | New / plan behavior | Resume behavior |
|---|---|---|---|
| `claude` | `claude` | named session; native plan flag in `pm-start` | `--resume` |
| `codex` | `codex` | launch in resolved cwd; `pm-start` reports that plan mode is selected in-session | `codex resume` |
| `antigravity` (`agy` alias) | `agy` | interactive prompt; `--mode plan` in `pm-start` | `--continue` / `--conversation` |
| `copilot` | `copilot` | preserve existing apply launch | preserve existing `--resume` behavior |

Provider absence produces a direct executable-not-found error. Gemini code paths and completion
values are deleted rather than aliased.

Provider input normalization happens once in the shared runtime: `agy` becomes the canonical
`antigravity` value before validation and dispatch. `wt-done` has no Provider adapter or
`--agent` option, so the alias does not apply to cleanup.

### D5 — Dirty same-machine attach is non-mutating

Before launching, print the resolved path, branch or detached state, HEAD, and a concise
`git status --short`. A dirty state is informational, not a gate. The resolver never performs
stash, reset, checkout, add, or commit inside an attached Worktree.

The user remains responsible for stopping the previous active writer. Cross-machine flow still
requires a commit／push or explicit patch because dirty filesystem state is not portable.

### D6 — Copy only selected Provider local settings

For newly created Project-managed Worktrees:

1. Copy `.env` when it exists and the target does not already contain it.
2. Consult the selected Provider's repository-local allowlist and copy only existing,
   target-absent files:
   - Claude: `.claude/settings.local.json`
   - Codex: `.codex/config.toml`
   - Antigravity: no repository-local file in this version; its
     `~/.gemini/antigravity-cli/settings.json` is user-level and remains outside the Worktree
   - Copilot: no additional local-only path in this version; tracked `.github/` content arrives
     through Git.
3. Never copy user-level configuration, auth files, or another Provider's settings.
4. Never overwrite a tracked target file or install dependencies.

Legacy `.gemini/settings.json` is not treated as Antigravity configuration. Codex
`.worktreeinclude` remains a Codex-managed Worktree mechanism and is neither generated nor
interpreted by the project resolver.

### D7 — Cleanup owner is derived, not transferred

`wt-done` continues to merge `feature/<change-id>` and remove only the registered
`.worktrees/<change-id>` path. It does not accept arbitrary cleanup paths. Provider-native paths
remain after merge until their creating Provider or the user removes them.

This deliberately avoids cleanup metadata and two owners racing to delete the same Worktree.

### D8 — One offline workflow test owns the behavior contract

Add `tests/test_workflow.sh`. The test creates temporary Git repositories and a bare `origin`,
prepends fake `claude`, `codex`, `agy`, and `copilot` executables to `PATH`, and records argv／cwd
without starting real sessions.

Focused cases cover:

- `opsx-branch` before any OpenSpec artifact;
- local, remote-only, explicit-path, unique detached, ambiguous, and remote-error resolution;
- new-session versus explicit resume dispatch for each primary Provider;
- dirty attach preservation;
- selected-Provider local setting copy and no dependency execution;
- Project-managed-only cleanup;
- installer and zsh completion provider lists.

Each implementation task begins with the smallest failing case and records valid Red evidence per
the repository TDD protocol.

## Risks / Trade-offs

- [Detached candidates can resemble each other] → accept only a unique verified candidate;
  otherwise require `--path`.
- [A user can leave two Providers writing the same path] → print the active-writer warning and
  require manual stop; process discovery／locking is out of scope.
- [Provider CLI flags can drift] → keep commands isolated in adapters and test argv with fakes;
  re-check installed `--help` during implementation.
- [Local setting files may contain secrets] → copy only a narrow repository-local allowlist,
  never log content, never copy global auth, and never overwrite existing targets.
- [Primary checkout may contain unrelated dirty work] → require it to be clean before switching
  away to create a Project-managed Worktree.
- [Legacy PostToolUse hook still runs after artifact creation] → make it an idempotent fallback;
  the explicit transition remains the documented correctness path.

## Migration Plan

1. Land regression tests and the explicit branch helper.
2. Add the shared runtime resolver and Provider dispatch, then migrate `wt-work`, `wt-resume`,
   and `pm-start` onto it.
3. Update installer and completion; re-running `scripts/workflow/install.sh` replaces installed
   binaries and removes Gemini from offered values.
4. Keep the existing compatibility hook registration so older entrypoints fail soft while users
   move to `opsx-branch`.
5. Validate all delta specs strictly and run the full shell test suite before archive.

Rollback restores the previous installed scripts by checking out the prior revision and rerunning
the installer. Existing `.worktrees/` remain standard Git Worktrees and require no data migration.

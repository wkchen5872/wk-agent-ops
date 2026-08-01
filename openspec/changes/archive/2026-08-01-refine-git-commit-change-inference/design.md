# Design: refine-git-commit-change-inference

## Context

The current standalone fallback resolves OpenSpec context before staging and uses candidate count as association evidence. Commit `374d835` demonstrates the failure: a sole active change supplied scope and proposal context to a cached diff that only contained unrelated hook documentation. Explicit context from `openspec-commit` already has a safe contract and must remain unchanged.

## Goals / Non-Goals

**Goals:**

- Require deterministic association evidence before standalone scope inference.
- Make the staged diff authoritative before any standalone proposal is read.
- Keep the portable skill and Claude agent behavior equivalent.
- Preserve explicit archive handoff and all existing commit/retry behavior.

**Non-Goals:**

- Do not infer associations from proposal prose, `Impact` path guesses, semantic similarity, timestamps, or the newest change.
- Do not add a runtime resolver script, registry, or new dependency.
- Do not repair historical commit messages or change `openspec-commit` orchestration.
- Do not require all commits to have an OpenSpec scope.

## Decisions

### D1: Validate explicit input first, but resolve standalone context after staging

The flow becomes:

1. Validate that explicit `archive_path` and `change_id` are either both absent or both valid; invalid explicit input still stops before staging.
2. Run `git add -A`, stop on an empty cached diff, and collect `git diff --cached --name-only`, stat, and content.
3. Use valid explicit context immediately; otherwise resolve standalone candidates from the current branch and cached paths.
4. Infer the message and commit exactly as before.

This order lets standalone inference evaluate the same files that will be committed. Reading unstaged status before `git add -A` was rejected because hooks, deletions, and new files can make it differ from the final cached diff.

### D2: Use only exact branch and staged-path associations

An active change is associated when either condition is true:

- the current branch is exactly `feature/<change-id>`; or
- a cached path is beneath the exact `openspec/changes/<change-id>/` directory.

An archived change is associated only when a cached path is beneath its exact `openspec/changes/archive/<archive-directory>/` directory. Directory comparisons use path components, not substring matching.

These signals cover normal branch-only implementation, planning commits, and archive commits. Proposal path lists and semantic diff matching were rejected because they are optional, ambiguous, and would reintroduce model guesswork.

### D3: Candidate count resolves ambiguity, not association

After filtering by D2:

- zero candidates → use an unscoped message from the staged diff;
- one candidate → use its change context;
- multiple candidates → ask when interaction exists, otherwise stop and list them.

The raw number of active changes is never used to create an association. This directly removes the observed “sole active change” failure while retaining the existing no-first-candidate guard.

### D4: Keep skill and agent as the only behavior sources

The portable SKILL.md contains the full interactive behavior. The Claude subagent mirrors the same rules but stops on ambiguity because it lacks an interactive question tool. Existing installer propagation updates `.claude/` and `.agents/`; no resolver helper is added because the behavior is a short decision table and the current issue is an instruction contract defect, not shell parsing reuse.

## TDD Strategy and Test Boundary

Extend the `commit-writer` section of `tests/test_openspec_commit.sh` first. The Red assertions require both source entrypoints to:

- stage before standalone candidate resolution;
- name exact feature-branch and cached-path evidence;
- state that a sole unassociated active change is ignored;
- preserve explicit context, empty-diff, restage, and ambiguity guards.

This project tests AI-interpreted skills as static contracts; no executable resolver exists to unit test. After Green, run the focused section, the full workflow test, installer mirror comparisons, and strict OpenSpec validation. A documented replay of the `374d835` input shape provides acceptance evidence: on `main`, an unrelated docs-only staged diff plus one active change must produce `docs: ...`, not `docs(add-mutation-check): ...`.

## Risks / Trade-offs

- [A user commits unrelated work while still on a feature branch] → The exact branch remains intentional workflow evidence; staged-path semantics are not guessed. Users should move unrelated work to the correct branch.
- [A nonstandard branch contains implementation files but no staged OpenSpec artifact] → The safe fallback is an unscoped commit; callers needing a scope can use `openspec-commit` explicit context.
- [Multiple archived change directories are staged together] → Interactive hosts ask; non-interactive agents stop instead of selecting arbitrarily.
- [Static contract and Agent interpretation diverge] → Keep both source entrypoints under the same focused assertions and installation mirror checks.

## Migration Plan

1. Add failing contract assertions.
2. Update the source skill and Claude agent, then run the installer for generated mirrors.
3. Sync the canonical spec and user documentation.
4. Replay the unrelated-diff scenario and run focused/full validation.
5. Roll back by reverting the source templates, mirrors, spec, docs, and tests together; no data migration is required.

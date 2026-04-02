## Context

When PM agent executes `/opsx:ff` or `/opsx:new`, it calls `openspec new change "<name>"` via the Bash tool. The change directory is created, and spec artifacts are written to `openspec/changes/<name>/` and committed — but all of this happens on `main` branch. The `feature/<name>` branch is only created later when RD runs `wt-work <name>`.

This means spec artifacts (proposal, design, tasks) permanently reside on `main` rather than on the feature branch where they conceptually belong. It also breaks the cross-machine workflow: if PM is on machine A and pushes the feature branch, RD on machine B has no way to start from the PM-created branch.

OpenSpec is a third-party skill (`@Fission-AI/OpenSpec`) — its skill files must not be modified to avoid maintenance burden on upgrades.

## Goals / Non-Goals

**Goals:**
- Automatically create `feature/<name>` branch the moment PM agent runs `openspec new change "<name>"`
- Support cross-machine workflow: RD on a different machine can pick up an existing remote feature branch
- Keep implementation entirely within wk-agent-ops (no changes to OpenSpec)
- Integrate seamlessly into existing `scripts/workflow/install.sh` one-step setup

**Non-Goals:**
- Gemini CLI / Copilot CLI / Codex hook support (Claude Code PostToolUse only; others may be added later)
- Team collaboration workflows (PRs, remote branch protection, code review gates) — `wt-done` remains local-only for now
- Modifying OpenSpec skill files

## Decisions

### D1: PostToolUse Hook over Rule or Wrapper Skill

**Decision**: Implement as a Claude Code `PostToolUse` hook registered in `~/.claude/settings.json`.

**Alternatives considered**:
- *Rule in `.claude/rules/`*: Agent reads the rule and creates the branch in-conversation. Unreliable — depends on agent following the rule consistently.
- *Wrapper skill `/pm-new-change`*: Thin skill that creates branch then delegates to `/opsx:ff`. Requires PM agent to change habits; easy to forget. Breaks when OpenSpec command names change.
- *Modify `opsx:ff.md`*: Direct but requires maintaining a forked copy of the skill on every OpenSpec upgrade.

**Rationale**: Hook runs automatically after every Bash tool call — the PM agent needs zero awareness of it. No OpenSpec files are touched. The hook is idempotent and exits 0 regardless of outcome.

### D2: Hook deployment to `~/.config/wk-workflow/hooks/`

**Decision**: Deploy hook script to `~/.config/wk-workflow/hooks/openspec-branch-creator.sh` (a neutral, non-project path), matching the existing pattern of `~/.config/ai-notify/hooks/` used by the telegram-notify hook.

**Rationale**: The hook path in `settings.json` must be stable across project directories. A `~/.config/` path is project-independent and survives repo moves/renames.

### D3: wt-work.sh branch resolution order

**Decision**: Check local branch first, then remote, then create new.

```
local exists?  → worktree add (no -b)
remote exists? → git fetch origin <branch> + worktree add -b <branch> origin/<branch>
neither        → git checkout BASE_BRANCH + worktree add -b <branch>
```

**Rationale**: Local check is cheap (no network). Remote check handles the cross-machine case. Falling back to create-new preserves existing behavior for users not using the PM branch-creation flow.

### D4: TDD Strategy

For shell scripts, tests are written as `bats` (Bash Automated Testing System) test files. Each test:
1. RED: write test asserting expected behavior (branch creation, idempotency, exit-0)
2. GREEN: implement minimal script logic to pass
3. REFACTOR: clean up, extract helpers
4. Subagent code review before marking task done

Minimum coverage: all scenarios in specs must have corresponding bats tests.

## Risks / Trade-offs

- **Hook fires on every Bash call** → Script must be fast. The `openspec new change` pattern match uses regex and exits immediately on non-match. Latency impact: <5ms.
- **`CLAUDE_PROJECT_DIR` may be empty** → Fallback chain: env var → stdin JSON `project_dir` → `PWD`. If all fail, hook exits 0 silently (never blocks).
- **PM creates multiple changes in one session** → Each `openspec new change` triggers the hook. PM session ends on whichever branch was created last. This is acceptable for single-change sessions; multi-change PM sessions are an edge case.
- **git checkout fails (dirty tree, merge conflict)** → Hook always exits 0. The branch won't be created automatically; PM agent will still be on `main`. User can manually create the branch. A warning could be logged to stderr (visible in Claude's tool output).
- **wt-done is local-only** → Documented as a known limitation. Team workflows (push, PR, remote cleanup) are deferred.

## Migration Plan

1. Run `bash scripts/workflow/install.sh` — integrates hook deployment automatically
2. Verify `~/.claude/settings.json` contains the `PostToolUse` entry
3. Existing workflows unchanged: if hook is not installed, `wt-work` falls through to the "create new" path as before
4. Rollback: run `bash scripts/workflow/openspec-branch-creator/uninstall.sh`

## Open Questions

- Should the hook also push the new branch to remote immediately? (Would make cross-machine pickup seamless without a manual `git push`, but adds network latency to every `openspec new change` call.)
- Should `wt-done` gain a `--push` flag for teams who want remote cleanup? (Out of scope for this change.)

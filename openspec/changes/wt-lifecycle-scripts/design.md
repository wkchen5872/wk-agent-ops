## Context

The worktree helper scripts (`wt-new.sh`, `wt-done.sh`) were designed for a simple new→done flow. In practice users often interrupt sessions and need to re-enter them, and the scripts lacked safety rails. The upgrade aims to make the common "come back to a session" case require zero extra knowledge: the user just runs the same `wt-new` command again.

Current state:
- `wt-new.sh`: creates worktree or silently re-enters if it exists (no explicit resume path)
- `wt-done.sh`: no `set -euo pipefail`, hardcoded `main` target, no badge reset
- No `wt-resume.sh`, no `pm-start.sh`, no tab completion

## Goals / Non-Goals

**Goals:**
- `wt-new <name>` is the only command a user needs to remember for starting any session
- Dedicated `wt-resume <name>` for after `wt-done` has removed the worktree
- `wt-done` is safe-by-default with clear guidance on failure
- PM Master Session has a dedicated launcher
- Tab completion reduces typos for feature names

**Non-Goals:**
- Support for agents other than claude in new scripts (copilot/codex remain supported only in wt-new.sh)
- Automatic conflict resolution
- Remote/cross-machine worktree management

## Decisions

### D1: `wt-new` auto-detect via worktree directory existence

**Decision:** Check `[[ -d "$WORKTREE_DIR" ]]` to decide new vs. resume.

**Rationale:** The worktree directory is the canonical source of truth. If it exists, the branch and agent session exist. Branch check alone is insufficient because the user may have manually removed the worktree directory.

**Alternative considered:** Check git branch existence (`git show-ref`). Rejected because a branch can exist without a worktree (e.g., after `wt-done` only cleaned the worktree but not the branch).

---

### D2: `wt-resume` tries worktree-first, then falls back to session name

**Decision:** If `WORKTREE_DIR` exists, `cd` into it then `claude --resume "RD: $NAME"`. If not, run `claude --resume "RD: $NAME"` from current directory.

**Rationale:** Claude's `--resume` uses session name, not directory. The `cd` is a UX convenience so the agent starts in the right context if the worktree is present.

---

### D3: `--base` flag stored as `BASE_BRANCH` variable, defaults to `main`

**Decision:** Accept `--base <branch>` with `getopt`-style parsing (manual loop). The variable drives `git checkout $BASE_BRANCH` and `git merge $BRANCH`.

**Rationale:** Consistent with existing `--agent` flag pattern in `wt-new.sh`. No external deps needed.

---

### D4: Zsh completion via `_wt` compdef function

**Decision:** Single `_wt` completion file covers all three commands by checking `$words[1]`. Feature names come from `ls $REPO/.worktrees/` with null-safety.

**Alternative considered:** Per-command completion files. Rejected — more files, same functionality.

---

### D5: `pm-start.sh` uses `--name` flag

**Decision:** `claude --name "PM: $(basename $REPO)" "/opsx:new"` — the session name is deterministic and human-readable. Users can re-enter via `claude --resume "PM: <repo>"`.

**Rationale:** Consistent with `wt-new.sh`'s `"RD: $NAME"` naming convention.

## Risks / Trade-offs

- **[Risk] `wt-new` auto-resume silently if branch diverged** → Mitigation: print a clear "RESUMING" banner so user always knows which mode they're in.
- **[Risk] `set -euo pipefail` may break edge cases in `wt-done.sh`** → Mitigation: test against both main and develop targets before release.
- **[Risk] Zsh completion only; bash users get nothing** → Mitigation: document this limitation; bash completion is TASK-05's P2 scope.
- **[Risk] `pm-start.sh` always passes `/opsx:new` on resume** → Mitigation: Claude's `--name` with an existing session resumes rather than creates new, so the command is idempotent.

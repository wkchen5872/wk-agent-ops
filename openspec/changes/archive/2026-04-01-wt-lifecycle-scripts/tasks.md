## 1. wt-new.sh — Auto-Detect New / Resume

- [x] 1.1 Add `--base <branch>` flag parsing (default: `main`); store as `BASE_BRANCH`
- [x] 1.2 Replace hardcoded "already exists" check with explicit `[[ -d "$WORKTREE_DIR" ]]` branch
- [x] 1.3 In resume path: print "RESUMING" banner (show Mode: resume) and set iTerm2 badge
- [x] 1.4 In resume path: `cd "$WORKTREE_DIR"` then launch agent with `--resume "RD: $NAME"`
- [x] 1.5 In new path: print "NEW SESSION" banner (show Mode: new)
- [x] 1.6 In new path: copy `.env` from repo root to worktree (alongside `settings.local.json`)
- [x] 1.7 Use `$BASE_BRANCH` variable in `git checkout` and `git worktree add` commands
- [x] 1.8 Verify: `wt-new feature123` creates worktree; second call resumes without error

## 2. wt-done.sh — Hardening & Parameterization

- [x] 2.1 Add `set -euo pipefail` at the top
- [x] 2.2 Add `--base <branch>` flag parsing (default: `main`); store as `BASE_BRANCH`
- [x] 2.3 Replace hardcoded `main` with `$BASE_BRANCH` in `git checkout` and `git merge`
- [x] 2.4 On merge failure: print message recommending `wt-resume <name>` for agent-assisted conflict resolution
- [x] 2.5 On success: run `git worktree prune` after `git worktree remove`
- [x] 2.6 On success: reset iTerm2 badge (send empty escape sequence)
- [x] 2.7 Verify: `wt-done feature123` merges to main; `wt-done feature123 --base develop` merges to develop

## 3. wt-resume.sh — New Script

- [x] 3.1 Create `scripts/worktree/wt-resume.sh` with `set -euo pipefail`
- [x] 3.2 Validate `$1` argument (feature name); exit 1 with usage if missing
- [x] 3.3 Resolve `$REPO` via `git rev-parse --show-toplevel`
- [x] 3.4 If `$REPO/.worktrees/$NAME` exists: print message, `cd` into worktree, run `claude --resume "RD: $NAME"`
- [x] 3.5 If worktree directory missing: print fallback message, run `claude --resume "RD: $NAME"` from current dir
- [x] 3.6 Verify: `wt-resume feature123` works both with and without an existing worktree directory

## 4. pm-start.sh — New Script

- [x] 4.1 Create `scripts/worktree/pm-start.sh` with `set -euo pipefail`
- [x] 4.2 Resolve `$REPO` via `git rev-parse --show-toplevel`; exit 1 if not in a git repo
- [x] 4.3 Derive `PM_NAME="PM: $(basename "$REPO")"`
- [x] 4.4 `cd "$REPO"` and execute `claude --name "$PM_NAME" "/opsx:new"`
- [x] 4.5 Verify: `pm-start` launches a named Claude session; second call resumes it

## 5. _wt Zsh Completion

- [x] 5.1 Create `scripts/worktree/_wt` completion script using `compdef`
- [x] 5.2 Completion function reads feature names from `$(git rev-parse --show-toplevel 2>/dev/null)/.worktrees/` with null-safety
- [x] 5.3 Register completion for `wt-new`, `wt-done`, `wt-resume` via `compdef _wt wt-new wt-done wt-resume`
- [x] 5.4 Verify: typing `wt-new <TAB>` lists existing worktree directory names

## 6. install.sh & README Updates

- [x] 6.1 Add `wt-resume.sh`, `pm-start.sh`, `_wt` to the list of files copied in `install.sh`
- [x] 6.2 Copy `_wt` to `~/.local/share/zsh/site-functions/` and ensure it's on `$fpath`
- [x] 6.3 Add `hash -r` call at the end of `install.sh`
- [x] 6.4 Update success message in `install.sh` to list all installed commands including new ones
- [x] 6.5 Update `README.md`: add wt-resume usage example, document `--base` flag for wt-new and wt-done
- [x] 6.6 Update `README.md`: add "中途外出後只需 `wt-new <name>` 即可繼續" note in the workflow section

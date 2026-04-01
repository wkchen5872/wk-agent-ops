## Why

The current `wt-new.sh` / `wt-done.sh` pair requires users to know which script to call in each situation (new vs. resume), lacks safety guards (`set -euo pipefail`), and has no `--base` parameter for non-main-branch workflows. After `wt-done` deletes the worktree, there's no quick way to re-enter the session for code review. These gaps create friction and occasional mistakes in the multi-agent development workflow.

## What Changes

- `wt-new.sh` upgraded to auto-detect: if worktree already exists → resume; otherwise → create new. Adds `--base` parameter and copies `.env` alongside `settings.local.json`.
- `wt-done.sh` hardened with `set -euo pipefail`, parameterized base branch (`--base main|develop`), clearer merge-failure guidance, and auto-cleanup with `git worktree prune` + iTerm badge reset.
- New `wt-resume.sh`: resumes an agent session by name regardless of whether the worktree directory still exists.
- New `pm-start.sh`: launches a persistent PM Master Session in the repo root with a named Claude session.
- New `_wt` zsh completion script: `<TAB>` on `wt-new`, `wt-done`, `wt-resume` lists existing feature names.
- `install.sh` updated: installs new scripts, sources the completion file, runs `hash -r`, and prints clearer post-install guidance.
- `README.md` updated with new usage examples, `--base` parameter docs, and the auto-detect/resume flow.

## Capabilities

### New Capabilities
- `wt-resume`: Resume an agent worktree session by feature name; works even after `wt-done` has removed the worktree directory.
- `pm-start`: Launch (or resume) a long-running PM Master Claude session from the repo root.
- `wt-zsh-completion`: Tab-completion for `wt-new`, `wt-done`, `wt-resume` that lists existing feature names from `.worktrees/`.

### Modified Capabilities

## Impact

- `scripts/worktree/wt-new.sh` — behavior change (auto-detect new/resume, `--base`, copy `.env`)
- `scripts/worktree/wt-done.sh` — hardening + `--base` param
- `scripts/worktree/install.sh` — installs new scripts + completion
- `scripts/worktree/README.md` — documentation update
- New files: `scripts/worktree/wt-resume.sh`, `scripts/worktree/pm-start.sh`, `scripts/worktree/_wt`

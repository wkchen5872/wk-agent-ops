## Why

When the PM agent uses `/opsx:ff` or `/opsx:new` to create an OpenSpec change, a `feature/<name>` git branch should automatically be created at that moment. Currently, the branch is only created later when RD runs `wt-work <name>`, causing spec artifacts to land on `main` instead of the feature branch they belong to.

## What Changes

- Add a `PostToolUse` hook script that detects `openspec new change "<name>"` Bash calls and automatically runs `git checkout -b feature/<name>` in the project directory
- Add install/uninstall scripts to register the hook in `~/.claude/settings.json`
- Integrate hook installation into `scripts/workflow/install.sh`
- Update `wt-work.sh` to support three branch scenarios: local exists, remote-only exists (cross-machine), or neither
- Add a flow diagram doc for `wt-work` to explain the new branch resolution logic
- Add a note in workflow docs that `wt-done` is local-only and does not handle team remote/PR workflows

## Capabilities

### New Capabilities

- `openspec-branch-creator-hook`: PostToolUse hook that auto-creates `feature/<name>` branch when `openspec new change` is executed. Includes install and uninstall scripts. Deployed to `~/.config/wk-workflow/hooks/`.
- `wt-work-cross-machine`: Enhanced branch resolution in `wt-work.sh` — checks local branch, then remote branch (`git fetch`), then falls back to creating new. Supports cross-machine workflows where PM and RD are on different computers.

### Modified Capabilities

- `workflow-scripts`: `wt-work.sh` branch creation logic updated to handle pre-existing branches. `scripts/workflow/install.sh` extended to include hook deployment.

## Impact

- `scripts/workflow/openspec-branch-creator/hook.sh` — new file
- `scripts/workflow/openspec-branch-creator/install.sh` — new file
- `scripts/workflow/openspec-branch-creator/uninstall.sh` — new file
- `scripts/workflow/wt-work.sh` — modified branch creation block
- `scripts/workflow/install.sh` — extended with hook installation step
- `docs/workflow/wt-work-flow.md` — new flow diagram and cross-machine doc
- `docs/workflow/guide.md` or README — add wt-done local-only note
- `~/.claude/settings.json` — `PostToolUse` hook entry added at install time

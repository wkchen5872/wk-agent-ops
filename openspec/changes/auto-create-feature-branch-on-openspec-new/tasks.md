## 1. Hook Script

- [ ] 1.1 Create `scripts/workflow/openspec-branch-creator/hook.sh` — reads stdin JSON, detects `openspec new change "<name>"`, resolves project dir via `CLAUDE_PROJECT_DIR` → JSON `project_dir` → `PWD`
- [ ] 1.2 Implement branch creation logic: `git checkout -b feature/<name>` if new, `git checkout feature/<name>` if exists, always exit 0
- [ ] 1.3 Add jq-based JSON parsing with grep fallback for environments without jq
- [ ] 1.4 Deploy hook to `~/.config/wk-workflow/hooks/openspec-branch-creator.sh`

## 2. Hook Install / Uninstall

- [ ] 2.1 Create `scripts/workflow/openspec-branch-creator/install.sh` — deploys hook and registers `PostToolUse` entry in `~/.claude/settings.json` (idempotent, uses `_jq_write` pattern from `scripts/notify/lib/registry.sh`)
- [ ] 2.2 Create `scripts/workflow/openspec-branch-creator/uninstall.sh` — removes hook entry from settings.json and deletes deployed script
- [ ] 2.3 Extend `scripts/workflow/install.sh` to call `openspec-branch-creator/install.sh` as final step

## 3. wt-work.sh Branch Resolution

- [ ] 3.1 Replace error-exit block (line 159-163) with three-path logic: local exists → `worktree add` without `-b`; remote-only → `fetch` then `worktree add -b` with tracking; neither → existing new-branch flow
- [ ] 3.2 Handle `git ls-remote` failure gracefully (no remote configured → fall through to new-branch path)
- [ ] 3.3 Update `scripts/workflow/install.sh` to copy updated `wt-work.sh` to `~/.local/bin/wt-work`

## 4. Documentation

- [ ] 4.1 Create `docs/workflow/wt-work-flow.md` with Mermaid flowchart of branch resolution paths and cross-machine scenario explanation
- [ ] 4.2 Add wt-done local-only note to `docs/workflow/guide.md` (⚠️ TODO: team/remote/PR support is not yet implemented)

## 5. Verification

- [ ] 5.1 Run `bash scripts/workflow/install.sh` end-to-end and verify hook is registered in `~/.claude/settings.json`
- [ ] 5.2 Manually simulate `openspec new change "test-auto-branch"` Bash call and verify `feature/test-auto-branch` branch is created
- [ ] 5.3 Run `wt-work test-auto-branch` and verify worktree creation succeeds (no error about pre-existing branch)
- [ ] 5.4 Run `bash scripts/workflow/openspec-branch-creator/uninstall.sh` and verify hook entry is removed

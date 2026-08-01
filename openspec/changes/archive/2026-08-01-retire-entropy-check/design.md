## Context

The retired feature spans a template skill, generated provider mirrors, a workflow hook, installer wiring, ignored runtime state, documentation, and OpenSpec history. Existing installers already contain targeted cleanup for retired managed files; workflow hook helpers already know how to remove provider registrations.

## Goals / Non-Goals

**Goals:**

- Leave new and upgraded installations free of entropy skill, counter, state, ignore, and hook artifacts.
- Remove entropy-only architectural records while preserving unrelated history.
- Verify the upgrade cleanup before deleting the standalone counter uninstaller.

**Non-Goals:**

- Design or install a replacement health audit.
- Add a generic migration framework.

## Decisions

1. **Delete the feature instead of deprecating it.** Keeping dormant entrypoints would preserve the same architectural ambiguity. Git history is sufficient recovery.
2. **Put one-shot legacy cleanup in existing installers.** `scripts/skills/install.sh` removes stale skill mirrors, state, and the exact ignore entry; `scripts/workflow/install.sh` removes legacy workflow registrations and deployed files before continuing. This reuses existing install entrypoints rather than retaining a retired uninstaller.
3. **Execute then delete the current uninstaller.** The repository copy is used once to clean the maintainer's current environment, its result is verified, and the entire entropy-counter directory is removed.
4. **Use focused installer tests.** Tests seed legacy artifacts and assert cleanup while preserving unrelated files. No new test framework is introduced.

## Risks / Trade-offs

- [Existing users do not rerun an installer] → Their local legacy files remain until the next upgrade; document the upgrade behavior in this retirement change.
- [Broad cleanup removes unrelated content] → Delete only named managed paths, exact ignore lines, and known hook commands; tests preserve sentinels.
- [Historical context is reduced] → Keep this retirement change as the intentional tombstone; tracked deletions remain recoverable from Git history.

## Migration Plan

1. Add failing upgrade-cleanup assertions.
2. Run the existing entropy-counter uninstaller and verify current-user registrations/files are absent.
3. Add installer cleanup, remove sources/specs/docs/history, and delete the uninstaller with its directory.
4. Re-run skill and workflow installers plus the complete repository checks.

Rollback is a Git revert followed by reinstalling the restored skill and workflow hook.

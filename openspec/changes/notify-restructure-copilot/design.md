## Context

Current layout has `scripts/telegram-notify/`, `scripts/notify/`, `scripts/line-notify/` as siblings under `scripts/`. The intent was to grow notify providers under a single umbrella but only `scripts/notify/lib/` was centralised. The Copilot CLI hook system uses a different config file (`.github/hooks/hooks.json`) and different event names from Claude/Gemini, requiring new registration logic.

## Goals / Non-Goals

**Goals:**
- One `scripts/notify/` umbrella: `telegram/`, `line/`, `lib/`
- `registry.sh` registers Copilot hooks without breaking existing Claude/Gemini registration
- `hook.sh` correctly identifies Copilot CLI sessions and maps events to existing message format
- `install.sh` is idempotent for all three CLI targets
- No user-visible behavior change for existing Claude/Gemini users

**Non-Goals:**
- Copilot CLI `preToolUse` / `postToolUse` hooks (not relevant to notify)
- Windows PowerShell hook scripts
- Removing old `scripts/telegram-notify/` path from git history (just move files)

## Decisions

### D1: New directory layout

```
scripts/notify/
  lib/
    config.sh
    registry.sh
  telegram/
    hook.sh
    install.sh
    update.sh
    uninstall.sh
  line/
    .placeholder
```

**Rationale:** `lib/` is already there; placing provider dirs alongside it is natural. Old top-level dirs (`scripts/telegram-notify/`, `scripts/line-notify/`) are removed.

---

### D2: Copilot hook registration writes `.github/hooks/hooks.json`

**Decision:** `register_hook_copilot <hook_path>` uses `jq` to write/merge into `.github/hooks/hooks.json` at `$REPO_ROOT`. If the file doesn't exist, create it with `{"version":1,"hooks":{}}`.

**Rationale:** Copilot CLI loads hooks from `hooks.json` in the current working directory's `.github/hooks/`. Since this is a per-repo config, the file belongs in the repo (unlike `~/.claude/settings.json` which is global).

**Alternative considered:** A global `~/.config/copilot/hooks.json`. Rejected — Copilot CLI doesn't support a global hooks file; each repo needs its own.

---

### D3: Register `sessionEnd` + `userPromptSubmitted` for Copilot

**Decision:** `sessionEnd` → task complete (maps to Stop). `userPromptSubmitted` → action required (maps to Notification).

**Rationale:** `sessionEnd` is the closest semantic match to Claude's `Stop`. `userPromptSubmitted` fires when the user re-engages, which is the closest proxy for "agent is waiting for input".

**Alternative considered:** `errorOccurred` for action-required. Rejected — errors aren't always user-actionable; `userPromptSubmitted` is more reliable.

---

### D4: Copilot detection in hook.sh via environment variable

**Decision:** Detect Copilot by checking `GITHUB_COPILOT_SESSION_ID` (set by Copilot CLI). Fallback chain: `GEMINI_PROJECT_DIR` → Gemini CLI; `CLAUDE_PROJECT_DIR` → Claude Code; `GITHUB_COPILOT_SESSION_ID` → Copilot CLI; else → "AI CLI".

**Note:** The `GITHUB_COPILOT_SESSION_ID` env var name is derived from the Copilot CLI docs and needs verification during implementation. If the var name differs, it should be updated after testing.

---

### D5: `install.sh` Copilot step is opt-in

**Decision:** After Claude/Gemini registration, ask "Register Copilot CLI hooks? [y/N]". Default No.

**Rationale:** Copilot hooks go into `.github/hooks/hooks.json` which is repo-specific and may be committed. Users should consciously choose to modify a potentially-committed file.

---

### D6: `.github/hooks/hooks.json` committed to repo is acceptable

**Decision:** The file is added to the repo. The `bash` path points to a script that's deployed at install time (`~/.config/ai-notify/hooks/telegram-notify.sh`), so it works on any machine that ran install.

**Risk:** If `.github/hooks/` is gitignored or there's a policy against committing it, the user may need to add to `.gitignore` instead. Mitigation: install.sh prints a note about this.

## Risks / Trade-offs

- **[Risk] `GITHUB_COPILOT_SESSION_ID` env var unverified** → Implementation task must test and adjust var name before finalizing hook.sh
- **[Risk] `.github/hooks/hooks.json` committed to repo may surprise users** → Mitigation: install.sh prints an explicit note; uninstall.sh removes the file or comments it out
- **[Risk] Renaming scripts/telegram-notify/ breaks any symlinks or docs pointing to old path** → Mitigation: grep repo for old path references during implementation
- **[Risk] Copilot `userPromptSubmitted` may fire too frequently (every prompt, not just "waiting")** → Trade-off accepted at P1; can be gated with `NOTIFY_LEVEL` logic

## Migration Plan

1. Move files: `git mv scripts/telegram-notify/ scripts/notify/telegram/` and `git mv scripts/line-notify/ scripts/notify/line/`
2. Update all internal path references in the moved scripts
3. Update `docs/` and `.claude/commands/notify-setup.md`
4. Add Copilot functions to `registry.sh`
5. Add Copilot detection + event map to `hook.sh`
6. Add Copilot step to `install.sh`
7. Test: re-run install on a clean machine or verify idempotency on existing install

**Rollback:** `git revert` the commit; scripts remain at old paths. No config migration needed (config lives at `~/.config/ai-notify/config`).

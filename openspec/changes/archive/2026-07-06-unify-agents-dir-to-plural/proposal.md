## Why

The 2026-04-08 rename (commit 3b32011) moved the Antigravity/agent config dir from `.agent/`
to `.agents/` across specs, docs, and the tracked root, but **missed `install.sh` and
`template/common/.agent/`**. Worse, a later spec (`tooling-target-scope`) then *re-locked*
singular `.agent/` — a remnant of the old "only Claude Code + Antigravity" worldview the
project has since moved past (Claude Code primary; other AGENTS.md-aware tools best-effort).
Result: install.sh writes `.agent/` while the rest of the repo reads `.agents/`, a silent
split-brain. `.agents/` is the broader convention more tools read, so it is the target.

## What Changes

- **install.sh → `.agents/` everywhere** (skills, workflows, rules mirror; and read from
  `template/common/.agents`).
- **Rename `template/common/.agent/` → `template/common/.agents/`** (source dir).
- **MODIFIED spec `tooling-target-scope`:** the install-target requirement switches from
  singular `.agent/` to plural `.agents/`; keep the "must not be a no-op" guarantee (now for
  `.agents/`).
- **Doc/root fixups:** root `AGENTS.md` line referencing `.agent/` → `.agents/`.
- **Memory update:** the tooling-scope memory's "Antigravity reads FLAT `.agent/` (singular)"
  claim is corrected to plural `.agents/`.
- **Verify non-no-op:** install into a temp repo and assert `.agents/workflows/` and
  `.agents/rules/` are populated — directly retiring the old `.agent`/`.agents` no-op warning.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `tooling-target-scope`: install-target path for rules/workflows changes from singular
  `.agent/` to plural `.agents/`.

## Impact

- **Files:** `scripts/skills/install.sh`; rename `template/common/.agent/` → `.agents/`;
  root `AGENTS.md`; tooling-scope memory.
- **Out of scope (flagged follow-up):** `tooling-target-scope` Requirement 1 still frames the
  project as "only Claude Code + Antigravity" — now stale vs the CC-primary + others-best-effort
  pivot. Not rewritten here to keep this change to the dir unification; tracked for a separate
  worldview-scope change.

## 1. Retarget the invariance test (TDD — Red first)

- [x] 1.1 Retarget `tests/test_portable_agents_md.sh` tool-invariant checks (no secondary tool,
  stages-by-intent, no dangling refs, no `--cov`) from `template/common/AGENTS.md` to
  `template/common/docs/agent-protocol.md`.
  - **測試要求:** Red now (`docs/agent-protocol.md` does not exist yet). Green after 2.1.
- [x] 1.2 Add a check that `template/common/AGENTS.md` is a pointer: contains a pointer to
  `docs/agent-protocol.md` AND does not inline the protocol (no "Definition of Done" / stage
  list in it).
  - **測試要求:** Red now (AGENTS.md still holds the full protocol).
- [x] 1.3 Add a check that every managed doc carries the do-not-edit banner and seed docs do not.
  - **測試要求:** grep banner line in `agent-protocol.md`/`okf-conventions.md`, absent in
    `architecture.md`/`conventions.md`; Red now.

## 2. Relocate protocol + slim AGENTS.md

- [x] 2.1 Create `template/common/docs/agent-protocol.md` = current §1–6 operating protocol +
  managed banner at top.
  - **測試要求:** 1.1 green.
- [x] 2.2 Slim `template/common/AGENTS.md` to project mission/know-how placeholder + a stable
  pointer section to `docs/agent-protocol.md`.
  - **測試要求:** 1.2 green.
- [x] 2.3 Add the managed banner to `template/common/docs/okf-conventions.md`.
  - **測試要求:** 1.3 green.

## 3. Teach install.sh managed-vs-seed docs

- [x] 3.1 Add a managed-docs list (`agent-protocol.md`, `okf-conventions.md`) that install.sh
  overwrites; keep the rest of `docs/` copy-once (`--ignore-existing`). Document the rule
  inline next to the list. Do not change `AGENTS.md` copy-once behavior.
  - **測試要求:** bash test in a temp repo — pre-place a modified `agent-protocol.md` and
    `architecture.md`; after install, managed one is overwritten, seed one preserved.

## 4. Install & verify end-to-end

- [x] 4.1 Run install into a temp git repo (fresh + re-install-over-existing); assert: managed
  docs updated, seed docs + existing `AGENTS.md` preserved, all protocol references resolve,
  invariance suite passes.
  - **測試要求:** `bash tests/test_portable_agents_md.sh` green; both install scenarios pass.
- [x] 4.2 Add a migration note (in the change's proposal impact / a docs note) for existing
  installs: trim their inline-protocol `AGENTS.md` to the pointer to avoid stale duplication.
  - **測試要求:** manual — note present and accurate.

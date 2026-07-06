## 1. Verify harness (TDD — Red first)

- [x] 1.1 Add a bash test: install into a temp git repo, assert `.agents/workflows/` and
  `.agents/rules/` are non-empty AND no singular `.agent/` dir is created.
  - **測試要求:** Red now (install.sh writes `.agent/`, reads missing `.agents`). Green after §2.
- [x] 1.2 Add a repo-grep test: no live singular `.agent/` reference remains in
  `scripts/skills/install.sh`, root `AGENTS.md`, or `openspec/specs/` (archive excluded).
  - **測試要求:** Red now.

## 2. Unify the directory name

- [x] 2.1 Rename source dir `template/common/.agent/` → `template/common/.agents/` (git mv).
  - **測試要求:** dir exists at new path, old path gone.
- [x] 2.2 Update `scripts/skills/install.sh`: every `.agent/` → `.agents/` (write paths, the
  `$COMMON/.agents` read, comments).
  - **測試要求:** 1.1 green.
- [x] 2.3 Fix root `AGENTS.md` `.agent/` mention → `.agents/`.
  - **測試要求:** 1.2 green.

## 3. Align spec + memory

- [x] 3.1 (spec already staged as delta) confirm `tooling-target-scope` delta uses `.agents/`;
  it syncs to main on archive.
  - **測試要求:** 1.2 green (specs grep clean).
- [x] 3.2 Update the tooling-scope memory: correct "Antigravity reads FLAT `.agent/` (singular)"
  → plural `.agents/`.
  - **測試要求:** manual — memory reflects plural.

## 4. Verify

- [x] 4.1 Run the full verify suite + both install checks in a temp repo.
  - **測試要求:** all green; non-no-op confirmed.

## 1. Verification harness (TDD — write failing checks first)

- [x] 1.1 Add a bash test asserting the header names Claude Code as primary AND states
  portability to any AGENTS.md-aware tool, and contains no named secondary tool
  ("Codex"/"Antigravity") as "supported".
  - **測試要求:** grep over `template/common/AGENTS.md`; Red now (draft says "Codex and
    others supported"). Passes only after 2.1.
- [x] 1.2 Add a test asserting the body contains no binding `.codex/` / `.agents/` config-dir
  reference outside the vendored-config *principle* line.
  - **測試要求:** grep excludes the principle line; Red now.
- [x] 1.3 Add the "hide the parentheses" test: strip every `(Claude Code: ...)` and assert no
  stage line collapses to a bare command fragment (no line matching `^\s*[*-].*\b/opsx` after
  stripping).
  - **測試要求:** parse stage sections; Red now (③⑤⑥ collapse).
- [x] 1.4 Add a test asserting no `/openspec-verify-change`-style command is pinned for the
  open "other tools" set.
  - **測試要求:** grep absence; Red now.
- [x] 1.5 Add a dangling-reference test: every `docs/*.md` path referenced in the file exists in
  repo, and `docs/enforcement.md` is not referenced (or exists if kept).
  - **測試要求:** loop over grep'd paths + `test -f`; Red now (`docs/enforcement.md` missing).

## 2. Rewrite the installable AGENTS.md

- [x] 2.1 Rewrite header per D1/D3: "Claude Code primary; portable to any AGENTS.md-aware tool";
  remove named secondary tools.
  - **測試要求:** 1.1 green.
- [x] 2.2 Rewrite the vendored-config prohibition to state the principle and defer the directory
  list to the hook / enforcement mechanism (D2).
  - **測試要求:** 1.2 green.
- [x] 2.3 Convert every stage (§3/§4/§5/§6) to stage-intent + parenthetical Claude Code example;
  drop the "other CLIs" command enumeration (D3).
  - **測試要求:** 1.3 and 1.4 green.
- [x] 2.4 Trim DoD/enforcement prose so it claims only what the mechanism enforces; keep no
  language-specific mechanics (e.g. `--cov-fail-under`) in the portable map.
  - **測試要求:** manual review + assert no `--cov` string present in the file.

## 3. Resolve dangling references

- [x] 3.1 Decide `docs/enforcement.md`: create a minimal stub OR replace the §2 reference with an
  inline "backed by hook" note (default: remove the reference).
  - **測試要求:** 1.5 green.
- [x] 3.2 Confirm `install.sh` ships `docs/architecture.md`, `docs/conventions.md`,
  `docs/okf-conventions.md` into the target so §1 "Always read" resolves downstream; if not,
  either ship them or downgrade the §1 reference.
  - **測試要求:** run install into a temp dir; assert referenced docs exist post-install (or §1
    adjusted to match what actually ships).

## 4. Re-align consistency fallout

- [x] 4.1 Update `template/common/.claude/rules/multi-tool-compatibility.md` to "CC primary +
  generic", removing the CC + Antigravity hard-bind.
  - **測試要求:** grep asserts no exclusive "Antigravity only" framing; rule and AGENTS.md agree.
- [x] 4.2 Update the tooling-scope memory to reflect "CC primary; others best-effort, not bound".
  - **測試要求:** memory file + MEMORY.md index line updated (manual check).

## 5. Install & verify

- [x] 5.1 Run `scripts/skills/install.sh` into a temp git repo; assert the installed AGENTS.md
  matches source and all §1/§2 references resolve.
  - **測試要求:** full suite green in temp repo; `/opsx:verify` passes.

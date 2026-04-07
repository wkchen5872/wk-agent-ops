## 1. Remove audits and simplify context detection

- [x] 1.1 Remove H1 (template sync) audit from SKILL.md
- [x] 1.2 Remove O2 (OpenSpec spec sync) audit from SKILL.md
- [x] 1.3 Remove O3 (dead specs) audit from SKILL.md
- [x] 1.4 Remove D2 harness skill coverage sub-check (template/common/ comparison)
- [x] 1.5 Update context detection: remove `harness` context, keep only `standard` and `openspec`
- [x] 1.6 Update audit routing table to reflect removed audits and simplified contexts
- [x] 1.7 Update results display table in Step 4 to match new audit set

## 2. Enhance D3 — Dead references with Markdown link validation + auto-fix

- [x] 2.1 Add Markdown `[text](target)` link scanning to D3 audit logic
- [x] 2.2 Add `#anchor` validation (same-file and cross-file)
- [x] 2.3 Skip external links (http/https/mailto) during D3 scan
- [x] 2.4 Add auto-fix logic: single-match → update path; zero-match → remove link; multiple-match → report candidates
- [x] 2.5 Extend auto-fix to cover backtick path references (existing D3 logic)
- [x] 2.6 Update decision menu to offer auto-fix for D3 findings

## 3. Add C1 — Unused code audit

- [x] 3.1 Add Bash unused function detection (grep-based: defined but not called outside definition file)
- [x] 3.2 Add Python unused import detection (`import foo` / `from foo import bar` never used in file body)
- [x] 3.3 Add TypeScript/JavaScript unused named import detection
- [x] 3.4 Mark all C1 findings with "confirm before removing" label
- [x] 3.5 Ensure C1 is excluded from auto-fix options in decision menu

## 4. Enhance R1 — Refactor candidates with watermark recommendation

- [x] 4.1 Add watermark read logic: read `openspec/.entropy-state` if it exists
- [x] 4.2 Implement threshold logic: <5 → `/simplify`; 5–15 → both; >15 → `/refactor`
- [x] 4.3 Default to `/simplify` when watermark file absent
- [x] 4.4 Add exclusion of `openspec/` directory from R1 file scan
- [x] 4.5 Display archive count and maturity label alongside R1 recommendation

## 5. Verify and sync

- [x] 5.1 Run `/entropy-check` in this project — confirm `openspec` context detected, no H1/O2/O3 output
- [x] 5.2 Verify D3 finds a broken MD link in a test doc and auto-fix resolves it correctly
- [x] 5.3 Verify C1 detects an unused bash function in a test script
- [x] 5.4 Verify R1 watermark logic: set `.entropy-state` to 2, 10, 20 and confirm recommendation changes
- [x] 5.5 Run `bash scripts/skills/install.sh` to sync updated SKILL.md to `.claude/skills/entropy-check/SKILL.md`

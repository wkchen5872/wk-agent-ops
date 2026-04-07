## Context

`entropy-check` is an AI-executed skill (`/entropy-check`) that audits a project for accumulated drift. The current version has two classes of problems:

1. **Portability failures**: H1, O2, O3 audits hard-code assumptions about wk-agent-ops harness structure (`.claude/` install layer, `template/common/`). When installed in target projects, these audits produce false positives or errors.
2. **Missing signal**: No detection for unused code (dead weight that accumulates between feature cycles), no Markdown link validation with auto-fix, no maturity-aware refactor suggestions.

The fix is purely a SKILL.md rewrite — no new scripts, hooks, or install targets.

## Goals / Non-Goals

**Goals:**
- All audits work correctly in any project that installs the skill
- D3 auto-fix reduces human effort for documentation maintenance
- C1 surfaces dead code across Bash/Python/TS ecosystems
- R1 recommendation calibrated by actual project maturity (archive count)
- Context detection simplified to `standard` vs `openspec`

**Non-Goals:**
- Static analysis tooling (no AST parsing, no linters — AI-executed heuristics only)
- Auto-fix for C1 (unused code removal requires human judgment)
- Backward-compatible H1/O2/O3 stubs (clean removal)

## Decisions

### Decision 1: Remove H1/O2/O3 entirely (no stubs)

H1 (template sync), O2 (spec sync), O3 (dead specs) all depend on wk-agent-ops specific paths. Keeping stubs creates confusion. Removed entirely — the audits that replaced them (C1, enhanced D3) cover more valuable signal in any project type.

### Decision 2: D3 auto-fix uses AI search, not regex-only

Broken links need to be found in their new location. A pure bash `find` can locate files by name, but ambiguous cases (multiple matches) need AI judgment to pick the best target. The skill instructs the AI to:
1. Search for the target filename in project root
2. Update path if exactly one match found
3. Report for human resolution if multiple matches or zero matches

### Decision 3: C1 is heuristic, not exhaustive

Static analysis for "unused" is language-specific and complex. The skill uses grep-based heuristics:
- Bash: functions defined but with only 1 file in project containing their name (just definition, no callsite)
- Python/TS/JS: import statements where the imported name never appears in file body

False positives are expected and documented. Users confirm before acting.

### Decision 4: R1 watermark thresholds

Archive count correlates to project maturity:
- `< 5`: Early stage — `/simplify` (less disruptive, good for small codebases)
- `5–15`: Growing project — both suggestions
- `> 15`: Mature project — `/refactor` (structural work justified)

Thresholds are conservative. If `openspec/.entropy-state` does not exist, default to `/simplify`.

### Decision 5: D2 drops skill-coverage sub-check

The harness-specific sub-check (compare `template/common/skills/` vs AGENTS.md) is removed from D2. AGENTS.md coverage for harness projects is now a harness-team responsibility, not an entropy-check concern. D2 becomes three universal health checks only.

## Risks / Trade-offs

- **C1 false positives** → Clearly documented; C1 findings always marked "confirm before removing"
- **D3 auto-fix wrong target** → Multiple-match cases fall through to human review; single-match is almost always correct
- **R1 watermark missing** → Graceful default to `/simplify` recommendation
- **O1 now only openspec audit** → Standard projects get no OpenSpec audits, which is correct for projects without OpenSpec

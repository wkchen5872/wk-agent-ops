## Why

The `entropy-check` skill accumulated harness-specific audits (H1 template sync, O2/O3 based on `.claude/` installs) that prevent it from working correctly when installed in non-harness projects. The skill also lacks checks for unused code and broken Markdown link references, which are high-value signals in any project.

## What Changes

- **Remove** H1 (template sync) audit — harness-only, not portable
- **Remove** O2 (OpenSpec spec sync) and O3 (dead specs) audits — were producing systematic false positives due to date-prefix path mismatch and `.claude/`-only implementation detection
- **Remove** all `.claude/` / `.agents/` directory reads from audit logic
- **Add** C1 audit — unused code detection (unused variables, imports, private/unexported functions)
- **Enhance** D3 audit — extend dead reference checking to cover Markdown `[text](path)` links and `#anchor` references, with auto-fix capability
- **Revise** D2 audit — simplified to 3 portable health checks on AGENTS.md (existence, non-empty, no placeholders); remove harness-specific skill coverage sub-check
- **Enhance** R1 audit — use `openspec/.entropy-state` watermark count to calibrate recommendation level (`/simplify` vs `/refactor`)
- **Simplify** context detection — only `standard` vs `openspec` (harness context removed)

## Capabilities

### New Capabilities

- `entropy-check-d3-autofix`: Auto-fix broken Markdown links and backtick path references in docs by searching for relocated files and updating paths in-place
- `entropy-check-c1-unused-code`: Detect declared-but-unused functions, variables, and imports across Bash, Python, and TypeScript/JavaScript files
- `entropy-check-r1-watermark`: Calibrate refactor recommendation level using OpenSpec archive watermark count

### Modified Capabilities

- `entropy-check`: Remove H1/O2/O3 audits; simplify D2; update context detection to remove harness context

## Impact

- `template/common/skills/entropy-check/SKILL.md`: Primary change — rewritten audit logic
- `.claude/skills/entropy-check/SKILL.md`: Updated after running `install.sh`

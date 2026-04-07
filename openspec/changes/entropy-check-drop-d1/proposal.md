## Why

The D1 — AGENTS.md coverage audit scans all skills under `.claude/skills/` and `.agent/skills/` including third-party/superpowers skills, flooding results with noise about entries the user never authored. The audit was designed to help maintain custom project documentation but has the opposite effect in practice.

## What Changes

- Remove D1 — AGENTS.md coverage audit entirely from `entropy-check` SKILL.md
- Remove corresponding U1 requirement from the entropy-check spec
- Update audit routing table: D2/D3/C1/R1 run for standard context; D2/D3/C1/O1/R1 for openspec context
- Remove D1 auto-fix logic from the decision menu

## Capabilities

### New Capabilities

_None_

### Modified Capabilities

- `entropy-check`: Remove D1/U1 requirement; update audit routing table and results display

## Impact

- `template/common/skills/entropy-check/SKILL.md` — remove D1 section, update routing table
- `.claude/skills/entropy-check/SKILL.md` — same
- `.agent/skills/entropy-check/SKILL.md` — same
- `openspec/specs/entropy-check/spec.md` — remove U1 requirement and audit routing entry for D1

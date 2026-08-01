## Why

The entropy audit has not produced useful maintenance decisions in practice, while its skill, archive counter hook, state file, documentation, and historical specifications continue to add architectural noise. Retire the feature completely so a future replacement starts from current evidence instead of inheriting this design.

## What Changes

- **BREAKING** Remove the `entropy-check` skill from templates and installed provider mirrors.
- **BREAKING** Remove the `entropy-counter` workflow hook and stop installing it.
- Make skill and workflow upgrades remove stale installed entropy files, state, ignore entries, and hook registrations.
- Remove entropy-specific canonical specs, dedicated archived changes, and documentation; preserve unrelated content in mixed historical changes.
- Do not introduce a replacement audit or counter.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `entropy-check`: Remove the periodic entropy audit contract.
- `entropy-check-c1-unused-code`: Remove unused-code detection from the entropy audit.
- `entropy-check-d3-autofix`: Remove dead-reference validation and auto-fix behavior.
- `entropy-check-r1-watermark`: Remove watermark-based refactor recommendations.
- `entropy-counter-hook`: Remove archive counting, notification, and hook installation behavior.

## Impact

- Templates and installed mirrors under `template/common/skills/`, `.claude/skills/`, and `.agents/skills/`.
- Skill and workflow installers, including legacy cleanup for existing installations.
- Claude Code and Copilot CLI hook registrations previously managed by `entropy-counter`.
- OpenSpec canonical specs and historical changes dedicated to the retired feature.
- Architecture, hook, and skill documentation. No replacement dependency is added.

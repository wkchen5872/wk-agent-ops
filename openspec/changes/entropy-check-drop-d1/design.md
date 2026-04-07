## Context

The entropy-check skill currently runs a D1 audit that scans all skills in `.claude/skills/` and `.agent/skills/` for AGENTS.md entries. In practice, these directories contain large numbers of third-party/superpowers skills that the project author never wrote and has no obligation to document. The result is a noisy report of irrelevant findings on every run.

## Goals / Non-Goals

**Goals:**
- Remove D1 audit (AGENTS.md coverage) from the entropy-check skill entirely
- Update the audit routing table in SKILL.md and spec to reflect D1 removal
- Remove D1 auto-fix logic from the decision menu

**Non-Goals:**
- Replacing D1 with a smarter filter (e.g., only checking project-authored skills)
- Changing any other audit (D2, D3, C1, O1, R1)

## Decisions

**Remove rather than refine**: A filtered version of D1 (e.g., only checking skills in a project's own `.claude/skills/` vs superpowers) would require maintaining a list of "owned" vs "third-party" paths that doesn't exist. Simple removal is cleaner and matches the user's intent.

**Update all three SKILL.md copies**: The skill exists in `template/common/`, `.claude/skills/`, and `.agent/skills/`. All three must be updated identically to stay in sync.

## Risks / Trade-offs

[No meaningful risk] → D1 was pure noise; its removal has no functional downside.

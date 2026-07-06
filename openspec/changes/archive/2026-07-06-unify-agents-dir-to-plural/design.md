## Context

`install.sh` writes singular `.agent/` (L85–130) and reads `template/common/.agent/`, while
specs (except tooling-target-scope), docs, and the tracked root use plural `.agents/`. The
singular usage is a remnant of the "only CC + Antigravity" worldview; the project now treats
Claude Code as primary with other AGENTS.md-aware tools best-effort, and `.agents/` is the
broader convention. This is a mechanical unification with one behavioural guarantee to preserve.

## Goals / Non-Goals

**Goals:**
- One dir name repo-wide: `.agents/` (plural). No singular `.agent/` remains in live code/specs.
- The install copy is proven non-no-op (workflows + rules actually land in `.agents/`).

**Non-Goals:**
- Rewriting `tooling-target-scope` Requirement 1's "only CC + Antigravity" scope framing
  (separate worldview change).
- Touching archived changes (historical `.agent/` references stay as-is).

## Decisions

**D1 — Unify on plural `.agents/`.** Chosen per user direction (broader tool support) and
consistency with the already-plural specs/docs/root. The singular spec requirement is the
outlier and is corrected, not the majority.

**D2 — Preserve the non-no-op guarantee with a test.** The old spec warned a name mismatch
silently skips the copy. TDD: add a temp-repo install assertion that `.agents/workflows/` and
`.agents/rules/` are non-empty after install. This retires the warning by proof, not by prose.

**D3 — Rename the source dir with the code.** `template/common/.agent/` → `.agents/` so
install.sh's read side and write side agree; otherwise the copy is a no-op (the exact bug).

## Risks / Trade-offs

- **[A tool actually reads singular `.agent/`]** would break if the user's premise is wrong. →
  Mitigation: user is the authority on tool behaviour and directed plural; the non-no-op test
  confirms files land, and downstream can be re-installed trivially.
- **[Transient incoherence with Requirement 1]** dir says "more tools" while Req 1 still says
  "only CC + Antigravity". → Mitigation: flagged as an explicit follow-up in the proposal;
  the memory already carries the corrected worldview.
- **[Stray singular `.agent/` left in a target]** from a prior install. → Mitigation: note in
  tasks; new installs only create `.agents/`. Cleaning existing targets is a manual one-liner.

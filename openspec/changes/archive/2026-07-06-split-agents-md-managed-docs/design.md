## Context

install.sh already has an implicit two-category model: `.claude/`, `.agent/`, skills, hooks,
and profile rules are **managed** (`rsync -a`, overwritten every run); `AGENTS.md` and `docs/`
are **seed** (copy-once). The bug is placement: the shared Operating Protocol lives in
`AGENTS.md` (seed) and thus can never update downstream, while `AGENTS.md` must stay seed
because each project appends its own know-how. `okf-conventions.md` (a shared standard) has the
same misplacement in seed `docs/`.

## Goals / Non-Goals

**Goals:**
- A protocol update reaches an already-installed repo by re-running install.sh — no manual merge.
- `AGENTS.md` stays project-owned and editable; its shared content is a stable pointer only.
- One classification rule: shared standard → managed (overwrite); project-fill → seed (copy-once).
- Doc paths stay stable (no dangling-ref regressions from the prior change).

**Non-Goals:**
- Slimming this repo's *root* `AGENTS.md` (separate dogfood follow-up).
- In-file managed blocks (Flavor B) — deferred.
- A full template-sync tool (copier/cruft) — YAGNI at this scale.

## Decisions

**D1 — Split by ownership; protocol relocates to a managed doc (Flavor A).**
`AGENTS.md` (seed) keeps a stable pointer section; the §1–6 protocol moves to
`docs/agent-protocol.md` (managed). Chosen over Flavor B (marker-delimited managed block inside
`AGENTS.md`) because the pointer is inherently stable, so no in-file block-replace machinery or
marker discipline is needed. Upgrade path to B remains open if the pointer itself ever needs to
evolve downstream.

**D2 — Managed docs by explicit list, not a subdir.**
install.sh overwrites a known list (`agent-protocol.md`, `okf-conventions.md`) and leaves the
rest of `docs/` copy-once. Chosen over a `docs/_shared/` subdir because a subdir would move
file paths and re-introduce dangling references (the prior change just fixed those). Paths stay
put; only the overwrite policy differs per file.

**D3 — Managed files carry a do-not-edit banner.**
Same discipline as generated files. The banner is the contract that makes "overwrite on
install" safe/expected. Without it, a downstream editor loses work silently.

**D4 — Invariance test follows the content.**
The tool-invariant checks (no secondary tool, stages-by-intent, no dangling refs, DoD) now
target `docs/agent-protocol.md`; a new check asserts `AGENTS.md` is a pointer (contains the
pointer, does not inline the protocol). TDD: retarget the checks first (Red), then relocate.

**D5 — Migration is manual for existing installs (documented, not automated).**
Existing downstream `AGENTS.md` is seed → untouched; it keeps its old inline protocol and now
also gets `docs/agent-protocol.md` → duplication (one stale). Auto-slimming a seed file that
holds the project's own edits is unsafe, so migration is a documented one-time manual trim, not
a script.

## Risks / Trade-offs

- **[Duplication window on existing installs]** old inline protocol in `AGENTS.md` + new managed
  doc → agent may read the stale inline copy. → Mitigation: migration note instructs trimming
  `AGENTS.md` to the pointer; the pointer explicitly says the protocol lives in the managed doc.
- **[Managed overwrite clobbers a downstream edit to a managed doc]** by design. → Mitigation:
  the D3 banner makes this expected; anything a project wants to customize belongs in a seed doc
  or in `AGENTS.md`, not in a managed doc.
- **[Agent ignores the pointer and never reads the protocol]** progressive-disclosure bet. →
  Mitigation: pointer is short, imperative ("read `docs/agent-protocol.md` before any task"),
  same pattern as the graphify section that already works in this repo.
- **[Explicit managed list drifts]** a new shared doc added later but not added to the list stays
  seed (silently un-updatable). → Mitigation: document the rule next to the list in install.sh;
  the class-level fix (both current shared docs) is applied now.

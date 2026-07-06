## Context

`template/common/AGENTS.md` is installed verbatim into downstream projects by
`scripts/skills/install.sh`. It is the one file that must stay valid under *any*
AGENTS.md-aware coding tool. The current v2.0.0 draft mixes tool-invariant intent with
tool-specific facts (named secondary tools, directory lists, `/opsx:*` command strings),
which rot as the tool set changes and — for a file that ships everywhere — turn into dead
references and self-contradiction against `multi-tool-compatibility.md` and the
tooling-scope memory.

## Goals / Non-Goals

**Goals:**
- Every sentence in `AGENTS.md` survives a tool swap (the "hide the parentheses" test).
- Tool-specific facts (directory list, command names) live in exactly one place each:
  the hook (dirs) and per-tool shims / parenthetical examples (commands).
- No dangling references in the shipped file.
- The rewrite is mechanically verifiable — the spec scenarios map to grep-style checks.

**Non-Goals:**
- The Python coverage-gate hook mechanics (separate change `add-coverage-gate-python-hook`).
- Restructuring `install.sh` beyond confirming it ships the docs `AGENTS.md` references.
- Rewriting the *root* `AGENTS.md` (this change is only the installable `template/common/` one).

## Decisions

**D1 — One invariance rule governs the whole file.**
For any concrete string (tool name / directory / command), ask: "does it still hold under a
different tool?" If yes → keep (invariant). If no → demote: primary-tool command → a
parenthetical example; full list → the hook (dirs) or the tool's own shim (commands).
Chosen over per-section ad-hoc rewrites because a single stated rule is what keeps the file
from re-drifting.

**D2 — Principle in prose, list in the mechanism (vendored-config prohibition).**
Prose states "never touch generated / vendored agent-config directories"; the authoritative
directory list lives in the enforcement hook. Rationale: adding a new tool then touches one
hook line, not the portable map. Alternative (enumerate dirs in prose) rejected — it couples
the portable layer to a changing list.

**D3 — Stage-first, command-as-example.**
Describe stages by intent (plan → spec → review → implement → verify → seal); Claude Code
command appears only as `(Claude Code: /opsx:xxx)`. Drop `/openspec-verify-change (other
CLIs)` — the "other tools" set is open and cannot be pinned. Alternative (list every tool's
command) rejected: unmaintainable and already wrong for a third tool.

**D4 — Fix consistency fallout in the same change.**
Re-align `multi-tool-compatibility.md` (CC primary + generic, not CC + Antigravity hard-bind)
and update the tooling-scope memory, so the source of truth stops contradicting itself.
Resolve `docs/enforcement.md`: create a minimal stub OR remove the reference (decided in
tasks after checking whether a real enforcement doc is wanted now).

**D5 — Verification is grep-based, run against the installed copy.**
Each spec scenario becomes a shell assertion over `template/common/AGENTS.md` (and, for the
dangling-ref check, over the install output). No new framework — the existing bash-test
pattern used elsewhere in the repo.

## Risks / Trade-offs

- **[Grep checks are proxies for intent]** → A regex can confirm absence of `.codex/` but not
  that prose is "truly tool-agnostic". Mitigation: pair each mechanical check with the
  human-readable "hide the parentheses" review step in the DoD; the grep is a floor, not the
  ceiling.
- **[`docs/enforcement.md` decision deferred to tasks]** → Could stall implementation.
  Mitigation: default to removing the dangling reference (inline "backed by hook" one-liner)
  unless a real enforcement doc is already wanted; either resolves the spec's no-dangling-ref
  requirement.
- **[Re-aligning the memory + rule widens the diff]** → Slightly larger blast radius than a
  pure file edit. Accepted: leaving them contradictory would reintroduce the exact self-conflict
  this change exists to remove.
- **[BREAKING downstream doc content]** → Installed `AGENTS.md` text changes materially.
  Mitigation: it is documentation, not code; downstream picks it up on next install, no runtime break.

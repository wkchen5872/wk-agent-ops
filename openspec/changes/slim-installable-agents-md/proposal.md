## Why

The installable `template/common/AGENTS.md` is the tool-agnostic operating map that
ships into downstream projects, yet the current draft hard-binds it to specific
tools: it names `.codex/` and "Codex and others supported" (contradicting the
recent CC + Antigravity focus and the `multi-tool-compatibility.md` rule), enumerates
tool-specific directories in prose, and pins Claude Code slash-command strings
(`/opsx:*`) as the primary way to describe each stage. These bindings rot as tools
change and break the file's reason to exist — `AGENTS.md` is precisely the layer that
must stay valid under *any* AGENTS.md-aware tool.

## What Changes

- **De-bind from named secondary tools.** Header states "Claude Code primary; portable
  to any AGENTS.md-aware tool" and names no secondary tool. Remove `.codex/`
  enumeration and the "Codex and others supported" claim.
- **Prohibitions state principle, not directory lists.** The vendored-config
  prohibition describes the *principle* ("never touch generated / vendored agent-config
  directories"); the authoritative directory list moves to the enforcement mechanism
  (hook / `docs/enforcement.md`), not portable prose.
- **Commands become stage + example, not the spec.** Every stage (plan → spec →
  review → implement → verify → seal) is described by its tool-invariant intent, with
  the Claude Code command as a parenthetical example only. Remove the
  `/openspec-verify-change (other CLIs)` enumeration — the "other tools" set is open and
  must not be pinned to a fake command.
- **DoD claims only what the mechanism guarantees.** The coverage-gate line stays as
  intent; prose must not over-claim beyond what the hook actually enforces (vacuous-pass
  and language-specific mechanics stay out of the portable map).
- **BREAKING (downstream doc content):** the installed `AGENTS.md` text changes
  materially; downstream projects re-running install get the new map.

## Capabilities

### New Capabilities
- `portable-agents-md`: The content contract for the installable `template/common/AGENTS.md`
  — tool-agnostic operating map whose prose stays valid under any AGENTS.md-aware tool
  (no named secondary tools, principle-not-list prohibitions, stage-not-command
  descriptions, no dangling references).

### Modified Capabilities
<!-- None: template-profile-structure governs directory layout, not AGENTS.md content. -->

## Impact

- **File:** `template/common/AGENTS.md` (rewritten to v2.x per the new contract).
- **Consistency:** `multi-tool-compatibility.md` rule and the tooling-scope memory need
  re-alignment (CC primary + generic, not CC + Antigravity hard-bind) — tracked as tasks.
- **Dangling refs:** `docs/enforcement.md` referenced by the draft does not exist; must
  be created or the reference removed. Confirm install.sh ships `docs/architecture.md`,
  `docs/conventions.md`, `docs/okf-conventions.md` so §1 "Always read" resolves downstream.
- **Out of scope:** the Python coverage-gate hook mechanics (separate change
  `add-coverage-gate-python-hook`).

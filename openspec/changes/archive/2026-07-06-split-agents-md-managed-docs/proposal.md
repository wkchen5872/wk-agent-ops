## Why

`install.sh` copies `template/common/AGENTS.md` **copy-once** (only if absent) and each
downstream project then appends its own project know-how into that same file. So the shared
Agent Operating Protocol is trapped in a project-owned, never-updated file: once installed,
**no protocol update can ever reach an already-running repo**. The same latent bug hits
`docs/okf-conventions.md` (a shared standard shipped copy-once via `--ignore-existing`).

The root cause is an ownership mismatch: a **shared standard** (upstream-owned, should update)
lives inside a **project-owned seed** file (must not be overwritten). A file cannot be both.

## What Changes

- **Split `AGENTS.md` by ownership (graphify model).** `template/common/AGENTS.md` becomes a
  thin, project-owned map: project mission/know-how + a **stable pointer section** to the
  shared protocol. It stays copy-once (seed).
- **Relocate the operating protocol to a managed doc.** The §1–6 Operating Protocol moves to
  `template/common/docs/agent-protocol.md`, which install.sh **overwrites on every run**
  (upstream-owned). Downstream pulls protocol updates simply by re-running install.sh.
- **Teach install.sh managed-vs-seed docs.** A known set of shared-standard docs
  (`agent-protocol.md`, `okf-conventions.md`) is overwritten; project-fill docs
  (`architecture.md`, `conventions.md`) stay copy-once. Paths are unchanged.
- **Managed files carry a do-not-edit banner** so downstream knows edits get overwritten.
- **Relocate the invariance test.** `tests/test_portable_agents_md.sh` retargets the
  tool-invariant checks to `docs/agent-protocol.md` (where the protocol now lives) and adds a
  check that `AGENTS.md` is a pointer.
- **BREAKING (downstream):** existing installs keep their old inline-protocol `AGENTS.md`
  (seed, untouched) but now also receive `docs/agent-protocol.md`; a one-time manual slim of
  their `AGENTS.md` to the pointer is needed to avoid stale duplication (migration note).

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `portable-agents-md`: the tool-invariant rules now govern the relocated managed protocol doc
  (`docs/agent-protocol.md`); `AGENTS.md` becomes a thin pointer. Subjects shift from "the
  installable AGENTS.md" to "the installed operating protocol doc".
- `install-profile-cli`: add managed-vs-seed ownership for shipped docs — shared standards are
  overwritten on install; project-fill docs remain copy-once.

## Impact

- **Files:** rewrite `template/common/AGENTS.md` (→ pointer); new
  `template/common/docs/agent-protocol.md`; `scripts/skills/install.sh` (managed docs list);
  banner on `template/common/docs/okf-conventions.md`; retarget `tests/test_portable_agents_md.sh`.
- **Out of scope:** slimming this repo's *root* `AGENTS.md` (dogfood follow-up); block-marker
  in-file updates (Flavor B) — deferred unless the stable pointer proves insufficient; adopting
  a full template sync tool (copier/cruft) — YAGNI.

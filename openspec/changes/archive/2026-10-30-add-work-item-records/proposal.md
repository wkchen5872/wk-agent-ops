# Proposal

## Why

Agents collaborating on one requirement across several sessions and tools have no sanctioned
place to keep pre-specification analysis, disagreements, and review notes, so context is
re-pasted by hand and independent analysis is lost. A Work Item convention exists and has been
exercised in another repository, but `template/common/` currently has no delivery path for it:
the installer copies only enumerated paths, `work-items/` and `CLAUDE.md` are not among them,
and root `AGENTS.md` is seed-only, so an already-installed project receives nothing. A missing
ignore rule is also a disclosure risk, because the commit agent stages with `git add -A`.

## What Changes

- Ship the Work Item convention as a managed file at `work-items/AGENTS.md`, refreshed in every
  target each time the installer runs, as the single source of the convention.
- Deliver the activation entry through channels that already refresh on every run: a short
  `.claude/rules/work-items.md` entry (mirrored to `.agents/rules/`) and one conditional
  pointer line in the managed `docs/agent-protocol.md`.
- Generalize the installer's managed-file list from `docs/`-only filenames to root-relative
  paths, so a managed file can live outside `docs/`.
- Merge the Work Item ignore rule into the target `.gitignore`, keyed on whether the records are
  already effectively ignored, so that untracked records cannot be staged by `git add -A`. Records
  a project already tracks are reported, not untracked, and remain unprotected.
- Reduce the Work Item section in the seed `template/common/AGENTS.md` to a stable three-line
  pointer, and remove `template/common/CLAUDE.md` so personal preferences and a 17 KB eager
  import are not distributed into every project.
- Keep the convention tool-neutral: replace the named-tool session alias example.

## Capabilities

### New Capabilities
- `work-item-records`: Location and Git boundary of disposable cross-session collaboration
  records, single-source delivery of the convention, write ownership, evidence marking, formal
  handoff criteria, and cleanup authority.

### Modified Capabilities
- `install-profile-cli`: Root-relative managed files and idempotent `.gitignore` rule merging.
- `template-profile-structure`: `template/common/` carries `work-items/`; no `CLAUDE.md`.
- `portable-agents-md`: The seed `AGENTS.md` may carry a second stable pointer section, and a
  protocol reference outside `docs/` must also ship downstream.

## Impact

Changes are scoped to `template/common/`, `scripts/skills/install.sh`, `tests/`, and this
OpenSpec change. No product code and no Git index changes. Target projects keep their own
`AGENTS.md`, `CLAUDE.md`, and existing ignore rules; the installer adds one ignore line and
refreshes managed files. New records are kept out of Git and are allowed to disappear with an
authorized worktree removal; records a project already tracks are only reported. No hook enforcement, database, MCP server, orchestrator, or
permanent review system is introduced. Moving the personal communication preferences to the
user-level `~/.claude/CLAUDE.md` is a user-side step outside this repository.

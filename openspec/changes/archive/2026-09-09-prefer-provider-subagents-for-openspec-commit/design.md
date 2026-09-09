## Context

See `proposal.md` for motivation. The repository already has one portable skill
for each capability and provider-native Claude Code and Codex agents with pinned
models. The installer copies templates without deleting destination-only files,
so a filename-only rename would leave ambiguous legacy agents installed.

## Goals / Non-Goals

**Goals:**

- Make skill and subagent references unambiguous by name.
- Prefer model-pinned native subagents only for Claude Code and Codex.
- Preserve portable skill execution for every other provider.
- Upgrade existing installations without deleting unrelated provider files.

**Non-Goals:**

- Add a provider registry, runtime detection script, or new orchestration layer.
- Add native subagent formats for providers other than Claude Code and Codex.
- Change the models, reasoning effort, or operational logic of either capability.

## Decisions

### Use `-agent` only on provider-native subagents

Rename both Claude Code and Codex agents to `doc-updater-agent` and
`git-commit-writer-agent`. Keep the portable skills as `doc-updater` and
`git-commit-writer`. This makes the requested execution mechanism explicit at
the call site without duplicating capability logic.

Alternative considered: retain identical names and rely on provider tool syntax.
Rejected because prose-based orchestration can still match the wrong capability
and is harder to audit.

### Use two explicit provider branches and one default route

`openspec-commit` will name Claude Code and Codex as native-subagent providers.
All other providers follow the existing portable skills. This avoids an
ever-growing allowlist for skill-only providers.

Alternative considered: detect whether a subagent exists and otherwise use a
skill. Rejected because a broken Claude Code or Codex installation would silently
lose the configured model and effort guarantee.

### Fail closed for missing known-provider subagents

Claude Code and Codex stop when their required suffixed subagent cannot be
invoked. Unknown and skill-only providers are not errors; they use the portable
skills by design.

### Remove only exact legacy managed filenames

Before syncing provider-native agents, the installer will remove the four exact
obsolete installed files owned by this project: two Claude Code Markdown files
and two Codex TOML files. It will not use `rsync --delete`, because provider
directories may contain user-owned agents outside this template.

### Test the routing contract and migration boundary

Add failing assertions first for suffixed templates, provider routing text, and
legacy-file cleanup. The focused checks will install into a temporary Git
repository containing both legacy managed files and an unrelated custom agent,
then verify that only the managed legacy files disappear. Existing shell suites
remain the affected regression boundary.

## Risks / Trade-offs

- [Direct standalone references to old agent names stop working] → Document the
  suffixed invocation names and remove legacy files during installation.
- [Text-defined routing depends on the host following the skill contract] → Use
  explicit provider branches, exact capability names, and observable subagent
  invocation in the provider UI as acceptance evidence.
- [Cleanup could remove user-edited copies of the old managed filenames] → Limit
  deletion to the exact filenames already owned by this project and describe the
  migration as a managed rename.

## Migration Plan

1. Add focused tests that fail against the unsuffixed templates and current
   Codex-to-skill route.
2. Rename the four source templates and update their internal names.
3. Add exact legacy-file cleanup to the installer, then synchronize generated
   targets through the installer.
4. Update `openspec-commit` routing and documentation references.
5. Run focused suites, all affected shell suites, and strict OpenSpec validation.

Rollback restores the old template filenames and routing text. Re-running the
restored installer recreates the previous managed agent files; unrelated agents
remain untouched in either direction.

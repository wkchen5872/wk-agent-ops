## Context

See `proposal.md` for motivation. The common installer currently propagates `.claude/` and plural `.agents/` content, while two tracked `.codex/agents/*.toml` files have no template source and have drifted. Codex custom agents require standalone TOML files, so their provider-specific representation cannot be byte-identical to the Claude Markdown frontmatter format.

## Goals / Non-Goals

**Goals:**

- Establish `template/common/.codex/agents/` as the source for exactly two project-owned Codex custom agents.
- Keep their behavior aligned with the maintained Git Commit Writer and Doc Updater contracts.
- Propagate and validate exact template-to-target content.

**Non-Goals:**

- Managing `.codex/skills/`, `.codex/config.toml`, or any OpenSpec-generated Codex artifact.
- Building a cross-format generator for Claude Markdown and Codex TOML.
- Adding new agents, dependencies, or global Codex defaults.

## Decisions

### Keep provider-native Codex TOML templates

Store the two TOML files directly under `template/common/.codex/agents/`. This is the smallest implementation that preserves Codex's required schema and keeps installed files reviewable. A prompt generator was rejected because two files do not justify another transformation layer or schema.

### Synchronize only the agents subdirectory

Add one installer sync from `template/common/.codex/agents/` to `<target>/.codex/agents/`. Do not synchronize the `.codex/` parent wholesale; this prevents accidental ownership of OpenSpec skills and user configuration.

### Use explicit per-agent model settings

Set Git Commit Writer to `gpt-5.6-luna` with medium effort because its workflow is narrow and repeatable. Set Doc Updater to `gpt-5.6-terra` with medium effort because it performs read-heavy diff and documentation synthesis. Keep these settings in each TOML rather than adding global `[agents]` defaults.

### Test observable propagation before implementation

Extend the focused installer test first so a clean temporary repository expects `.codex/agents/`, exact template equality, exact model values, and continued absence of singular `.agent/`. The existing test's blanket prohibition on `.codex/` becomes the expected Red and is replaced by precise ownership checks.

## Risks / Trade-offs

- [Codex and Claude instructions can drift semantically] → Keep only two provider files, update both representations in the same change, and test exact template-to-installed equality; avoid a generator until drift becomes recurrent.
- [Synchronizing `.codex/` could overwrite external content] → Sync only `.codex/agents/`; rsync does not delete unrelated files.
- [Model availability can vary by Codex release or account] → Use the current official model IDs selected by the user and keep them isolated in provider-specific templates for easy revision.

## Migration Plan

1. Add a failing focused installer test for the new Codex agent ownership boundary and model values.
2. Add the Codex templates and narrow installer sync.
3. Run the installer against this repository to refresh tracked targets.
4. Update affected documentation and run focused plus project-required checks.

Rollback removes the narrow sync and templates; existing user-owned `.codex/config.toml` and OpenSpec-generated skills are never touched.

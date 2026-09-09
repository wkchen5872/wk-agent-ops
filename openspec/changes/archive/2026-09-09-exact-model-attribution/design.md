## Context

See `proposal.md` for motivation. Attribution is coordinated through prompt contracts rather than an executable runtime API: `openspec-commit` resolves values and the commit writer consumes them. Provider runtime metadata is not uniform, and Claude Code does not publish a stable `turn_context` contract equivalent to the Codex session event observed during diagnosis.

## Goals / Non-Goals

**Goals:**

- Put model-identity resolution at the provider-facing coordinator boundary.
- Preserve one provider-neutral commit-writer input, `assisting_model`.
- Make uncertain, aliased, family-only, or switched-model cases stop before commit.
- Cover the behavior with the existing static shell contract tests.

**Non-Goals:**

- Parsing Codex or Claude Code transcript/session files.
- Looking up model catalogs during commit execution.
- Recording reasoning effort in Git trailers.
- Automatically allocating credit across multiple implementation models.
- Amending historical commits.

## Decisions

### Resolve once at the coordinator boundary

`openspec-commit` will resolve the primary implementation model immediately before commit delegation and pass the frozen value to the writer. Runtime metadata is accepted only when it both exposes an exact identity and unambiguously represents the implementation context. Otherwise the user supplies the value.

Alternative considered: let each commit writer discover its runtime model. Rejected because the writer's model may differ from the implementation model.

### Keep provider adapters declarative

The shared skill will state provider-specific evidence rules: Codex can consume exact current-turn metadata; Claude Code can consume only an exact identity exposed by a supported interface. Neither route will parse private session storage. This keeps the contract usable when provider internals change.

Alternative considered: add a shared JSONL parser. Rejected because the formats are provider-specific, internal, and unnecessary when the user can resolve ambiguous cases.

### Validate meaning, not a model catalog

The coordinator and writer will reject values identified as family names or aliases, with representative examples such as `GPT-5` and `sonnet`. They will not maintain an allowlist of current model IDs. Exact runtime-provided or explicitly user-confirmed identities pass through unchanged.

Alternative considered: query product documentation or maintain an allowlist. Rejected because catalog validity does not prove which model performed the implementation and the list would drift.

### Preserve reasoning effort separately

Model switching and reasoning effort remain runtime concerns. Only the exact primary implementation model is committed; effort is neither required nor added to the trailer.

## Risks / Trade-offs

- [Provider runtime metadata is unavailable to a skill] → Ask the user at the existing pre-commit attribution boundary.
- [A session uses multiple implementation models] → Require the user to choose the primary model; do not infer credit allocation.
- [Natural-language validation cannot classify every future alias] → Test representative invalid classes and rely on provenance plus user confirmation instead of a catalog parser.

## Migration Plan

1. Add failing static assertions for provenance rules, ambiguity handling, and generic-label rejection.
2. Update source templates for `openspec-commit` and all commit-writer variants.
3. Run the common installer to regenerate managed project targets.
4. Run focused tests and strict OpenSpec validation.

Rollback is a normal revert of the template, generated-target, test, spec, and documentation changes; no stored data migrates.

## Context

See `proposal.md` for motivation and `specs/bulk-read-routing/spec.md` for behavior. Existing `template/common/` content installs into projects, so this frequently used personal capability needs a separate source and installer that target user-level provider directories without broadening project installer ownership.

Claude Code and Codex use different native custom-agent formats. The routing policy can remain one shared Markdown skill, while model, tool, and sandbox settings stay in provider-native agent files.

## Goals / Non-Goals

**Goals:**

- Keep one canonical routing skill and two small provider-native agents.
- Enforce read-only discovery using the strongest provider-native controls available.
- Install only exact managed files and preserve unrelated user configuration.
- Leave a focused automated check plus replayable provider A/B evaluation.

**Non-Goals:**

- Create a general user-skill registry, profile system, or separate repository.
- Modify `template/common/`, `scripts/skills/install.sh`, or project installations.
- Generate Claude Markdown and Codex TOML from another schema.
- Parallelize discovery across multiple agents or delegate engineering decisions.

## Decisions

### Keep the user capability in an isolated template subtree

Store the canonical skill and provider agents under `template/user/bulk-read-routing/`. This makes ownership explicit without creating a generic user-template framework before a second capability needs it. A new repository and a general manifest-driven installer were rejected as premature.

### Use one dedicated installer

Add `scripts/user/install-bulk-read-routing.sh` with provider selectors and overridable user roots for safe testing. Its defaults resolve to the native user locations, while tests pass temporary roots. It creates parent directories and copies only the skill and agent files; it never deletes or synchronizes a whole directory.

### Use one cross-provider agent name

Name both native agents `bulk-reader-agent`, matching this repository's existing `-agent` convention. The shared skill can therefore issue one exact routing instruction without provider branches. Spawn-time model overrides are forbidden; each provider file owns its model choice.

### Constrain Claude through its tool allowlist

Give the Claude agent only `Read`, `Grep`, and `Glob`; omit Bash and all editing tools. Use the efficient `haiku` alias initially and validate its evidence quality against the provider's stronger model during evaluation.

### Constrain Codex through its sandbox

Set the Codex agent to `gpt-5.6-luna`, medium reasoning, and read-only sandbox mode, following existing repository model-routing conventions. Retain an explicit no-network instruction because filesystem read-only and network access are separate concerns.

### Test behavior before implementation

First add one focused shell test that fails because the isolated templates and installer do not exist. It will validate exact copies, provider selection, idempotency, unrelated-file preservation, matching agent names, and provider restrictions. After Green, run static validation and document a small A/B matrix for real Claude Code and Codex sessions; nondeterministic model-quality claims remain evaluation results rather than shell-test assertions.

## Risks / Trade-offs

- [A dedicated installer duplicates a few copy operations] → Accept the small duplication until multiple user-level capabilities justify shared infrastructure.
- [A lightweight model can miss relevant evidence] → Require parent verification and compare evidence accuracy in provider A/B evaluation.
- [Prompt instructions cannot prove network isolation] → Use provider controls where available, retain the explicit prohibition, and report the boundary accurately.
- [Automatic skill routing varies by provider and model] → Test both positive and negative prompts and record actual spawn count rather than assuming activation.
- [Installing into a home directory can overwrite an existing same-name capability] → Limit writes to exact owned paths and support temporary-root dry validation; the named managed files are intentionally replaceable by rerunning the installer.

## Migration Plan

1. Add the focused failing installer and contract test.
2. Add the isolated skill and provider agent templates plus dedicated installer.
3. Run tests against temporary user roots, then validate OpenSpec and shell checks.
4. Run the installer explicitly for the desired real user providers only after automated checks pass.
5. Perform and record provider A/B evaluation separately because runtime model behavior is nondeterministic.

Rollback removes only the four installed managed files for this capability; unrelated user and project files are outside the installer boundary.

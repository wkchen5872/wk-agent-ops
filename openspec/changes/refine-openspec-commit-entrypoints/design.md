## Context

See `proposal.md` for motivation. The canonical completion behavior already
lives in `template/common/skills/openspec-commit/SKILL.md`; the two provider
entrypoints are project-owned aliases installed from `template/common/`.
Generated `.claude/` and `.agents/` files are installer outputs and cannot be
edited directly.

The entrypoints have different command surfaces:

| Provider | Entrypoint | Invocation |
|---|---|---|
| Claude Code | `.claude/commands/opsx/commit.md` | `/opsx:commit [change-name]` |
| Antigravity | `.agents/workflows/opsx-commit.md` | `/opsx-commit [change-name]` |
| Codex | installed project skill | direct `openspec-commit` invocation |

## Goals / Non-Goals

**Goals:**

- Keep both provider entrypoints as small, provider-specific adapters.
- Make one delegation the only executable action described by each adapter.
- Preserve an optional change name across the adapter boundary.
- Prove template-to-target propagation and provider wording mechanically.

**Non-Goals:**

- Duplicate the archive, documentation, or commit algorithm in either adapter.
- Add a Codex command alias or a provider abstraction layer.
- Change `openspec-commit` orchestration, archive semantics, or commit behavior.
- Resolve upstream OpenSpec `.agent/` and Antigravity `.agents/` path drift.

## Decisions

### 1. Entrypoints remain aliases over one canonical skill

Each entrypoint will describe only delegation to `openspec-commit`, state
`exactly once`, and explicitly prohibit separate archive, documentation, or
commit actions. The canonical skill remains responsible for sequencing, resume
state, and exact context hand-offs.

Copying the full workflow into each provider file was rejected because it would
create three independently drifting implementations. Keeping the current
numbered workflow summary was also rejected because a model can interpret it as
an instruction sequence in addition to the skill invocation.

### 2. Input and invocation syntax stay provider-specific

The Claude command will declare `argument-hint: "[change-name]"`, reference
`$ARGUMENTS`, and invoke the skill through Claude Code's Skill tool. It will not
add `allowed-tools`; normal project permission rules remain authoritative for
the mutating completion workflow.

The Antigravity workflow will name its flat `/opsx-commit` command, treat
following text as the optional change name, and activate the project-owned
skill. It will avoid Claude-specific `Skill tool` and `/opsx:apply` wording. If
nested activation is unavailable, it will follow
`.agents/skills/openspec-commit/SKILL.md` in the current context.

A single provider-neutral body was rejected because the command spelling,
argument mechanism, and nested-skill terminology are intentionally different at
the invocation edge.

### 3. Template propagation is part of the contract

Only files under `template/common/` will be edited. The standard installer will
refresh `.claude/commands/opsx/commit.md` and restore
`.agents/workflows/opsx-commit.md`.

`tests/test_agents_dir.sh` will compare each temporary installed file with its
template using `cmp -s`, rather than checking only that a workflows directory is
non-empty. `tests/test_openspec_commit.sh` will assert exactly-once delegation,
provider-correct terminology, and the Antigravity fallback.

### 4. TDD proves both missing behavior and propagation

The first implementation step will add the new contract assertions and run the
focused tests against the current templates. The expected RED failures are the
missing exactly-once/input language, Claude terminology in Antigravity, and the
missing tracked Antigravity installed target. Only after observing those
failures will the templates and documentation be changed and the installer run.

## Risks / Trade-offs

- **[Risk] Antigravity nested skill activation varies by host version.** →
  Retain an explicit in-context fallback to the installed `SKILL.md`.
- **[Risk] Static Markdown tests cannot prove model execution behavior.** →
  Test the enforceable text and installation contracts while keeping the
  canonical skill's existing orchestration tests.
- **[Risk] Exact byte comparisons are stricter than semantic comparisons.** →
  Accept the strictness because `rsync` is expected to preserve these managed
  files exactly and drift is the failure being prevented.
- **[Risk] Upstream OpenSpec paths remain inconsistent with current Antigravity
  documentation.** → Keep that investigation separate so this change does not
  blur project-owned and provider-native ownership.

## Migration Plan

1. Add failing contract assertions.
2. Update the two template entrypoints.
3. Run `scripts/skills/install.sh` to refresh generated targets.
4. Update the workflow documentation.
5. Run focused shell tests, strict OpenSpec validation, and diff checks.

Rollback is a normal Git revert of the project-owned template, test, doc, and
OpenSpec artifact changes, followed by rerunning the installer.

---
type: Playbook
title: Bulk Read Routing Evaluation
description: Install and evaluate the user-level bulk-read routing skill for Claude Code and Codex.
tags: [skills, subagents, evaluation, claude-code, codex]
timestamp: 2026-09-09T00:00:00+08:00
---

# Bulk Read Routing Evaluation

## Scope

`bulk-read-routing` delegates one broad, location-unknown discovery phase to the provider-native `bulk-reader-agent`. It does not route small or already-located work, and the parent retains verification, engineering decisions, and edits.

The source is isolated under `template/user/bulk-read-routing/`; it is not part of the project-level common installer.

## Installation

Install both providers:

```bash
bash scripts/user/install-bulk-read-routing.sh
```

Install one provider:

```bash
bash scripts/user/install-bulk-read-routing.sh claude
bash scripts/user/install-bulk-read-routing.sh codex
```

For a non-destructive installation check, provide temporary provider roots:

```bash
tmp_dir="$(mktemp -d)"
bash scripts/user/install-bulk-read-routing.sh \
  --claude-root "$tmp_dir/claude" \
  --codex-root "$tmp_dir/codex"
```

The installer owns only the `bulk-read-routing` skill directory and `bulk-reader-agent` file in each selected user root.

## Static Verification

```bash
bash tests/test_bulk_read_routing.sh
```

This check validates exact template copies, provider selection, repeated installation, unrelated-file preservation, shared naming, and native read-only restrictions.

## A/B Evaluation

Use the same clean checkout and question for both variants. Start a fresh provider session for every run.

Discovery prompt:

```text
Trace how scripts/skills/install.sh installs provider-specific custom agents.
Return the source template locations, installer functions or commands, tests,
and at most six exact quotes with repository-relative paths and line ranges.
Do not edit files and do not propose an implementation.
```

Run two variants per provider:

1. Direct: append `Do not delegate or invoke bulk-read-routing.`
2. Routed: append `Use $bulk-read-routing.`

Record each result independently:

| Provider | Variant | Parent tokens | Subagent tokens | Total tokens | Elapsed time | Correct evidence | False or invented evidence | Spawn count | Write attempts |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Claude Code | Direct |  | 0 |  |  |  |  | 0 |  |
| Claude Code | Routed |  |  |  |  |  |  |  |  |
| Codex | Direct |  | 0 |  |  |  |  | 0 |  |
| Codex | Routed |  |  |  |  |  |  |  |  |

Inspect every reported path and quote directly before scoring it. Routed behavior passes only when exactly one `bulk-reader-agent` runs, no write is attempted, and evidence quality does not regress. Efficiency is reported rather than assumed: lower parent tokens alone do not establish an improvement when total tokens or elapsed time increase materially.

Also run a negative routing prompt in a fresh session:

```text
Read template/common/.codex/agents/doc-updater-agent.toml and report its model.
Do not edit files.
```

The negative case passes when `bulk-reader-agent` is not spawned.

## Current Smoke Evidence

### Claude Code 2.1.266 — not verified

Command:

```bash
claude -p --permission-mode plan --output-format stream-json \
  --forward-subagent-text --verbose --max-budget-usd 0.50 \
  'Use $bulk-read-routing. Within this repository, trace how scripts/skills/install.sh installs provider-specific custom-agent TOML files. Return the source template locations, installer functions or commands, tests, and at most six exact quotes with repository-relative paths and line ranges. Do not edit files and do not propose an implementation.'
```

The CLI discovered both `bulk-read-routing` and `bulk-reader-agent`, then exited before inference because its OAuth session had expired and could not be refreshed. Exit status was 1, cost and tokens were zero, spawn count was zero, and no write was attempted. Routing effectiveness is therefore not verified for Claude Code.

### Codex CLI 0.153.4 — fallback verified, subagent not verified

Command:

```bash
rtk codex exec --json --ephemeral --sandbox read-only \
  'Use $bulk-read-routing. Within this repository, trace how scripts/skills/install.sh installs provider-specific custom-agent TOML files. Return the source template locations, installer functions or commands, tests, and at most six exact quotes with repository-relative paths and line ranges. Do not edit files and do not propose an implementation.'
```

The parent loaded the skill and made one named `bulk-reader-agent` spawn attempt. The collaboration runtime rejected it with `collab spawn failed: no thread with id`; no subagent started. The parent then followed the specified fallback, completed read-only targeted discovery, corrected an initially suspected path before its final report, and returned verified repository evidence. Exit status was 0, elapsed wall time was approximately 99 seconds, and usage reported 420,293 input tokens (360,704 cached), 5,325 output tokens, and 2,030 reasoning output tokens. The transcript contained no write attempt. The fallback contract is verified, but Codex subagent execution and efficiency improvement are not verified.

# Citations

[1] [Claude Code custom agent example](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/agent-development/examples/agent-creation-prompt.md)
[2] [Codex custom agent role configuration](https://github.com/openai/codex/blob/main/codex-rs/agent-roles/src/agent_role_config.rs)

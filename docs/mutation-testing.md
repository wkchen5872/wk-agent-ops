---
type: Playbook
title: Mutation Testing Playbook
description: How to configure and run provider-neutral mutation audits with mutmut and Stryker.
tags: [testing, mutation-testing, tdd, playbook]
timestamp: 2026-08-01T00:00:00+08:00
---

<!-- Managed by wk-agent-ops · do not edit here — re-running install.sh overwrites this file. -->

# Mutation Testing Playbook

Line coverage proves a line ran; it does not prove a test would notice if that
line broke. Mutation testing introduces small faults and observes whether the
existing tests detect them. It is an advisory test-strength audit, never a
mutation-score, completion, commit, or CI gate.

## Invocation and ownership

| Skill | When | Ownership |
|---|---|---|
| `mutation-setup` | first setup, upgrades, config changes | interactive dependency/config side effects |
| `mutation-check` | audit a current change | baseline, mutation run, report, triage state |

Invoke either portable skill by name in Claude Code, Codex, Antigravity, or
another Provider that supports project skills. **Provider-specific example:**
Claude Code may expose `/mutation-setup` and `/mutation-check`; slash commands
are not a cross-Provider requirement.

`mutation-setup` is idempotent: it resolves the Git root and affected project
unit, preserves the existing package manager/lockfile, shows current settings,
and asks before every write. The common installer only distributes Agent
configuration; it never edits a target project's manifest or mutation config.

## Valid audit sequence

1. Resolve the repository root with Git, then map changed production files to
   their nearest Python or TS/JS project unit. Ask when monorepo ownership is
   ambiguous.
2. Confirm the tool and configuration are ready; otherwise return to
   `mutation-setup`.
3. Run the project unit's baseline tests. A failing baseline makes the audit
   invalid: stop without a score or scan-state update. After a mutmut run, make
   sure pytest targets the real tests directory or excludes generated
   `mutants/` to avoid duplicate-module collection.
4. Compute changed-code focus from dirty work, the feature-branch merge-base,
   or `last_scan_commit` on the default branch.
5. Run the tool with its native scope model, report all result categories, and
   preserve human triage decisions.

## Tool-specific scope

| Language | Tool | Mutation scope |
|---|---|---|
| Python | [mutmut](https://mutmut.readthedocs.io/en/latest/) | configured `source_paths` is the generation/cache universe; changed modules focus rerun, inspection, and reporting |
| TS/JS | [StrykerJS](https://stryker-mutator.io/) | `--mutate` accepts changed files and line ranges |

The Git diff defines the audit focus, but the tools do not implement that focus
identically. In particular, mutmut may generate mutants for the configured
source universe before a positional selector narrows a rerun. Do not describe
it as Stryker-style file-level generation, and do not use one changed-line cost
formula for both tools.

Current mutmut configuration uses `source_paths`; mutmut 3.7.0 dogfood verified
the public `mutmut run`, `mutmut results`, `mutmut show`, and `mutmut browse`
commands. Do not depend on an undocumented internal result file. Stryker's
`mutate`, incremental, and force settings are documented in its official
configuration reference.

## Results and triage state

Keep tool-native result meanings separate: killed, survived, no coverage or
untested, timeout, invalid/error, and skipped when available. A tool-provided
score is secondary context. Even 100% only describes the executed scope; it is
not proof that the complete test suite is effective.

Actionable survivors are sorted conditional → boundary → return-value → other.
The audit offers three outcomes:

1. hand the test gap to the current implementation/TDD workflow;
2. record an equivalent mutant with a human reason;
3. defer the finding with a reason, keeping it unresolved.

The state file keeps the scan base separate from decisions:

```text
last_scan_commit=<sha>
equivalent=<fingerprint>\t<date>\t<reason>
deferred=<fingerprint>\t<date>\t<reason>
```

Advancing the scan base must not delete equivalent or deferred records. If a
tool output cannot identify a prior finding reliably, show it for triage again.

## Relationship to TDD

Mutation testing supplements test-first evidence; it does not replace it. The
shared protocol uses a **conditional causal check** when Red evidence is absent,
risk is high, or test causality remains unclear. A revert-check is one possible
causal check, not a mandatory step for every task.

From the community test-architect reference this toolkit adopts survivor risk
classification. It does not adopt a fixed score threshold or unconditional
revert-check. From the add-mutation-testing command it keeps the setup concern,
but not its one-shot, CI-gate-heavy shape.

# Citations

[1] [StrykerJS — Mutation testing for JavaScript and TypeScript](https://stryker-mutator.io/)
[2] [StrykerJS configuration reference](https://stryker-mutator.io/docs/stryker-js/configuration/)
[3] [stryker-mutator/stryker-js source](https://github.com/stryker-mutator/stryker-js)
[4] [mutmut documentation](https://mutmut.readthedocs.io/en/latest/)
[5] [boxed/mutmut source](https://github.com/boxed/mutmut)
[6] [add-mutation-testing command](https://github.com/davepoon/buildwithclaude/blob/main/plugins/all-commands/commands/add-mutation-testing.md)
[7] [test-architect agent](https://github.com/rohitg00/awesome-claude-code-toolkit/blob/main/agents/quality-assurance/test-architect.md)

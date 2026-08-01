## Context

The preceding `refine-multi-provider-worktree-workflow` change already provides and tests `opsx-branch` as the single branch transition. The remaining gap is orchestration: generated OpenSpec skills do not contain the guard, while the compatibility hook parses only `tool_input.command`, duplicates Git mutation, and is installed only for Claude Code and Copilot CLI.

Codex accepts the Claude-style PostToolUse configuration and event fields, including migrated entries in `~/.codex/hooks.json`, but its PostToolUse event can also run after a shell command exits non-zero. Copilot CLI uses a camelCase `postToolUse` payload and fires that event only for successful calls. Generated Provider skills, commands, and workflows remain installer-owned and must not be edited.

## Goals / Non-Goals

**Goals:**

- Make one tool-invariant Agent instruction enforce branch preparation for `new`, `ff`, and `continue`.
- Keep all Git create, switch, and Worktree-conflict behavior in `opsx-branch`.
- Normalize only the supported PostToolUse event shapes needed by Claude Code, Codex, and Copilot CLI.
- Make installation and removal idempotent when Codex already contains a migrated Claude hook.
- Leave a focused, offline TDD check for each behavior boundary.

**Non-Goals:**

- Modify generated OpenSpec skills or Provider commands.
- Add an Antigravity-wide shell hook or change its permission behavior.
- Automatically attach to an existing Worktree or transfer active-writer ownership.
- Make a PostToolUse fallback provide branch-first correctness; it runs after the OpenSpec command by definition.

## Decisions

### D1 — Put the Agent guard in the managed operating protocol

Add a short branch-preparation rule to `template/common/docs/agent-protocol.md` and propagate it through the existing installer. The rule runs after the Agent resolves a change ID and before it performs `new`, `ff`, or `continue`; a non-zero result stops that action.

This is the only existing managed instruction read through the portable `AGENTS.md` entrypoint by Claude Code and AGENTS.md-aware Providers. Provider-specific copies and patches to generated OpenSpec files were rejected because they would drift or be overwritten.

### D2 — Normalize the event, then delegate to `opsx-branch`

The compatibility hook will perform four steps only:

1. Read the command from Claude/Codex `tool_input.command` or Copilot `toolArgs.command`; decode a JSON-string `toolArgs` when necessary.
2. Ignore explicit failure payloads, including a non-zero Codex Bash response.
3. Resolve the repository from the event cwd/project directory, then the process cwd.
4. Invoke the installed `opsx-branch <change-id>` and convert any failure to a warning plus exit 0.

The command lookup order is an `OPSX_BRANCH_BIN` test/override value, `command -v opsx-branch`, then `$HOME/.local/bin/opsx-branch`. The hook will not retain its own `git checkout` implementation.

### D3 — Register only Providers with a suitable PostToolUse surface

The installer will use the existing settings helper for both `~/.claude/settings.json` and `~/.codex/hooks.json`, so an identical migrated Codex command is naturally deduplicated. Copilot keeps its repository hook file. The uninstaller removes the corresponding managed entries.

Antigravity uses D1 and receives no broad shell hook. Codex registration does not bypass its trust model; users still review or enable the hook through Codex `/hooks` when required.

### D4 — Preserve fail-soft compatibility semantics

The Agent-mediated guard is fail-closed for the requested OpenSpec action: failure stops artifact work. The compatibility hook remains fail-soft because it runs after the observed command and must not turn an optional repair into a Provider execution failure.

### D5 — Test contracts at the shell boundary

Extend the offline workflow test with focused cases for:

- Claude/Codex and Copilot payload normalization;
- explicit Codex command failure suppression;
- delegation to a stub `opsx-branch`, including Worktree-style failure;
- Claude/Codex/Copilot installation, migrated Codex deduplication, and uninstall;
- the managed protocol rule and downstream installer propagation.

Each production behavior starts with its smallest failing shell assertion. After focused Green, run the workflow, portable-protocol, syntax, and strict OpenSpec checks.

## Risks / Trade-offs

- [PostToolUse runs after scaffold creation] → Keep it explicitly compatibility-only; D1 owns branch-first correctness.
- [Codex hook is registered but not trusted] → Preserve Codex trust and document `/hooks` as the activation check.
- [Provider payloads evolve] → Keep normalization small, test known official shapes, and fail-soft on unknown input.
- [The installed command is absent from a hook PATH] → Use the deterministic `$HOME/.local/bin/opsx-branch` fallback and warn without duplicating Git logic.
- [This change is stacked on an unarchived predecessor] → Include the predecessor's final installer behavior in the full modified requirement so sequential archive does not regress it.

## Migration Plan

1. Update the source protocol and hook implementation with tests.
2. Run `scripts/skills/install.sh` to refresh the managed protocol in this repository.
3. Run `scripts/workflow/install.sh` to deploy the command and refresh Provider registrations; review the Codex entry in `/hooks` if prompted.
4. Roll back Provider hooks with `scripts/workflow/openspec-branch-creator/uninstall.sh`; restore the prior managed protocol by reinstalling the previous repository revision.

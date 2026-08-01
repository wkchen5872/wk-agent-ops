## Why

OpenSpec skills can determine the final change ID only after the requirement has been clarified, but the current workflow treats `opsx-branch` as a manual prerequisite and relies on a Claude-shaped PostToolUse hook afterward. This leaves `new`, `ff`, and `continue` with inconsistent branch guarantees across providers and can write change artifacts to the wrong checkout.

## What Changes

- Add an Agent-mediated branch preparation contract: after resolving a new or existing change ID, run `opsx-branch <change-id>` and continue the OpenSpec action only when it succeeds.
- Apply the contract to `openspec-new-change` / `opsx:new`, `openspec-ff-change` / `opsx:ff`, and `openspec-continue-change` / `opsx:continue`.
- Treat branch preparation failure as a stop condition. When another Worktree owns the branch, report its path without automatically attaching to it or creating another writer.
- Refactor the PostToolUse branch creator into a safety net for direct CLI and legacy entrypoints. It will recognize successful `openspec new change` execution and delegate Git branch mutation to `opsx-branch` instead of duplicating that logic.
- Cover Claude Code and Codex hook registration, retain and verify GitHub Copilot CLI support, and document Antigravity's Agent-mediated path without adding a broad shell-interception hook.
- Align workflow documentation and tests with the actual semantics and provider support of all three OpenSpec actions.

## Capabilities

### New Capabilities

<!-- None. -->

### Modified Capabilities

- `openspec-branch-creator-hook`: Make the hook a provider-aware PostToolUse safety net that delegates branch coordination to `opsx-branch` and only reacts to successful change creation.
- `workflow-scripts`: Define the Agent-mediated branch preparation flow, stop behavior, provider coverage, and Worktree ownership rules for OpenSpec new, fast-forward, and continue workflows.
- `portable-agents-md`: Add the tool-invariant OpenSpec branch guard to the managed operating protocol without modifying generated Provider skills or commands.

## Impact

- Affected workflow scripts: `scripts/workflow/opsx-branch.sh` and `scripts/workflow/openspec-branch-creator/`.
- Affected provider integration: Claude Code, Codex, Antigravity, and GitHub Copilot CLI.
- Affected documentation and tests: OpenSpec workflow guides, provider support references, and branch coordination coverage.
- No new runtime dependency is required.

## Why

`openspec-commit` currently requires the primary implementation model before
any delegation, even though that value is only needed for the final Git trailer.
Its generic `model` wording can also be misread as a subagent spawn override,
despite provider-native agents already owning their runtime model and effort.

## What Changes

- Resolve `tool_name` and `assisting_model` immediately before the commit step,
  rather than before archive or documentation handling.
- Define `assisting_model` as Git attribution metadata for the primary
  implementation model only.
- Prohibit using `assisting_model` as a subagent spawn model or reasoning-effort
  override.
- Invoke Claude Code and Codex custom agents by exact agent name without an
  explicit spawn model or effort, preserving their native configuration.
- Keep the existing portable-skill fallback for every other provider.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-commit`: Move attribution resolution to the commit boundary and
  separate it from provider-native subagent runtime configuration.
- `git-commit-writer`: Clarify that `assisting_model` is trailer metadata for
  the primary implementation model, not the commit writer's runtime model.

## Impact

- Updates the project-owned `openspec-commit` and `git-commit-writer`
  instructions, their installed copies, contract tests, and workflow docs.
- Does not change custom-agent models, reasoning effort, archive behavior, or
  provider fallback availability.

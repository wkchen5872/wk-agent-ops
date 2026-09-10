## Why

Codex currently may try `opsx-branch` inside `workspace-write`, fail because
`.git` is protected, and then retry with an already allowed elevated command.
The redundant failed attempt adds noise without improving safety.

## What Changes

- Require Agents running in a Provider that protects Git metadata to request the
  minimum required Git-write permission on the first `opsx-branch` attempt.
- Keep `opsx-branch` itself and its branch guard behavior unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `portable-agents-md`: Clarify permission handling for the existing Agent-mediated
  OpenSpec branch guard.

## Impact

- Updates the managed portable agent protocol template and generated protocol.
- Adds a focused protocol regression check; no workflow script or sandbox policy
  changes.
